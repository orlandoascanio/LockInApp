import FocusLockCore
import SwiftUI

struct MenuBarPopoverView: View {
    @EnvironmentObject private var controller: MenuBarController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            timerSection

            blockedAppsSummary

            primaryAction

            presetSection

            HStack(spacing: FLSpacing.sm) {
                FLIconButton(title: "Settings", systemImage: "gearshape") { controller.openSettings() }
                FLIconButton(title: "History", systemImage: "clock.arrow.circlepath") { controller.openHistory() }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .frame(width: 360)
        .background(
            LinearGradient(
                colors: [
                    Color.flFocusSubtle.opacity(0.42),
                    Color.flBackground,
                    Color.flSurface.opacity(0.72)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var header: some View {
        HStack(spacing: FLSpacing.sm) {
            Image(systemName: "lock.shield")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(
                    LinearGradient(
                        colors: [Color.flFocus, Color.flFocusControl],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: FLRadius.lg, style: .continuous)
                )
                .symbolRenderingMode(.hierarchical)
                .shadow(color: Color.flFocus.opacity(0.22), radius: 8, x: 0, y: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(AppIdentity.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.flTextPrimary)

                Text(controller.isSessionActive ? "Guarding your focus" : "Ready when you are")
                    .font(.caption)
                    .foregroundStyle(Color.flTextSecondary)
            }

            Spacer()

            FLStatusPill(label: stateName, accent: controller.snapshot.phase == .focus, systemImage: stateIcon)
        }
    }

    // MARK: - Timer

    private var timerSection: some View {
        FLSurface(padding: 20, radius: FLRadius.xl) {
            VStack(alignment: .leading, spacing: FLSpacing.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: FLSpacing.xs) {
                        Text(currentStateLabel)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.flTextPrimary)

                        Text(statusLine)
                            .font(.callout)
                            .foregroundStyle(Color.flTextSecondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Image(systemName: timerIconName)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(timerAccent)
                        .frame(width: 40, height: 40)
                        .background(timerAccent.opacity(0.13), in: RoundedRectangle(cornerRadius: FLRadius.md, style: .continuous))
                        .symbolRenderingMode(.hierarchical)
                }

                Text(controller.snapshot.formattedRemaining)
                    .font(FLTypography.timerLarge)
                    .monospacedDigit()
                    .foregroundStyle(Color.flTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var timerAccent: Color {
        switch controller.snapshot.phase {
        case .focus:
            return .flFocus
        case .break, .breakEnded:
            return .flWarning
        default:
            return .flFocus
        }
    }

    private var timerIconName: String {
        switch controller.snapshot.phase {
        case .focus:
            return "shield.lefthalf.filled"
        case .break:
            return "cup.and.saucer.fill"
        case .breakEnded:
            return "bell.fill"
        default:
            return "timer"
        }
    }

    private var currentStateLabel: String {
        switch controller.snapshot.phase {
        case .focus:
            return "Focus Mode"
        case .break:
            return "Break"
        case .breakEnded:
            return "Break Ended"
        default:
            return "Idle"
        }
    }

    private var statusLine: String {
        switch controller.snapshot.phase {
        case .focus:
            return "Protecting \(blockedAppCountLabel)"
        case .break:
            return "Break - guard paused"
        case .breakEnded:
            return "Ready to start the next focus block"
        case .completed:
            return "Session complete"
        case .cancelled:
            return "Session cancelled"
        case .idle, .paused:
            return "\(blockedAppCountLabel.capitalized) ready to guard"
        }
    }

    private var blockedAppCountLabel: String {
        "\(controller.config.blockedApps.count) app\(controller.config.blockedApps.count == 1 ? "" : "s")"
    }

    private var stateName: String {
        switch controller.snapshot.phase {
        case .focus:
            return "Focus"
        case .breakEnded:
            return "Break done"
        default:
            return controller.snapshot.phase.displayName
        }
    }

    private var stateIcon: String {
        switch controller.snapshot.phase {
        case .focus:
            return "lock.fill"
        case .break:
            return "cup.and.saucer.fill"
        case .breakEnded:
            return "bell.fill"
        default:
            return "circle.fill"
        }
    }

    // MARK: - Preset

    private var presetSection: some View {
        FLSurface {
            VStack(alignment: .leading, spacing: FLSpacing.md) {
                FLSectionHeader(title: "Preset", systemImage: "slider.horizontal.3")

                HStack(spacing: FLSpacing.xs) {
                    ForEach(FocusPreset.allCases) { preset in
                        presetButton(preset)
                    }
                }

                if controller.preset == .custom {
                    HStack(spacing: FLSpacing.md) {
                        durationControl(
                            label: "Focus",
                            value: Binding(
                                get: { controller.config.focusMinutes },
                                set: { controller.updateFocusMinutes($0) }
                            ),
                            range: 1...180
                        )

                        durationControl(
                            label: "Break",
                            value: Binding(
                                get: { controller.config.breakMinutes },
                                set: { controller.updateBreakMinutes($0) }
                            ),
                            range: 0...60
                        )
                    }
                }
            }
        }
    }

    private func presetButton(_ preset: FocusPreset) -> some View {
        let isSelected = controller.preset == preset

        return Button {
            controller.selectPreset(preset)
        } label: {
            Text(preset.title)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(isSelected ? Color.white : Color.flTextPrimary)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(
                    isSelected ? Color.flFocusControl : Color.primary.opacity(0.055),
                    in: RoundedRectangle(cornerRadius: FLRadius.md, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: FLRadius.md, style: .continuous)
                        .strokeBorder(isSelected ? Color.clear : Color.flSeparator.opacity(0.5), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Select \(preset.title) preset")
    }

    private func durationControl(label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(alignment: .leading, spacing: FLSpacing.sm) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.flTextSecondary)

            HStack(spacing: FLSpacing.sm) {
                Text("\(value.wrappedValue)m")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(Color.flTextPrimary)
                    .frame(minWidth: 46, alignment: .leading)

                Spacer(minLength: 0)

                HStack(spacing: 4) {
                    durationAdjustButton(systemImage: "minus", label: "Decrease \(label)", disabled: value.wrappedValue <= range.lowerBound) {
                        value.wrappedValue = max(range.lowerBound, value.wrappedValue - 1)
                    }

                    durationAdjustButton(systemImage: "plus", label: "Increase \(label)", disabled: value.wrappedValue >= range.upperBound) {
                        value.wrappedValue = min(range.upperBound, value.wrappedValue + 1)
                    }
                }
            }
        }
        .padding(FLSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: FLRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FLRadius.md, style: .continuous)
                .strokeBorder(Color.flSeparator.opacity(0.45), lineWidth: 1)
        )
    }

    private func durationAdjustButton(systemImage: String, label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .frame(width: 28, height: 28)
                .background(Color.primary.opacity(disabled ? 0.025 : 0.065), in: RoundedRectangle(cornerRadius: FLRadius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(disabled ? Color.flTextTertiary : Color.flTextPrimary)
        .disabled(disabled)
        .accessibilityLabel(label)
    }

    // MARK: - Blocked apps

    private var blockedAppsSummary: some View {
        FLSurface {
            HStack(spacing: FLSpacing.sm) {
                Image(systemName: controller.config.blockedApps.isEmpty ? "shield.slash" : "shield.lefthalf.filled")
                    .font(.body)
                    .foregroundStyle(controller.config.blockedApps.isEmpty ? Color.flWarning : Color.flFocus)
                    .frame(width: 30, height: 30)
                    .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: FLRadius.sm, style: .continuous))
                    .symbolRenderingMode(.hierarchical)

                VStack(alignment: .leading, spacing: 2) {
                    Text(blockedAppsTitle)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Color.flTextPrimary)

                    Text(blockedAppsDetail)
                        .font(.caption)
                        .foregroundStyle(Color.flTextSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                FLStatusPill(label: controller.config.blockerMode.displayName)
            }
        }
    }

    private var blockedAppsTitle: String {
        if controller.config.blockedApps.isEmpty {
            return "No apps blocked"
        }

        return "\(controller.config.blockedApps.count) app\(controller.config.blockedApps.count == 1 ? "" : "s") guarded"
    }

    private var blockedAppsDetail: String {
        if controller.config.blockedApps.isEmpty {
            return "Add apps from Settings"
        }

        return controller.config.blockedApps.prefix(3).map(\.name).joined(separator: ", ")
    }

    // MARK: - Primary action

    @ViewBuilder
    private var primaryAction: some View {
        if controller.isSessionActive {
            Button {
                controller.stopSession()
            } label: {
                Label("Stop Session", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(FLActionButtonStyle(variant: .destructive))
            .controlSize(.large)
        } else {
            Button {
                controller.startFocus()
            } label: {
                Label("Start Focus", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(FLActionButtonStyle(variant: .primary))
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
    }
}
