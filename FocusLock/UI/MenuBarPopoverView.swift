import FocusLockCore
import SwiftUI

/// The menu-bar tuck: the same strip as the floating HUD, dropped from the
/// status item. It is deliberately not a control panel — anything beyond
/// glancing and stopping belongs in the main window.
struct MenuBarPopoverView: View {
    @EnvironmentObject private var controller: MenuBarController

    var body: some View {
        VStack(spacing: 0) {
            strip

            FLRule()

            HStack(spacing: 0) {
                action("Open \(AppIdentity.name)") {
                    controller.openMainWindow()
                }

                Rectangle()
                    .fill(Color.flHairline.opacity(0.7))
                    .frame(width: 1, height: 16)

                action(controller.config.pinnedHUDEnabled ? "Unpin HUD" : "Pin HUD") {
                    controller.updatePinnedHUD(enabled: !controller.config.pinnedHUDEnabled)
                }
            }
            .frame(height: 36)
        }
        .frame(width: 404)
        .background(Color.flCanvas)
    }

    private var strip: some View {
        HStack(alignment: .center, spacing: 14) {
            Text(controller.displayCountdown)
                .font(FLTypography.timer(34))
                .monospacedDigit()
                .foregroundStyle(Color.flInk)
                .accessibilityLabel("\(controller.displayCountdown) remaining")

            VStack(alignment: .leading, spacing: 2) {
                FLMicroLabel(
                    text: phaseLabel,
                    tint: controller.isSessionActive ? .flAccentDeep : .flInkSoft
                )
                .fixedSize()

                Text(guardedLine)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.flInkSoft)
                    .lineLimit(1)
                    .fixedSize()
            }

            Spacer(minLength: 12)

            if controller.isStrictLocked {
                Label("Strict", systemImage: "lock.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.flAccentDeep)
                    .fixedSize()
            } else if controller.isSessionActive {
                Button("End") {
                    controller.stopSession()
                }
                .buttonStyle(FLLinkButtonStyle(tint: .flClay))
                .fixedSize()
            } else {
                Button("Start") {
                    controller.startFocus()
                }
                .buttonStyle(FLLinkButtonStyle())
                .fixedSize()
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 74)
    }

    private var phaseLabel: String {
        switch controller.snapshot.phase {
        case .focus:
            return "Focus · \(controller.snapshot.focusMinutes)/\(controller.snapshot.breakMinutes)"
        case .break:
            return "Break"
        case .breakEnded:
            return "Break ended"
        default:
            return "Ready · \(controller.config.focusMinutes)/\(controller.config.breakMinutes)"
        }
    }

    private var guardedLine: String {
        controller.guardedSummaryLine
    }

    private func action(_ title: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Color.flInkSoft)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
