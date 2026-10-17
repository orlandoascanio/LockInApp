import FocusLockCore
import SwiftUI

/// The menu-bar popover: a small Focus page. The time, what it guards, the
/// one button that matters right now, and today at a glance. Anything beyond
/// glancing, starting, and stopping belongs in the main window.
struct MenuBarPopoverView: View {
    @EnvironmentObject private var controller: MenuBarController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if controller.isSessionActive {
                progressBar
            }

            guardedRow

            action

            HStack(spacing: 14) {
                tile(
                    label: "Today",
                    value: FLWeeklyRhythm.duration(controller.sessionStats.focusMinutesToday),
                    detail: blocksToday
                )
                FLColumnRule()
                tile(
                    label: "Streak",
                    value: "\(controller.streak)",
                    detail: controller.streak == 1 ? "day" : "days"
                )
            }
            .fixedSize(horizontal: false, vertical: true)

            FLRule()

            HStack {
                Button("Open \(AppIdentity.name)") {
                    controller.openMainWindow()
                }
                .buttonStyle(FLLinkButtonStyle())

                Spacer()

                Button(controller.config.pinnedHUDEnabled ? "Unpin HUD" : "Pin HUD") {
                    controller.updatePinnedHUD(enabled: !controller.config.pinnedHUDEnabled)
                }
                .buttonStyle(FLLinkButtonStyle(tint: .flInkSoft))
            }
        }
        .padding(16)
        .frame(width: 300)
        // No fill of its own: the system's popover material shows through,
        // so the panel and its arrow are one surface, as in a stock popover.
    }

    // MARK: Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                if controller.isStrictLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10.5, weight: .semibold))
                }
                Text(phaseLabel)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(phaseTint)

            Text(controller.displayCountdown)
                .font(FLTypography.timer(46))
                .foregroundStyle(Color.flInk)
                .contentTransition(.numericText())
                .accessibilityLabel("\(controller.displayCountdown)\(controller.isSessionActive ? " remaining" : "")")
        }
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.flSunken)
                Capsule()
                    .fill(controller.snapshot.phase == .break ? Color.flRest : Color.flAccentDeep)
                    .frame(width: max(6, geometry.size.width * min(1, controller.phaseProgress)))
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }

    private var guardedRow: some View {
        HStack(spacing: 10) {
            if !controller.activeBlockedApps.isEmpty, controller.snapshot.phase != .break {
                FLAppPile(
                    apps: controller.activeBlockedApps.map {
                        FLAppPile.BlockedAppSummary(id: $0.bundleId, bundleId: $0.bundleId)
                    },
                    size: 20
                )
            } else {
                Image(systemName: controller.snapshot.phase == .break ? "cup.and.saucer" : "shield")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.flInkSoft)
                    .frame(width: 20)
            }

            Text(controller.guardedSummaryLine)
                .font(.system(size: 12))
                .foregroundStyle(Color.flInkSoft)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var action: some View {
        if controller.isStrictLocked {
            Label("Strict: this block can’t be ended", systemImage: "lock.fill")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Color.flInkSoft)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
        } else if controller.isSessionActive {
            Button("End session") {
                controller.requestStopSession()
            }
            .buttonStyle(FLActionButtonStyle(variant: .destructive, minHeight: 36, fullWidth: true))
        } else {
            Button(controller.nextBlockIsStrict ? "Start strict block…" : "Start focus") {
                controller.requestStartFocus()
            }
            .buttonStyle(FLActionButtonStyle(variant: .primary, minHeight: 38, fullWidth: true))
        }
    }

    private func tile(label: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(FLTypography.micro)
                .foregroundStyle(Color.flInkSoft)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Color.flInk)
            Text(detail)
                .font(FLTypography.caption)
                .foregroundStyle(Color.flInkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var blocksToday: String {
        let count = controller.sessionStats.sessionsCompletedToday
        return count == 1 ? "1 block" : "\(count) blocks"
    }

    private var phaseTint: Color {
        switch controller.snapshot.phase {
        case .focus:
            return .flAccentDeep
        case .break, .breakEnded:
            return .flRestInk
        default:
            return .flInkSoft
        }
    }

    private var phaseLabel: String {
        switch controller.snapshot.phase {
        case .focus:
            return "Focus · \(controller.snapshot.focusMinutes) / \(controller.snapshot.breakMinutes)"
        case .break:
            return controller.currentBreakIsLong ? "Long break" : "Break"
        case .breakEnded:
            return "Break ended"
        default:
            return "Ready · \(controller.config.focusMinutes) / \(controller.config.breakMinutes)"
        }
    }
}
