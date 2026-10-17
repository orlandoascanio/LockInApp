import FocusLockCore
import SwiftUI

/// The countdown inside a ring that fills as the phase runs, so how far along
/// a block is reads from across the room, not only the digits.
struct FocusDial: View {
    let phaseLabel: String
    let countdown: String
    let progress: Double
    let isBreak: Bool
    let isActive: Bool
    /// The phase in words for VoiceOver; falls back to the visible label.
    var spokenPhase: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let diameter: CGFloat = 264
    private let lineWidth: CGFloat = 9

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.flInk.opacity(0.07), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(0.0001, min(1, progress)))
                .stroke(
                    isBreak ? Color.flRest : Color.flAccentDeep,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .opacity(isActive ? 1 : 0)
                .animation(reduceMotion ? nil : .linear(duration: 0.5), value: progress)

            VStack(spacing: 2) {
                Text(phaseLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isBreak ? Color.flRestInk : isActive ? Color.flAccentDeep : Color.flInkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: diameter - 60)

                Text(countdown)
                    .font(FLTypography.timer(64))
                    .monospacedDigit()
                    .foregroundStyle(Color.flInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 26)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        // Nothing is "remaining" before a block starts.
        .accessibilityLabel("\(spokenPhase ?? phaseLabel), \(countdown)\(isActive ? " remaining" : "")")
        .accessibilityValue(isActive ? "\(Int(progress * 100)) percent through this phase" : "")
    }
}

/// Every block started today, in order, so the bottom of the Focus page shows
/// the day taking shape instead of an empty canvas.
struct TodayBlocks: View {
    @EnvironmentObject private var controller: MenuBarController

    private var blocks: [SessionHistoryEntry] {
        controller.history
            .filter { Calendar.current.isDateInToday($0.startedAt) }
            .sorted { $0.startedAt < $1.startedAt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FLSectionHeader(
                title: "Today",
                subtitle: blocks.isEmpty
                    ? nil
                    : "\(blocks.filter { $0.status == .completed }.count) of \(blocks.count) finished"
            )

            if blocks.isEmpty {
                Text("Nothing yet. Your first block of the day shows up here.")
                    .font(FLTypography.callout)
                    .foregroundStyle(Color.flInkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(blocks.suffix(8)) { entry in
                        row(entry)
                        if entry.id != blocks.suffix(8).last?.id {
                            Rectangle().fill(Color.flHairline).frame(height: 1)
                        }
                    }
                }
            }
        }
    }

    private func row(_ entry: SessionHistoryEntry) -> some View {
        HStack(spacing: 12) {
            Text(MenuBarController.shortTime(entry.startedAt))
                .font(.system(size: 12))
                .monospacedDigit()
                .foregroundStyle(Color.flInkSoft)
                .frame(width: 62, alignment: .leading)

            Circle()
                .fill(dotColor(entry.status))
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 1) {
                Text(title(for: entry))
                    .font(FLTypography.body)
                    .foregroundStyle(Color.flInk)
                    .lineLimit(1)
                if let outcome = entry.checkIn?.outcome {
                    Text(outcome.title)
                        .font(FLTypography.caption)
                        .foregroundStyle(outcome.tint)
                }
            }

            Spacer(minLength: 8)

            if entry.strictMode {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.flInkSoft)
                    .help("Strict block")
            }

            Text(entry.status == .completed ? "\(entry.focusMinutes) min" : entry.status.displayName)
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(entry.status == .completed ? Color.flInk : Color.flInkSoft)
        }
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
    }

    private func title(for entry: SessionHistoryEntry) -> String {
        let goal = entry.task?.goal ?? ""
        let category = entry.task?.category ?? ""
        if !goal.isEmpty { return goal }
        return category.isEmpty ? "Focus block" : category
    }

    private func dotColor(_ status: SessionHistoryStatus) -> Color {
        switch status {
        case .completed: return .flAccentDeep
        case .cancelled: return .flInkSoft
        case .abandoned: return .flClay
        }
    }
}

/// "What is this block for?" — a goal and a category, under the timer.
struct FocusGoalBar: View {
    @EnvironmentObject private var controller: MenuBarController
    /// Told while you are typing here, so Return can finish the text rather
    /// than press the page's Start.
    var onTypingChange: (Bool) -> Void = { _ in }
    @State private var newCategory = ""
    @State private var isNamingCategory = false
    @FocusState private var categoryFieldFocused: Bool
    @FocusState private var goalFieldFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                TextField(controller.isSessionActive ? "Next block's goal" : "What's this block for?", text: Binding(
                    get: { controller.config.task.goal },
                    set: { value in controller.updateTask { $0.goal = String(value.prefix(160)) } }
                ))
                .focused($goalFieldFocused)
                .flField(focused: goalFieldFocused)
                .frame(maxWidth: .infinity)
                // Return finishes the goal; a second Return starts the block.
                .onSubmit { goalFieldFocused = false }

