import SwiftUI

struct BreakEndedOverlayView: View {
    let onStartFocus: () -> Void
    let onSnooze: () -> Void
    let onEndCycle: () -> Void

    var body: some View {
        VStack(spacing: FLSpacing.xl) {
            VStack(spacing: FLSpacing.md) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(Color.flFocus)
                    .frame(width: 64, height: 64)
                    .background(Color.flFocusSurface, in: RoundedRectangle(cornerRadius: FLRadius.xl, style: .continuous))
                    .symbolRenderingMode(.hierarchical)

                VStack(spacing: FLSpacing.sm) {
                    Text("Break is done.")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.flTextPrimary)

                    Text("Time to get locked in again.")
                        .font(.body)
                        .foregroundStyle(Color.flTextPrimary)

                    Text("You rested. Now protect the next block.")
                        .font(.callout)
                        .foregroundStyle(Color.flTextSecondary)
                }
                .multilineTextAlignment(.center)
            }

            HStack(spacing: FLSpacing.sm) {
                Button {
                    onStartFocus()
                } label: {
                    Label("Start Focus", systemImage: "play.fill")
                        .frame(minWidth: 110)
                }
                .buttonStyle(FLActionButtonStyle(variant: .primary))
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)

                Button {
                    onSnooze()
                } label: {
                    Label("Snooze 2 Minutes", systemImage: "clock.arrow.circlepath")
                        .frame(minWidth: 150)
                }
                .buttonStyle(FLActionButtonStyle(variant: .secondary))
                .controlSize(.large)

                Button {
                    onEndCycle()
                } label: {
                    Label("End Cycle", systemImage: "xmark")
                        .frame(minWidth: 110)
                }
                .buttonStyle(FLActionButtonStyle(variant: .secondary))
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(FLSpacing.xl)
        .frame(width: 480)
        .background(Color.flBackground)
    }
}
