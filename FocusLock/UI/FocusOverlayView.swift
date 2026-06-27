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
            LinearGradient(
                colors: [Color.flBackground, Color.flFocusSubtle.opacity(0.45), Color.flBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                statusPill
                    .padding(.top, FLSpacing.xl)

                Spacer()

                VStack(spacing: FLSpacing.xl) {
                    VStack(spacing: FLSpacing.md) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 58, weight: .semibold))
                            .foregroundStyle(Color.flFocus)
                            .symbolRenderingMode(.hierarchical)

                        VStack(spacing: FLSpacing.sm) {
                            Text("Stay locked in.")
                                .font(.system(size: 44, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.flTextPrimary)

                            Text("You opened \(openedAppName) during a focus session.")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Color.flTextPrimary)
                        }
                        .multilineTextAlignment(.center)
                    }

                    VStack(spacing: FLSpacing.sm) {
                        Text(model.countdown)
                            .font(FLTypography.timerOverlay)
                            .monospacedDigit()
                            .foregroundStyle(Color.flTextPrimary)

                        Text("remaining")
                            .font(.caption)
                            .foregroundStyle(Color.flTextTertiary)
                    }

                    Text("\(backgroundAppName) can keep running in the background.\nYou just don't need to live inside it right now.")
                        .font(.body)
                        .foregroundStyle(Color.flTextSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                Spacer()

                VStack(spacing: FLSpacing.md) {
                    buttonRow

                    if model.allowSnooze {
                        Text("Background processes keep running while the guard stays on.")
                            .font(.caption)
                            .foregroundStyle(Color.flTextTertiary)
                    }
                }
                .padding(.bottom, FLSpacing.xl)
            }
            .scaleEffect(appeared ? 1 : 0.98)
            .opacity(appeared ? 1 : 0)
        }
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

    private var statusPill: some View {
        HStack(spacing: FLSpacing.xs) {
            Image(systemName: "lock.fill")
                .font(.caption2)
            Text("Focus mode")
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(Color.flFocus)
        .padding(.horizontal, FLSpacing.md)
        .padding(.vertical, FLSpacing.sm)
        .background(Color.flFocusSubtle, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Focus mode active")
    }

    private var buttonRow: some View {
        HStack(spacing: FLSpacing.md) {
            OverlayButton(
                title: "Back to Focus",
                systemImage: "arrow.uturn.backward",
                prominent: true,
                action: onBackToFocus
            )
            .keyboardShortcut(.cancelAction)

            if model.allowSnooze {
                OverlayButton(
                    title: "Allow for \(model.snoozeMinutes) \(model.snoozeMinutes == 1 ? "Minute" : "Minutes")",
                    systemImage: "clock.arrow.circlepath",
                    action: onAllow
                )
            }

            OverlayButton(
                title: "End Session",
                systemImage: "stop.fill",
                action: onEndSession
            )
        }
    }

    private var openedAppName: String {
        model.appName.isEmpty ? "an app" : model.appName
    }

    private var backgroundAppName: String {
        model.appName.isEmpty ? "The app" : model.appName
    }
}

private struct OverlayButton: View {
    let title: String
    let systemImage: String
    var prominent: Bool = false
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: FLSpacing.sm) {
                Image(systemName: systemImage)
                Text(title)
                    .fontWeight(.medium)
            }
            .font(.body)
            .foregroundStyle(prominent ? .white : Color.flTextPrimary)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: FLRadius.md, style: .continuous)
                    .fill(prominent
                          ? Color.flFocusControl.opacity(hovering ? 0.9 : 1)
                          : Color.primary.opacity(hovering ? 0.08 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: FLRadius.md, style: .continuous)
                    .strokeBorder(prominent ? Color.clear : Color.flSeparator.opacity(0.6), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(FLAnimation.quick) {
                self.hovering = hovering
            }
        }
    }
}
