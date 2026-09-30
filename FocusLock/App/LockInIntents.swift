import AppIntents
import FocusLockCore
import Foundation

// MARK: - Shortcuts actions

struct StartFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Focus"
    static let description = IntentDescription("Starts a LockIn focus block.")

    @Parameter(title: "Minutes", description: "Leave empty to use your usual length.",
               inclusiveRange: (1, 1_440))
    var minutes: Int?

    @Parameter(title: "Strict", description: "Run this block in strict mode.", default: false)
    var strict: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Start a \(\.$minutes) minute focus block") {
            \.$strict
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let controller = await LockInCommandCenter.shared.readyController() else {
            throw LockInIntentError.notReady
        }
        guard !controller.isSessionActive else {
            return .result(dialog: "A session is already running.")
        }
        controller.startFocus(strict: strict ? true : nil, minutes: minutes)
        let length = minutes ?? controller.config.focusMinutes
        return .result(dialog: "Focus started for \(length) minutes.")
    }
}

struct StopFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Focus"
    static let description = IntentDescription("Ends the current LockIn session. Strict blocks can't be stopped.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let controller = await LockInCommandCenter.shared.readyController() else {
            throw LockInIntentError.notReady
        }
        guard controller.isSessionActive || controller.snapshot.phase == .breakEnded else {
            return .result(dialog: "Nothing is running.")
        }
        guard !controller.isStrictLocked else {
            return .result(dialog: "This is a strict block, so it can't be stopped from Shortcuts.")
        }
        controller.stopSession()
        return .result(dialog: "Session ended.")
    }
}

struct SkipPhaseIntent: AppIntent {
    static let title: LocalizedStringResource = "Skip to Next Phase"
    static let description = IntentDescription("Ends focus early and starts the break, or ends the break and starts the next block.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let controller = await LockInCommandCenter.shared.readyController() else {
            throw LockInIntentError.notReady
        }
        guard !controller.isStrictLocked else {
            return .result(dialog: "This is a strict block, so it can't be skipped.")
        }
        let before = controller.snapshot.phase
        controller.skipPhase()
        switch before {
        case .focus: return .result(dialog: "Skipped to the break.")
        case .break, .breakEnded: return .result(dialog: "Next focus block started.")
        default: return .result(dialog: "Nothing to skip.")
        }
    }
}

struct FocusStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Focus Status"
    static let description = IntentDescription("Tells you what LockIn is doing and how long is left.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard let controller = await LockInCommandCenter.shared.readyController() else {
            throw LockInIntentError.notReady
        }
        let snapshot = controller.snapshot
        let status: String
        switch snapshot.phase {
        case .focus:
            status = "Focusing\(snapshot.isStrict ? " (strict)" : ""), \(snapshot.formattedRemaining) left."
        case .break:
            status = "On a break, \(snapshot.formattedRemaining) left."
        case .breakEnded:
            status = "The break is over. Ready for the next block."
        default:
            status = "Not focusing. \(controller.sessionStats.focusMinutesToday) minutes focused today."
        }
        return .result(value: status, dialog: "\(status)")
    }
}

enum LockInIntentError: Error, CustomLocalizedStringResourceConvertible {
    case notReady

    var localizedStringResource: LocalizedStringResource {
        "LockIn didn't finish opening. Try again in a moment."
    }
}

struct LockInShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartFocusIntent(),
            phrases: ["Start focus in \(.applicationName)", "Lock in with \(.applicationName)"],
            shortTitle: "Start Focus",
            systemImageName: "lock.fill"
        )
        AppShortcut(
            intent: StopFocusIntent(),
            phrases: ["Stop focus in \(.applicationName)"],
            shortTitle: "Stop Focus",
            systemImageName: "stop.circle"
        )
        AppShortcut(
            intent: SkipPhaseIntent(),
            phrases: ["Skip to the next phase in \(.applicationName)"],
            shortTitle: "Skip Phase",
            systemImageName: "forward.end"
        )
        AppShortcut(
            intent: FocusStatusIntent(),
            phrases: ["How long is left in \(.applicationName)"],
            shortTitle: "Focus Status",
            systemImageName: "timer"
        )
    }
}

// MARK: - Focus filter

/// Ties LockIn to a macOS Focus. When the Focus turns on, macOS runs this with
/// the options you picked; when it turns off, it runs it again with every
/// option at its default — so "Start a block" defaults to off, and a run with
/// it off means the Focus has ended.
struct LockInFocusFilter: SetFocusFilterIntent {
    static let title: LocalizedStringResource = "LockIn"
    static let description = IntentDescription("Start a LockIn focus block when this Focus turns on.")

    @Parameter(title: "Start a focus block", default: false)
    var startBlock: Bool

    @Parameter(title: "Use strict mode", default: false)
    var strict: Bool

    @Parameter(title: "End the block when this Focus turns off", default: false)
    var endWhenOff: Bool

    var displayRepresentation: DisplayRepresentation {
        guard startBlock else {
            return DisplayRepresentation(title: "Don't start a block")
        }
        var parts = [strict ? "Strict block" : "Focus block"]
        if endWhenOff {
            parts.append("ends with this Focus")
        }
        return DisplayRepresentation(title: "\(parts.joined(separator: ", "))")
    }

    private static let startedKey = "LockInFocusFilterStartedSession"
    private static let endWhenOffKey = "LockInFocusFilterEndWhenOff"

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let controller = await LockInCommandCenter.shared.readyController() else {
            return .result()
        }
        let defaults = UserDefaults.standard

        if startBlock {
            if !controller.isSessionActive {
                controller.startFocus(strict: strict ? true : nil)
                defaults.set(true, forKey: Self.startedKey)
                defaults.set(endWhenOff, forKey: Self.endWhenOffKey)
            }
        } else if defaults.bool(forKey: Self.startedKey) {
            // The Focus ended. Stop the block it started, if asked to — a
            // strict block is left to run out, same as any other way of asking.
            defaults.set(false, forKey: Self.startedKey)
            if defaults.bool(forKey: Self.endWhenOffKey), !controller.isStrictLocked,
               controller.isSessionActive || controller.snapshot.phase == .breakEnded {
                controller.stopSession()
            }
        }
        return .result()
    }
}
