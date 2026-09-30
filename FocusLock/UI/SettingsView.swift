import FocusLockCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var controller: MenuBarController

    enum Tab: String, CaseIterable {
        case general = "General"
        case blocking = "Blocking"
        case breaks = "Breaks"
        case shortcuts = "Shortcuts"
    }

    @State private var tab: Tab = .general

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    FLRule()
                    switch tab {
                    case .general:
                        durationsSection
                        FLRule()
                        appearanceSection
                        FLRule()
                        hudSection
                        FLRule()
                        generalSection
                    case .blocking:
                        behaviourSection
                        FLRule()
                        strictSection
                    case .breaks:
                        sessionSection
                        FLRule()
                        breakSuggestionsSection
                    case .shortcuts:
                        hotkeySection
                    }
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

            Text("Durations, guarding, strict mode, shortcuts, and how LockIn shows itself.")
                .font(FLTypography.caption)
                .foregroundStyle(Color.flInkSoft)

            FLSegmentedControl(
                options: Tab.allCases,
                selection: $tab,
                title: \.rawValue,
                accessibilityLabel: "Settings section"
            )
            .padding(.top, 16)
        }
        .padding(.horizontal, 26)
        .padding(.top, 28)
        .padding(.bottom, 20)
    }

    private var appearanceSection: some View {
        section("Appearance") {
            VStack(alignment: .leading, spacing: 12) {
                FLSegmentedControl(
                    options: AppearancePreference.allCases,
                    selection: Binding(
                        get: { controller.config.appearance },
                        set: { controller.updateAppearance($0) }
                    ),
                    title: \.displayName,
                    accessibilityLabel: "Appearance"
                )

                Text("Dark keeps the same moss palette on charcoal, for late sessions. The guard screen and HUD follow along.")
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flInkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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
                    range: AppConfig.focusMinutesRange
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
                FLSegmentedControl(
                    options: BlockerMode.allCases,
                    selection: Binding(
                        get: { controller.config.blockerMode },
                        set: { controller.updateBlockerMode($0) }
                    ),
                    title: \.displayName,
                    accessibilityLabel: "Default guarding behaviour"
                )
                .disabled(controller.isStrictLocked)

                Text(controller.config.blockerMode.helperText)
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flInkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Individual apps can override this from the Blocked list.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.flInkSoft.opacity(0.8))
            }
        }
    }

    private var sessionSection: some View {
        section("When a break ends") {
            VStack(alignment: .leading, spacing: 12) {
                FLSegmentedControl(
                    options: BreakEndBehavior.allCases,
                    selection: Binding(
                        get: { controller.config.breakEndBehavior },
                        set: { controller.updateBreakEndBehavior($0) }
                    ),
                    title: \.displayName,
                    accessibilityLabel: "When a break ends"
                )

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

    private var strictSection: some View {
        section("Strict mode") {
            VStack(alignment: .leading, spacing: 14) {
                toggleRow(
                    title: "Run every block strict",
                    detail: "During focus you can't end or skip the block, allow a guarded app, remove anything from the Blocked list, or quit LockIn. If LockIn is force-quit, it reopens and carries on. Breaks stay yours.",
                    isOn: Binding(
                        get: { controller.config.strict.enabled },
                        set: { controller.updateStrictMode(enabled: $0) }
                    )
                )
                .disabled(controller.isStrictLocked)

                choiceRow(
                    label: "Exit wait",
                    options: [60, 120, 300, 600],
                    selection: controller.config.strict.escapeWaitSeconds,
                    title: { "\($0 / 60) min" },
                    onSelect: { controller.updateEscapeWait(seconds: $0) }
                )
                .disabled(controller.isStrictLocked)

                Text("The emergency exit asks you to type a sentence, then waits this long before ending the block. Schedules can make their own blocks strict too.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.flInkSoft.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 560, alignment: .leading)
            }
        }
    }

    private var breakSuggestionsSection: some View {
        section("Break suggestions") {
            VStack(alignment: .leading, spacing: 14) {
                toggleRow(
                    title: "Suggest something to do on each break",
                    detail: "Shown in the break notification, on the Focus page, and in the floating HUD.",
                    isOn: Binding(
                        get: { controller.config.breakSuggestions.enabled },
                        set: { value in controller.updateBreakSuggestions { $0.enabled = value } }
                    )
                )

                HStack(spacing: 8) {
                    ForEach(BreakSuggestionKind.allCases) { kind in
                        suggestionChip(kind)
                    }
                }
                .disabled(!controller.config.breakSuggestions.enabled)
                .opacity(controller.config.breakSuggestions.enabled ? 1 : 0.5)

                toggleRow(
                    title: "20-20-20 reminder during long blocks",
                    detail: "Every 20 minutes of focus, a silent nudge to look about 20 feet away for 20 seconds.",
                    isOn: Binding(
                        get: { controller.config.breakSuggestions.eyeReminderDuringFocus },
                        set: { value in controller.updateBreakSuggestions { $0.eyeReminderDuringFocus = value } }
                    )
                )
            }
        }
    }

    private func suggestionChip(_ kind: BreakSuggestionKind) -> some View {
        let isOn = controller.config.breakSuggestions.kinds.contains(kind)
        return Button {
            controller.updateBreakSuggestions { settings in
                if isOn {
                    settings.kinds.remove(kind)
                } else {
                    settings.kinds.insert(kind)
                }
            }
        } label: {
            Text(kind.title)
                .font(.system(size: 12, weight: isOn ? .semibold : .regular))
                .foregroundStyle(isOn ? Color.flAccentDeep : Color.flInkSoft)
                .padding(.horizontal, 12)
                .frame(height: 26)
                .background(Capsule().fill(isOn ? Color.flAccentSoft.opacity(0.6) : .clear))
                .overlay(Capsule().strokeBorder(isOn ? Color.flAccentDeep.opacity(0.35) : Color.flHairline, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(kind.title)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    private var hotkeySection: some View {
        section("Keyboard shortcuts") {
            VStack(alignment: .leading, spacing: 12) {
                toggleRow(
                    title: "Global shortcuts",
                    detail: "Work from any app, even when LockIn is in the background. Strict blocks ignore stop and skip.",
                    isOn: Binding(
                        get: { controller.config.hotkeys.enabled },
                        set: { value in controller.updateHotkeys { $0.enabled = value } }
                    )
                )

                if controller.config.hotkeys.enabled {
                    ForEach(HotkeyAction.allCases) { action in
                        ShortcutRecorder(action: action)
                    }
                }
            }
        }
    }

    private var generalSection: some View {
        section("General") {
            VStack(alignment: .leading, spacing: 14) {
                toggleRow(
                    title: "Open LockIn at login",
                    detail: "Needed for schedules to start on their own.",
                    isOn: Binding(
                        get: { controller.launchAtLogin },
                        set: { controller.setLaunchAtLogin($0) }
                    )
                )

                UpdatesRow()
            }
        }
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

private struct UpdatesRow: View {
    @ObservedObject private var updates = UpdateController.shared

    var body: some View {
        if updates.isAvailable {
            HStack(alignment: .top, spacing: FLSpacing.md) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Check for updates automatically")
                        .font(FLTypography.body)
                        .foregroundStyle(Color.flInk)
                    Text("New versions are signed; LockIn checks them before installing.")
                        .font(FLTypography.caption)
                        .foregroundStyle(Color.flInkSoft)
                }
                Spacer(minLength: FLSpacing.md)
                Button("Check now") { updates.checkForUpdates() }
                    .buttonStyle(FLLinkButtonStyle())
                Toggle("", isOn: Binding(
                    get: { updates.automaticallyChecks },
                    set: { updates.automaticallyChecks = $0 }
                ))
                .toggleStyle(.switch)
                .tint(Color.flAccentDeep)
                .labelsHidden()
                .accessibilityLabel("Check for updates automatically")
            }
            .frame(maxWidth: 560, alignment: .leading)
        } else {
            Text("Updates are off in this build. They switch on once Scripts/release/setup_sparkle.sh has added a signing key.")
                .font(FLTypography.caption)
                .foregroundStyle(Color.flInkSoft)
        }
    }
}
