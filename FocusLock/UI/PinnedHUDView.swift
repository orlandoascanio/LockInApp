import FocusLockCore
import SwiftUI

/// Live content for the floating HUD. Kept separate from the controller so the
/// window can be built once and simply re-fed as the session ticks.
final class PinnedHUDModel: ObservableObject {
    @Published var countdown: String = "--:--"
    @Published var phaseLabel: String = ""
    @Published var guardedLine: String = ""
    @Published var progress: Double = 0
    @Published var canEnd: Bool = true
}

/// The always-on-top strip. Collapsed it shows only the time and what is being
/// guarded; hovering reveals the controls, so the resting state stays quiet.
struct PinnedHUDView: View {
    @ObservedObject var model: PinnedHUDModel

    let onEnd: () -> Void
    let onUnpin: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 16) {
            FLProgressRing(progress: model.progress)

            Text(model.countdown)
                .font(FLTypography.timerHUD)
                .monospacedDigit()
                .foregroundStyle(Color.flInk)
                .accessibilityLabel("\(model.countdown) remaining")

            VStack(alignment: .leading, spacing: 1) {
                FLMicroLabel(text: model.phaseLabel, tint: .flAccentDeep)
                    .fixedSize()

                Text(model.guardedLine)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.flInkSoft)
                    .lineLimit(1)
                    .fixedSize()
            }

            Spacer(minLength: 12)

            if isHovering {
                HStack(spacing: 14) {
                    if model.canEnd {
                        Button("End session", action: onEnd)
                            .buttonStyle(FLLinkButtonStyle(tint: .flClay))
                            .fixedSize()
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.flInkSoft)
                            .help("Strict block — it can't be ended early")
                    }

                    unpinButton
                }
                .transition(.opacity)
            } else {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.flInkSoft.opacity(0.5))
                    .rotationEffect(.degrees(45))
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 20)
        .frame(width: 420, height: 66)
        .background(Color.flCanvas)
        // Clipped last so the progress rule follows the corner radius.
        .overlay(alignment: .bottom) {
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.flHairline.opacity(0.6))
                Rectangle()
                    .fill(Color.flAccentDeep)
                    .frame(width: 420 * max(0, min(1, model.progress)))
            }
            .frame(height: 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: FLRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FLRadius.xl, style: .continuous)
                .strokeBorder(Color.flHairline.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.16), radius: 14, x: 0, y: 5)
        // Generous padding so the soft shadow has room to fall off before it
        // hits the transparent panel's edge — a tighter margin here clips the
        // blur into a hard rectangular line.
        .padding(FLSpacing.lg)
        .onHover { hovering in
            withAnimation(FLAnimation.quick) {
                isHovering = hovering
            }
        }
    }

    private var unpinButton: some View {
        Button(action: onUnpin) {
            Image(systemName: "pin.slash")
                .font(.system(size: 11))
                .foregroundStyle(Color.flAccentDeep)
        }
        .buttonStyle(.plain)
        .help("Unpin the floating HUD")
        .accessibilityLabel("Unpin the floating HUD")
    }
}
