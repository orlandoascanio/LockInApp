import FocusLockCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var controller: MenuBarController

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    FLRule()
                    durationsSection
                    FLRule()
                    behaviourSection
                    FLRule()
                    sessionSection
                    FLRule()
                    hudSection
                }
            }

            if let message = controller.settingsMessage {
                FLRule()
                Text(message)
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flInkSoft)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 10)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Settings")
                .font(FLTypography.display)
                .foregroundStyle(Color.flInk)

            Text("Durations, guarding behaviour, and how LockIn shows itself.")
                .font(FLTypography.caption)
                .foregroundStyle(Color.flInkSoft)
        }
        .padding(.horizontal, 26)
        .padding(.top, 28)
        .padding(.bottom, 20)
    }

    // MARK: Sections

    private var durationsSection: some View {
        section("Durations") {
            HStack(spacing: FLSpacing.xl) {
                FLDurationField(
                    label: "Focus",
                    minutes: Binding(
                        get: { controller.config.focusMinutes },
                        set: { controller.updateFocusMinutes($0) }
                    ),
                    range: 1...180
                )

                FLDurationField(
                    label: "Break",
                    minutes: Binding(
                        get: { controller.config.breakMinutes },
                        set: { controller.updateBreakMinutes($0) }
                    ),
                    range: 0...60
                )

                Spacer()
            }
        }
    }

    private var behaviourSection: some View {
        section("Default guarding behaviour") {
            VStack(alignment: .leading, spacing: 12) {
                // A stock segmented picker paints its selection in the system
                // accent colour, which fights the palette. This one is ours.
                HStack(spacing: 0) {
                    ForEach(BlockerMode.allCases) { mode in
                        behaviourOption(mode)
                    }
                }
                .padding(3)
                .background(
                    Capsule().fill(Color.flCanvasWarm)
                )
                .overlay(
                    Capsule().strokeBorder(Color.flHairline, lineWidth: 1)
                )
                .fixedSize()

                Text(controller.config.blockerMode.helperText)
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flInkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Individual apps can override this from the Blocked apps list.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.flInkSoft.opacity(0.8))
            }
        }
    }

    private var sessionSection: some View {
        section("When a break ends") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 0) {
                    ForEach(BreakEndBehavior.allCases) { behavior in
                        breakEndOption(behavior)
                    }
                }
                .padding(3)
                .background(
                    Capsule().fill(Color.flCanvasWarm)
                )
                .overlay(
                    Capsule().strokeBorder(Color.flHairline, lineWidth: 1)
                )
                .fixedSize()

                Text(controller.config.breakEndBehavior.helperText)
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flInkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                if controller.config.breakEndBehavior == .autopilot {
                    autopilotDetails
                }
            }
        }
    }

    /// Only shown once autopilot is chosen — the two numbers that decide how
    /// patient it is before it takes the screen.
    private var autopilotDetails: some View {
        VStack(alignment: .leading, spacing: 14) {
            choiceRow(
                label: "Nudge after",
                options: AutoResumePlanner.graceOptions,
                selection: controller.config.autoResume.graceMinutes,
                title: { "\($0) min" },
                onSelect: { controller.updateAutoResumeGrace(minutes: $0) }
            )

            choiceRow(
                label: "Warning",
                options: AutoResumePlanner.countdownOptions,
                selection: controller.config.autoResume.countdownSeconds,
                title: { $0 < 60 ? "\($0) sec" : "\($0 / 60) min" },
                onSelect: { controller.updateAutoResumeCountdown(seconds: $0) }
            )

            Text("Idle \(controller.config.autoResume.graceMinutes) minutes after a break and LockIn takes the screen, counts down \(countdownLabel), then starts the next block. You can always start now, push it back, or end the cycle.")
                .font(.system(size: 11))
                .foregroundStyle(Color.flInkSoft.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 560, alignment: .leading)
        }
        .padding(.top, 4)
    }

    private var countdownLabel: String {
        let seconds = controller.config.autoResume.countdownSeconds
        return seconds < 60 ? "\(seconds) seconds" : "\(seconds / 60) minute\(seconds == 60 ? "" : "s")"
    }

    private func breakEndOption(_ behavior: BreakEndBehavior) -> some View {
        let isSelected = controller.config.breakEndBehavior == behavior

        return Button {
            controller.updateBreakEndBehavior(behavior)
        } label: {
            Text(behavior.displayName)
                .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.flCanvas : Color.flInkSoft)
                .padding(.horizontal, 16)
                .frame(height: 28)
                .background(
                    Capsule().fill(isSelected ? Color.flAccentDeep : .clear)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(behavior.displayName)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func choiceRow(
        label: String,
        options: [Int],
        selection: Int,
        title: @escaping (Int) -> String,
        onSelect: @escaping (Int) -> Void
    ) -> some View {
        HStack(spacing: FLSpacing.md) {
            Text(label)
                .font(FLTypography.body)
                .foregroundStyle(Color.flInk)
                .frame(width: 86, alignment: .leading)

            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let isSelected = option == selection

                    Button {
                        onSelect(option)
                    } label: {
                        Text(title(option))
                            .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? Color.flAccentDeep : Color.flInkSoft)
                            .padding(.horizontal, 12)
                            .frame(height: 26)
                            .background(
                                Capsule().fill(isSelected ? Color.flAccentSoft.opacity(0.6) : .clear)
                            )
                            .overlay(
                                Capsule().strokeBorder(
                                    isSelected ? Color.flAccentDeep.opacity(0.35) : Color.flHairline,
                                    lineWidth: 1
                                )
                            )
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(label) \(title(option))")
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
        }
    }

    private var hudSection: some View {
        section("Floating HUD") {
            toggleRow(
                title: "Pin the countdown above every window",
                detail: "A thin strip stays on screen during a session so the time left is always one glance away.",
                isOn: Binding(
                    get: { controller.config.pinnedHUDEnabled },
                    set: { controller.updatePinnedHUD(enabled: $0) }
                )
            )
        }
    }

    private func behaviourOption(_ mode: BlockerMode) -> some View {
        let isSelected = controller.config.blockerMode == mode

        return Button {
            controller.updateBlockerMode(mode)
        } label: {
            Text(mode.displayName)
                .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.flCanvas : Color.flInkSoft)
                .padding(.horizontal, 16)
                .frame(height: 28)
                .background(
                    Capsule().fill(isSelected ? Color.flAccentDeep : .clear)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.displayName)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: Building blocks

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            FLMicroLabel(text: title)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 26)
        .padding(.vertical, 22)
    }

    private func toggleRow(title: String, detail: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .top, spacing: FLSpacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(FLTypography.body)
                    .foregroundStyle(Color.flInk)

                Text(detail)
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flInkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: FLSpacing.md)

            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .tint(Color.flAccentDeep)
                .labelsHidden()
                .accessibilityLabel(title)
        }
        .frame(maxWidth: 560, alignment: .leading)
    }
}