                FLMenuPicker(
                    options: controller.config.task.categories,
                    selection: controller.config.task.category,
                    title: { $0 },
                    onSelect: { name in
                        isNamingCategory = false
                        controller.updateTask { $0.category = name }
                    },
                    width: 140,
                    extraItems: AnyView(Button("New category…") { isNamingCategory = true }),
                    accessibilityLabel: "Category"
                )
            }

            // The field only exists while you are actually naming one.
            if isNamingCategory {
                HStack(spacing: 8) {
                    TextField("Name it", text: $newCategory)
                        .flField(width: 180)
                        .focused($categoryFieldFocused)
                        .onSubmit(addCategory)
                        .onAppear { categoryFieldFocused = true }
                    Button("Add", action: addCategory)
                        .buttonStyle(FLInlineButtonStyle())
                        .disabled(newCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Cancel") {
                        newCategory = ""
                        isNamingCategory = false
                    }
                    .buttonStyle(FLInlineButtonStyle(tint: .flInkSoft))
                }
            }

            if controller.isSessionActive, let goal = controller.snapshot.task?.goal, !goal.isEmpty,
               goal != controller.config.task.goal {
                Text("This block: \(goal)")
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flInkSoft)
                    .lineLimit(1)
            }
        }
        .onChange(of: goalFieldFocused || categoryFieldFocused) { _, typing in
            onTypingChange(typing)
        }
    }

    private func addCategory() {
        let name = newCategory
        controller.updateTask { _ = $0.addCategory(name) }
        newCategory = ""
        isNamingCategory = false
    }
}

/// During a break: something to do with it, and a check-in on the block
/// that just finished.
struct BreakPanel: View {
    @EnvironmentObject private var controller: MenuBarController
    /// During a break the guide sits beside the dial instead, above the fold.
    var showsGuide = true

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            if showsGuide, controller.breakSuggestion != nil {
                BreakSuggestionGuide()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let entry = controller.checkInEntry {
                CheckInView(entry: entry)
                    .id(entry.id)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// "Try this": the break's suggestion as something to do.
struct BreakSuggestionGuide: View {
    @EnvironmentObject private var controller: MenuBarController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let suggestion = controller.breakSuggestion {
            VStack(alignment: .leading, spacing: 8) {
                Text("Try this")
                    .font(FLTypography.headline)
                    .foregroundStyle(Color.flRestInk)
                BreakGuideView(
                    suggestion: suggestion,
                    breakEndsAt: controller.snapshot.phase == .break ? controller.snapshot.phaseEndsAt : nil,
                    isDone: controller.breakPick?.done == true,
                    tally: tally(for: suggestion.kind),
                    onDone: { controller.markBreakSuggestionDone() },
                    onAnother: {
                        withAnimation(reduceMotion ? nil : FLAnimation.standard) {
                            controller.anotherBreakSuggestion()
                        }
                    }
                )
            }
        }
    }

    private func tally(for kind: BreakSuggestionKind) -> String? {
        // Read again whenever the pick changes, which is when a count can.
        _ = controller.breakPick
        return BreakGuideView.tally(
            for: kind,
            today: controller.breakActivity.countToday(of: kind),
            week: controller.breakActivity.countThisWeek(of: kind)
        )
    }
}

private struct CheckInView: View {
    @EnvironmentObject private var controller: MenuBarController
    let entry: SessionHistoryEntry
    /// Nothing is picked until you pick it; picking saves.
    @State private var outcome: CheckInOutcome?
    @State private var note = ""
    @State private var isWritingNote = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FLSectionLabel(text: "How did that block go?")
            if let goal = entry.task?.goal, !goal.isEmpty {
                Text(goal)
                    .font(FLTypography.body)
                    .foregroundStyle(Color.flInk)
                    .lineLimit(2)
            }
            // One tap is the whole check-in; a note is optional and extra.
            FLSegmentedControl(
                options: CheckInOutcome.allCases.map { Optional($0) },
                selection: Binding(
                    get: { outcome },
                    set: { choice in
                        outcome = choice
                        if let choice {
                            controller.saveCheckIn(outcome: choice, note: note)
                        }
                    }
                ),
                title: { $0?.title ?? "" },
                accessibilityLabel: "How the block went"
            )

            if isWritingNote {
                TextField("A note for next time", text: $note, axis: .vertical)
                    .lineLimit(1...3)
                    .flField()
                    .onChange(of: note) { _, value in note = String(value.prefix(500)) }
                Button("Save note") {
                    controller.saveCheckIn(outcome: outcome ?? .progress, note: note)
                    isWritingNote = false
                }
                .buttonStyle(FLInlineButtonStyle())
            } else {
                Button(note.isEmpty ? "Add a note" : "Edit note") {
                    isWritingNote = true
                }
                .buttonStyle(FLLinkButtonStyle())
            }
        }
        .onAppear {
            outcome = entry.checkIn?.outcome
            note = entry.checkIn?.note ?? ""
        }
    }
}

