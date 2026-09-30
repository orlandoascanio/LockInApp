import FocusLockCore
import SwiftUI

/// "What is this block for?" — a goal and a category, under the timer.
struct FocusGoalBar: View {
    @EnvironmentObject private var controller: MenuBarController
    @State private var newCategory = ""
    @State private var isNamingCategory = false
    @FocusState private var categoryFieldFocused: Bool

    /// A type rather than a sentinel string: any reserved string is either
    /// something you could type yourself or, as with a NUL, something that
    /// does not survive the trip through AppKit's menus intact.
    private enum CategoryChoice: Hashable {
        case existing(String)
        case new
    }

    private var categorySelection: Binding<CategoryChoice> {
        Binding(
            get: { isNamingCategory ? .new : .existing(controller.config.task.category) },
            set: { choice in
                switch choice {
                case .new:
                    isNamingCategory = true
                case .existing(let name):
                    isNamingCategory = false
                    guard !name.isEmpty else { return }
                    controller.updateTask { $0.category = name }
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                TextField(controller.isSessionActive ? "Next block's goal" : "What's this block for?", text: Binding(
                    get: { controller.config.task.goal },
                    set: { value in controller.updateTask { $0.goal = String(value.prefix(160)) } }
                ))
                .flField(width: 300)

                Picker("Category", selection: categorySelection) {
                    ForEach(controller.config.task.categories, id: \.self) {
                        Text($0).tag(CategoryChoice.existing($0))
                    }
                    Divider()
                    Text("New category…").tag(CategoryChoice.new)
                }
                .labelsHidden()
                .frame(width: 130)
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
                        .disabled(newCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Cancel") {
                        newCategory = ""
                        isNamingCategory = false
                    }
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

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            if let suggestion = controller.breakSuggestion {
                VStack(alignment: .leading, spacing: 8) {
                    FLMicroLabel(text: "Try this")
                    HStack(spacing: 10) {
                        Image(systemName: suggestion.systemImage)
                            .font(.system(size: 20))
                            .foregroundStyle(Color.flAccentDeep)
                            .frame(width: 28)
                        Text(suggestion.title)
                            .font(FLTypography.title)
                            .foregroundStyle(Color.flInk)
                    }
                    Text(suggestion.detail)
                        .font(FLTypography.body)
                        .foregroundStyle(Color.flInkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let entry = controller.checkInEntry {
                CheckInView(entry: entry)
                    .id(entry.id)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 20)
    }
}

private struct CheckInView: View {
    @EnvironmentObject private var controller: MenuBarController
    let entry: SessionHistoryEntry
    @State private var outcome: CheckInOutcome = .progress
    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FLMicroLabel(text: "How did that block go?")
            if let goal = entry.task?.goal, !goal.isEmpty {
                Text(goal)
                    .font(FLTypography.body)
                    .foregroundStyle(Color.flInk)
                    .lineLimit(2)
            }
            Picker("Progress", selection: $outcome) {
                ForEach(CheckInOutcome.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            TextField("A note for next time (optional)", text: $note, axis: .vertical)
                .lineLimit(1...3)
                .flField()
                .onChange(of: note) { _, value in note = String(value.prefix(500)) }
            Button(entry.checkIn == nil ? "Save check-in" : "Update check-in") {
                controller.saveCheckIn(outcome: outcome, note: note)
            }
            .buttonStyle(FLActionButtonStyle(variant: .secondary, minHeight: 30))
        }
        .onAppear {
            outcome = entry.checkIn?.outcome ?? .progress
            note = entry.checkIn?.note ?? ""
        }
    }
}

struct RecapCard: View {
    @EnvironmentObject private var controller: MenuBarController
    let recap: RunRecap

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                FLMicroLabel(text: "Last run")
                Text(recap.headline)
                    .font(FLTypography.title)
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
        .padding(.horizontal, 26)
        .padding(.vertical, 18)
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
            FLMicroLabel(text: "Emergency exit")
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
                Text("Type this sentence exactly. After that, LockIn waits \(Self.format(TimeInterval(controller.config.strict.escapeWaitSeconds))) before ending the block.")
                    .font(FLTypography.body)
                    .foregroundStyle(Color.flInkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                Text(StrictEscape.phrase)
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .foregroundStyle(Color.flInk)
                    .textSelection(.disabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.flCanvasWarm, in: RoundedRectangle(cornerRadius: FLRadius.md))

                TextField("Type it here", text: $typed)
                    .flField()
                    .onSubmit(submit)

                if rejected {
                    Text("That isn't the sentence. Every word counts.")
                        .font(FLTypography.caption)
                        .foregroundStyle(Color.flClay)
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
