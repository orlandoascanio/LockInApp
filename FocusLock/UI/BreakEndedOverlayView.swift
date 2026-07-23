import SwiftUI

struct BreakEndedOverlayView: View {
    let onStartFocus: () -> Void
    let onSnooze: () -> Void
    let onEndCycle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 18) {
                FLMicroLabel(text: "Break ended", tint: .flAccentDeep)

                Text("Back to it.")
                    .font(FLTypography.timer(44))
                    .foregroundStyle(Color.flInk)

                Rectangle()
                    .fill(Color.flAccentDeep)
                    .frame(width: 36, height: 2)

                Text("You rested. The next block is the one that counts.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.flInkSoft)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            .padding(.bottom, 32)

            HStack(spacing: 22) {
                Button("Start focus", action: onStartFocus)
                    .buttonStyle(FLActionButtonStyle(variant: .primary, minHeight: 44))
                    .keyboardShortcut(.defaultAction)

                Button("Snooze 2 minutes", action: onSnooze)
                    .buttonStyle(FLLinkButtonStyle(tint: .flInkSoft))

                Button("End cycle", action: onEndCycle)
                    .buttonStyle(FLLinkButtonStyle(tint: .flClay))
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.bottom, 38)
        }
        .frame(width: 560)
        .padding(.horizontal, 40)
        .background(Color.flCanvas)
        .accessibilityElement(children: .contain)
    }
}