struct RecapCard: View {
    @EnvironmentObject private var controller: MenuBarController
    let recap: RunRecap

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Last run")
                    .font(FLTypography.micro)
                    .foregroundStyle(Color.flInkSoft)
                Text(recap.headline)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.flInk)
                if !recap.categories.isEmpty {
                    Text(recap.categories.map { "\($0.name) \(RunRecap.duration($0.minutes))" }.joined(separator: " · "))
                        .font(FLTypography.caption)
                        .foregroundStyle(Color.flInkSoft)
                }
                if recap.goalsDone > 0 {
                    Text("\(recap.goalsDone) goal\(recap.goalsDone == 1 ? "" : "s") done")
                        .font(FLTypography.caption)
                        .foregroundStyle(Color.flAccentDeep)
                }
            }
            Spacer()
            Button("Copy recap") {
                controller.copyRecap()
            }
            .buttonStyle(FLActionButtonStyle(variant: .secondary, minHeight: 32))
        }
    }
}

/// The emergency exit. Typing the sentence starts a wait; the block ends only
/// when the wait runs out, and closing this sheet does not cancel it.
struct StrictEscapeSheet: View {
    @EnvironmentObject private var controller: MenuBarController
    @Environment(\.dismiss) private var dismiss
    @State private var typed = ""
    @State private var rejected = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Emergency exit")
                .font(FLTypography.micro)
                .foregroundStyle(Color.flClayInk)
            Text("End this strict block early?")
                .font(FLTypography.display)
                .foregroundStyle(Color.flInk)

            if let escape = controller.strictEscape, let remaining = escape.remaining(at: Date()) {
                Text("The block ends in \(Self.format(remaining)). Leave this open or close it — either way, the wait keeps going. Change your mind and it stays locked.")
                    .font(FLTypography.body)
                    .foregroundStyle(Color.flInkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                Text(Self.format(remaining))
                    .font(FLTypography.timer(44))
                    .monospacedDigit()
                    .foregroundStyle(Color.flInk)
                    .frame(maxWidth: .infinity)

                HStack {
                    Button("Keep the block") {
                        controller.cancelEscape()
                        dismiss()
                    }
                    .buttonStyle(FLActionButtonStyle(variant: .primary, minHeight: 36))
                    .keyboardShortcut(.defaultAction)
                    Spacer()
                    Button("Close") { dismiss() }
                        .buttonStyle(FLActionButtonStyle(variant: .quiet, minHeight: 36))
                }
            } else {
                Text("Type this sentence exactly. After that, Quietwhile waits \(Self.format(TimeInterval(controller.config.strict.escapeWaitSeconds))) before ending the block.")
                    .font(FLTypography.body)
                    .foregroundStyle(Color.flInkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                Text(StrictEscape.phrase)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.flInk)
                    .textSelection(.disabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.flSunken, in: RoundedRectangle(cornerRadius: FLRadius.lg, style: .continuous))

                TextField("Type it here", text: $typed)
                    .flField()
                    .onSubmit(submit)

                if rejected {
                    Text("That isn't the sentence. Every word counts.")
                        .font(FLTypography.caption)
                        .foregroundStyle(Color.flClayInk)
                }

                HStack {
                    Button("Never mind") { dismiss() }
                        .buttonStyle(FLActionButtonStyle(variant: .primary, minHeight: 36))
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Start the wait", action: submit)
                        .buttonStyle(FLActionButtonStyle(variant: .destructive, minHeight: 36))
                        .disabled(typed.isEmpty)
                }
            }
        }
        .padding(28)
        .frame(width: 460)
        .background(Color.flCanvas)
        .onChange(of: controller.isStrictLocked) { _, locked in
            if !locked { dismiss() }
        }
    }

    private func submit() {
        rejected = !controller.beginEscape(typed: typed)
    }

    private static func format(_ seconds: TimeInterval) -> String {
        let whole = max(0, Int(seconds.rounded(.up)))
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }
}

extension CheckInOutcome {
    /// Done in moss, progress in amber, stuck in clay: how it went, at a
    /// glance, and never "stuck" in the colour of success.
    var tint: Color {
        switch self {
        case .done: return .flAccentDeep
        case .progress: return .flWarningInk
        case .stuck: return .flClayInk
        }
    }
}
