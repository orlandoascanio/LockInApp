import SwiftUI

struct BreakEndedOverlayView: View {
    let onStartFocus: () -> Void
    let onSnooze: () -> Void
    let onEndCycle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 18) {
                Text("Break ended")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.flAccentDeep)

                Text("Back to it.")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color.flInk)

                Text("You rested. The next block is the one that counts.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.flInkSoft)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            .padding(.bottom, 32)

            HStack(spacing: 10) {
                Button("End cycle", action: onEndCycle)
                    .buttonStyle(FLActionButtonStyle(variant: .destructiveQuiet, minHeight: 40))
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("5 more minutes", action: onSnooze)
                    .buttonStyle(FLActionButtonStyle(variant: .secondary, minHeight: 40))

                Button("Start focus", action: onStartFocus)
                    .buttonStyle(FLActionButtonStyle(variant: .primary, minHeight: 40))
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.bottom, 38)
        }
        .frame(width: 560)
        .padding(.horizontal, 40)
        .background(Color.flCanvas)
        .accessibilityElement(children: .contain)
    }
}
