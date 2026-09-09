import FocusLockCore
import SwiftUI

/// Audience-only surface. Capture this window instead of the host's workspace.
struct StreamAudienceView: View {
    @EnvironmentObject private var controller: MenuBarController

    private var dark: Bool { controller.config.stream.darkAppearance }
    private var ink: Color { dark ? Color(red: 0.95, green: 0.93, blue: 0.86) : Color(red: 0.17, green: 0.23, blue: 0.20) }
    private var accent: Color { dark ? Color(red: 0.73, green: 0.81, blue: 0.57) : Color(red: 0.29, green: 0.40, blue: 0.25) }
    private var copy: StreamPresentation { StreamPresentation(phase: controller.snapshot.phase) }
    /// Hidden until a block is actually running. Once you run past what you
    /// planned the total drops away rather than reading "Block 5 of 4".
    private var blockLabel: String? {
        guard controller.snapshot.phase != .idle else { return nil }
        let current = controller.snapshot.currentCycle
        let planned = controller.config.stream.plannedBlocks
        return current > planned ? "Block \(current)" : "Block \(current) of \(planned)"
    }

    /// A countdown says how long; a clock time says whether there is time to
    /// make coffee. The break is the one phase where that is the real question.
    private var returnLine: String? {
        guard controller.snapshot.phase == .break, let endsAt = controller.snapshot.phaseEndsAt else {
            return nil
        }
        return "Back at \(endsAt.formatted(date: .omitted, time: .shortened))"
    }

    private var countdown: String {
        switch controller.snapshot.phase {
        case .idle: return controller.displayCountdown
        case .focus, .break: return controller.snapshot.formattedRemaining
        default: return "00:00"
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 480
            // The wall needs room of its own; on a narrow window the countdown
            // wins and the roster waits until there is space for it.
            let showsRoster = controller.config.stream.showRoster
                && !controller.roster.isEmpty
                && geometry.size.width >= 820

            HStack(alignment: .top, spacing: 0) {
                mainColumn(compact: compact)

                if showsRoster {
                    Rectangle().fill(accent.opacity(0.22)).frame(width: 1)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        rosterColumn(height: geometry.size.height, compact: compact, at: context.date)
                    }
                    .frame(width: 300)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(ink)
            .background(dark ? Color(red: 0.09, green: 0.14, blue: 0.12) : Color(red: 0.96, green: 0.94, blue: 0.88))
        }
    }

    /// One page of the wall. Rows per page follow the window, so a taller
    /// window simply shows more people instead of cycling more often.
    private func rosterColumn(height: CGFloat, compact: Bool, at date: Date) -> some View {
        let rowHeight: CGFloat = compact ? 30 : 36
        let size = max(3, min(16, Int((height - 130) / rowHeight)))
        let page = controller.roster.page(size: size, at: date)

        return VStack(alignment: .leading, spacing: compact ? 8 : 11) {
            HStack {
                Text("WORKING ALONGSIDE — \(controller.roster.admitted.count)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                Spacer()
                if page.rotates {
                    Text("\(page.index + 1)/\(page.count)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .opacity(0.7)
                }
            }
            .foregroundStyle(accent)

            ForEach(page.tasks) { task in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(task.name)
                        .font(.system(size: compact ? 12 : 13, weight: .medium))
                        .foregroundStyle(accent)
                        .lineLimit(1)
                    Text(task.text)
                        .font(.system(size: compact ? 12 : 13))
                        .foregroundStyle(ink.opacity(task.isDone ? 0.45 : 0.85))
                        .strikethrough(task.isDone, color: ink.opacity(0.45))
                        .lineLimit(2)
                    if task.isDone {
                        Text("✓").foregroundStyle(accent).font(.system(size: 11))
                    }
                    Spacer(minLength: 4)
                    if let elapsed = task.elapsedLabel(at: date) {
                        Text(elapsed)
                            .font(.system(size: compact ? 10 : 11, design: .monospaced))
                            .foregroundStyle(ink.opacity(0.45))
                            .monospacedDigit()
                    }
                }
            }

            if page.rotates {
                Text("Everyone shows up — pages turn every \(Int(page.interval))s")
                    .font(.system(size: 10))
                    .foregroundStyle(ink.opacity(0.5))
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(compact ? 18 : 26)
    }

    private func mainColumn(compact: Bool) -> some View {
            VStack(spacing: compact ? 14 : 22) {
                HStack(spacing: 10) {
                    Label("LOCKIN / TOGETHER", systemImage: "circle.grid.2x2")
                    Spacer()
                    if let blockLabel {
                        Text(blockLabel).lineLimit(1)
                        Text("·").opacity(0.5)
                    }
                    Text(controller.streamTask.category.isEmpty ? "Your own task" : controller.streamTask.category)
                        .lineLimit(1)
                }
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(accent)

                Spacer(minLength: 0)

                VStack(spacing: 6) {
                    Text(copy.title)
                        .font(.system(size: compact ? 25 : 32, weight: .regular, design: .serif))
                    if controller.snapshot.phase != .idle {
                        Text(controller.config.stream.invitation)
                            .font(.system(size: 13))
                            .foregroundStyle(ink.opacity(0.72))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                }

                VStack(spacing: 4) {
                    Text(countdown)
                        .font(.system(size: compact ? 86 : 116, weight: .light, design: .monospaced))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .accessibilityLabel("\(countdown) remaining")

                    if let returnLine {
                        Text(returnLine)
                            .font(.system(size: compact ? 13 : 15, weight: .medium))
                            .foregroundStyle(accent)
                    }
                }

                if controller.config.stream.showGoal && !controller.streamTask.goal.isEmpty {
                    VStack(spacing: 6) {
                        Text("MY GOAL").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(accent)
                        Text(controller.streamTask.goal)
                            .font(.system(size: compact ? 17 : 22, design: .serif))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.8)
                    }
                }

                Spacer(minLength: 0)

                VStack(spacing: 14) {
                    Rectangle().fill(accent.opacity(0.3)).frame(height: 1)
                    Text(copy.prompt)
                        .font(.system(size: compact ? 14 : 16))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Type \(AudienceCommand.advertised) what you're working on — you'll appear on the wall")
                        .font(.system(size: compact ? 11 : 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(accent)
                        .multilineTextAlignment(.center)

                    Text("Different tasks. A little company. One shared timer.")
                        .font(.system(size: 11))
                        .foregroundStyle(ink.opacity(0.6))
                }
            }
            .padding(compact ? 28 : 40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
