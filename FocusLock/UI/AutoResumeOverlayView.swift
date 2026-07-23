import FocusLockCore
import SwiftUI

/// Live content for the autopilot takeover so the countdown can tick without
/// rebuilding the hosting windows.
final class AutoResumeOverlayModel: ObservableObject {
    @Published var countdown: String = "--:--"
    @Published var progress: Double = 0
    @Published var awayMinutes: Int = 0
    @Published var focusMinutes: Int = 50
    @Published var postponeMinutes: Int = 10
}

/// The screen autopilot takes over with when a break has been over for a while
/// and nothing has happened. Same paper as the guard screen — this is LockIn
/// speaking, not a system alert — but the countdown is the loudest thing on it.
struct AutoResumeOverlayView: View {
    @ObservedObject var model: AutoResumeOverlayModel

    let onStartNow: () -> Void
    let onPostpone: () -> Void
    let onEndCycle: () -> Void

    @State private var appeared = false
    @State private var pulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            topBar

            Spacer()

            VStack(spacing: 20) {
                FLMicroLabel(text: "Autopilot · next block starts in", tint: .flAccentDeep)

                Text(model.countdown)
                    .font(FLTypography.timerOverlay)
                    .monospacedDigit()
                    .foregroundStyle(Color.flInk)
                    .contentTransition(.numericText())
                    .accessibilityLabel("\(model.countdown) until the next focus block starts")

                progressLine

                Text(bodyLine)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.flInkSoft)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .frame(maxWidth: 520)
            }

            Spacer()

            actions
                .padding(.bottom, 46)
        }
        .opacity(appeared ? 1 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
        .ignoresSafeArea()
        .onAppear(perform: animateIn)
        .onExitCommand(perform: onPostpone)
    }

    /// The rings breathe once the screen lands — enough movement to catch an eye
    /// that was pointed at something else entirely, without a strobe.
    private var background: some View {
        ZStack {
            Color.flCanvas

            ForEach(0..<4) { index in
                Circle()
                    .strokeBorder(Color.flAccent.opacity(pulsing ? 0.22 : 0.10), lineWidth: 1)
                    .frame(
                        width: 300 + CGFloat(index) * 180,
                        height: 300 + CGFloat(index) * 180
                    )
                    .scaleEffect(pulsing ? 1.02 : 1)
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }

    private var topBar: some View {
        HStack {
            FLMicroLabel(text: AppIdentity.name)

            Spacer()

            FLBadge(
                text: "Autopilot",
                tint: .flAccentDeep,
                borderTint: Color.flAccentDeep.opacity(0.35)
            )
        }
        .padding(.horizontal, 34)
        .padding(.top, 28)
    }

    private var progressLine: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.flHairline.opacity(0.6))
                .frame(height: 2)

            GeometryReader { proxy in
                Capsule()
                    .fill(Color.flAccentDeep)
                    .frame(width: proxy.size.width * min(1, max(0, model.progress)), height: 2)
            }
            .frame(height: 2)
        }
        .frame(width: 260, height: 2)
        .accessibilityHidden(true)
    }

    private var bodyLine: String {
        let away = model.awayMinutes <= 0
            ? "Your break ended a moment ago."
            : "Your break ended \(model.awayMinutes) minute\(model.awayMinutes == 1 ? "" : "s") ago."

        return "\(away)\nThe next \(model.focusMinutes) minutes start on their own. Land what you are doing."
    }

    private var actions: some View {
        HStack(spacing: 26) {
            Button("Start now", action: onStartNow)
                .buttonStyle(FLActionButtonStyle(variant: .primary, minHeight: 44))
                .keyboardShortcut(.defaultAction)

            Button("Not yet — \(model.postponeMinutes) more minutes", action: onPostpone)
                .buttonStyle(FLLinkButtonStyle(tint: .flInkSoft))

            Button("End cycle", action: onEndCycle)
                .buttonStyle(FLLinkButtonStyle(tint: .flClay))
        }
    }

    private func animateIn() {
        guard !reduceMotion else {
            appeared = true
            return
        }

        withAnimation(FLAnimation.entrance) {
            appeared = true
        }

        // An even repeat count settles back on the resting ring opacity.
        withAnimation(.easeInOut(duration: 0.9).repeatCount(4, autoreverses: true)) {
            pulsing = true
        }
    }
}
