import FocusLockCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var controller: MenuBarController

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: FLSpacing.lg) {
                    header
                    timerSection
                    blockingSection
                }
                .padding(FLSpacing.lg)
            }

            if let settingsMessage = controller.settingsMessage {
                FLSubtleDivider()
                HStack(spacing: FLSpacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.flSuccess)
                        .symbolRenderingMode(.hierarchical)

                    Text(settingsMessage)
                        .font(.caption)
                        .foregroundStyle(Color.flTextSecondary)

                    Spacer()
                }
                .padding(.horizontal, FLSpacing.lg)
                .padding(.vertical, FLSpacing.sm)
            }
        }
        .background(Color.flBackground)
        .frame(minWidth: 460, minHeight: 520)
    }

    private var header: some View {
        HStack(spacing: FLSpacing.md) {
            Image(systemName: "gearshape.fill")
                .font(.title2)
                .foregroundStyle(Color.flFocus)
                .frame(width: 44, height: 44)
                .background(Color.flFocusSurface, in: RoundedRectangle(cornerRadius: FLRadius.lg, style: .continuous))
                .symbolRenderingMode(.hierarchical)

            VStack(alignment: .leading, spacing: FLSpacing.xs) {
                Text("Settings")
                    .font(FLTypography.title)
                    .foregroundStyle(Color.flTextPrimary)

                Text("Configure durations, blocking behavior, and blocked apps.")
                    .font(.callout)
                    .foregroundStyle(Color.flTextSecondary)
            }

            Spacer()
        }
    }

    private var timerSection: some View {
        FLSurface {
            VStack(alignment: .leading, spacing: FLSpacing.md) {
                FLSectionHeader(title: "Durations", systemImage: "timer")

                HStack(spacing: FLSpacing.md) {
                    durationControl(
                        title: "Focus duration",
                        value: Binding(
                            get: { controller.config.focusMinutes },
                            set: { controller.updateFocusMinutes($0) }
                        ),
                        range: 1...180,
                        systemImage: "target"
                    )

                    durationControl(
                        title: "Break duration",
                        value: Binding(
                            get: { controller.config.breakMinutes },
                            set: { controller.updateBreakMinutes($0) }
                        ),
                        range: 0...60,
                        systemImage: "cup.and.saucer"
                    )
                }
            }
        }
    }

    private func durationControl(title: String, value: Binding<Int>, range: ClosedRange<Int>, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: FLSpacing.sm) {
            HStack(spacing: FLSpacing.sm) {
                Image(systemName: systemImage)
                    .foregroundStyle(Color.flFocus)
                    .frame(width: 28, height: 28)
                    .background(Color.flFocusSubtle, in: RoundedRectangle(cornerRadius: FLRadius.sm, style: .continuous))
                    .symbolRenderingMode(.hierarchical)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Color.flTextPrimary)

                    Text("\(value.wrappedValue) min")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color.flTextSecondary)
                }
            }

            Stepper("\(title) duration", value: value, in: range)
                .labelsHidden()
        }
        .padding(FLSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: FLRadius.md, style: .continuous))
    }

    private var blockingSection: some View {
        FLSurface {
            VStack(alignment: .leading, spacing: FLSpacing.md) {
                FLSectionHeader(title: "Blocking behavior", systemImage: "shield.lefthalf.filled")

                Picker("Behavior", selection: Binding(
                    get: { controller.config.blockerMode },
                    set: { controller.updateBlockerMode($0) }
                )) {
                    ForEach(BlockerMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                HStack(alignment: .top, spacing: FLSpacing.sm) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Color.flFocus)
                        .padding(.top, 1)

                    Text(controller.config.blockerMode.helperText)
                        .font(.caption)
                        .foregroundStyle(Color.flTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(FLSpacing.md)
                .background(Color.flFocusSubtle, in: RoundedRectangle(cornerRadius: FLRadius.md, style: .continuous))

                BlockedAppsView()
            }
        }
    }
}
