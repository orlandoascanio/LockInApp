import Foundation

public struct StrictModeSettings: Codable, Equatable {
    /// Every manually started block runs strict. Schedules can make their own
    /// blocks strict independently of this.
    public var enabled = false

    /// How long the emergency exit makes you wait after typing the sentence.
    public var escapeWaitSeconds = 120

    public init(enabled: Bool = false, escapeWaitSeconds: Int = 120) {
        self.enabled = enabled
        self.escapeWaitSeconds = max(10, escapeWaitSeconds)
    }

    private enum CodingKeys: String, CodingKey {
        case enabled, escapeWaitSeconds
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        escapeWaitSeconds = max(10, try container.decodeIfPresent(Int.self, forKey: .escapeWaitSeconds) ?? 120)
    }
}

/// Something a strict block refuses while it runs.
public enum StrictAction: Equatable {
    case endSession
    case skipFocus
    case allowGuardedApp
    case weakenGuard
    case quitApp
    case changeStrictSettings
}

public enum StrictPolicy {
    /// A strict block holds for the focus phase. Breaks are yours: ending a run
    /// during one gives up no focus that was promised.
    public static func isLocked(phase: SessionPhase, sessionIsStrict: Bool) -> Bool {
        sessionIsStrict && phase == .focus
    }

    public static func allows(_ action: StrictAction, phase: SessionPhase, sessionIsStrict: Bool) -> Bool {
        !isLocked(phase: phase, sessionIsStrict: sessionIsStrict)
    }
}

/// The emergency exit: type a sentence exactly, then wait. Friction rather
/// than a wall — enough that leaving is a decision, not a reflex.
public struct StrictEscape: Equatable {
    public static let phrase = "I am ending this focus block early on purpose"

    public private(set) var requestedAt: Date?
    public let waitSeconds: TimeInterval

    public init(waitSeconds: TimeInterval) {
        self.waitSeconds = waitSeconds
    }

    /// Case, spacing, and a trailing full stop do not count against you;
    /// every word does.
    public static func accepts(_ typed: String) -> Bool {
        normalized(typed) == normalized(phrase)
    }

    @discardableResult
    public mutating func request(typed: String, at now: Date) -> Bool {
        guard Self.accepts(typed) else { return false }
        if requestedAt == nil {
            requestedAt = now
        }
        return true
    }

    public mutating func cancel() {
        requestedAt = nil
    }

    public func remaining(at now: Date) -> TimeInterval? {
        guard let requestedAt else { return nil }
        return max(0, waitSeconds - now.timeIntervalSince(requestedAt))
    }

    public func isReady(at now: Date) -> Bool {
        remaining(at: now) == 0
    }

    private static func normalized(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
