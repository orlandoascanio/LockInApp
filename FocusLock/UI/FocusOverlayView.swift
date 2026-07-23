import FocusLockCore
import SwiftUI

/// Live, observable content for the focus overlay so the countdown can tick
/// without rebuilding the hosting windows.
final class FocusOverlayModel: ObservableObject {
    @Published var appName: String = ""
    @Published var countdown: String = "--:--"
    @Published var allowSnooze: Bool = true
    @Published var snoozeMinutes: Int = 5
}

struct FocusOverlayView: View {
    @ObservedObject var model: FocusOverlayModel

    let onBackToFocus: () -> Void
    let onAllow: () -> Void
    let onEndSession: () -> Void

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                topBar

                Spacer()

                VStack(spacing: 22) {
                    Text("Not now.")
                        .font(FLTypography.timerOverlay)
                        .foregroundStyle(Color.flInk)

                    Rectangle()
                        .fill(Color.flAccentDeep)
                        .frame(width: 44, height: 2)

                    Text("\(openedAppName) is guarded until this block ends.\nIt is still running — nothing was closed, nothing was lost.")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.flInkSoft)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                }

                Spacer()

                actions
                    .padding(.bottom, 46)
            }
            .opacity(appeared ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
        .ignoresSafeArea()
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(FLAnimation.entrance) {
                    appeared = true
                }
            }
        }
        .onExitCommand(perform: onBackToFocus)
    }

    /// Concentric rings sit behind the content so they can never influence
    /// layout — they are the only ornament on the screen.
    private var background: some View {
        ZStack {
            Color.flCanvas

            ForEach(0..<4) { index in
                Circle()
                    .strokeBorder(Color.flAccent.opacity(0.10), lineWidth: 1)
                    .frame(
                        width: 300 + CGFloat(index) * 180,
                        height: 300 + CGFloat(index) * 180
                    )
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }

    private var topBar: some View {
        HStack {
            FLMicroLabel(text: AppIdentity.name)

            Spacer()

            Text("\(model.countdown) remaining")
                .font(.system(size: 12, design: .serif))
                .monospacedDigit()
                .foregroundStyle(Color.flInkSoft)
                .accessibilityLabel("\(model.countdown) remaining in this focus block")
        }
        .padding(.horizontal, 34)
        .padding(.top, 28)
    }

    private var actions: some View {
        HStack(spacing: 26) {
            Button("Back to work", action: onBackToFocus)
                .buttonStyle(FLActionButtonStyle(variant: .primary, minHeight: 44))
                .keyboardShortcut(.cancelAction)

            if model.allowSnooze {
                Button("Allow \(model.snoozeMinutes) minutes", action: onAllow)
                    .buttonStyle(FLLinkButtonStyle(tint: .flInkSoft))
            }

            Button("End session", action: onEndSession)
                .buttonStyle(FLLinkButtonStyle(tint: .flClay))
        }
    }

    private var openedAppName: String {
        model.appName.isEmpty ? "That app" : model.appName
    }
}
