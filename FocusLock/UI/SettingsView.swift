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
    /// The break suggestion being previewed, if any.
    @State private var previewKind: BreakSuggestionKind?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    FLRule()
                    switch tab {
                    case .general:
                        // Durations live on the Focus page, next to Start.
                        timerSoundSection
                        FLRule()
                        appearanceSection
                        FLRule()
                        hudSection
                        FLRule()
                        generalSection
                        FLRule()
                        permissionsSection
                    case .blocking:
                        behaviourSection
                        FLRule()
                        strictSection
                    case .breaks:
                        longBreakSection
                        FLRule()
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

            Text("Sounds, guarding, strict mode, breaks, shortcuts, and how Quietwhile shows itself.")
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
            FLSegmentedControl(
                options: AppearancePreference.allCases,
                selection: Binding(
                    get: { controller.config.appearance },
                    set: { controller.updateAppearance($0) }
                ),
                title: \.displayName,
                accessibilityLabel: "Appearance"
            )
        }
    }

    // MARK: Sections

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
                    .foregroundStyle(Color.flInkSoft)
            }
        }
    }

    private var longBreakSection: some View {
        section("Long break") {
            VStack(alignment: .leading, spacing: 14) {
                toggleRow(
                    title: "Take a longer break after a set of blocks",
                    detail: controller.config.breakMinutes > 0
                        ? "Every \(ordinal(controller.config.longBreak.every)) block in a run ends in a \(controller.config.longBreak.minutes)-minute break instead of \(controller.config.breakMinutes). The count starts over when a run ends."
                        : "Your blocks have no break right now, so there is nothing to lengthen. Set a break on the Focus page.",
                    isOn: Binding(
                        get: { controller.config.longBreak.enabled },
                        set: { enabled in controller.updateLongBreak { $0.enabled = enabled } }
                    )
                )

                if controller.config.longBreak.enabled {
                    choiceRow(
                        label: "After",
                        options: LongBreakSettings.everyOptions,
                        selection: controller.config.longBreak.every,
                        title: { "\($0) blocks" },
                        onSelect: { every in controller.updateLongBreak { $0.every = every } }
                    )

                    choiceRow(
                        label: "Length",
                        options: LongBreakSettings.minutesOptions,
                        selection: controller.config.longBreak.minutes,
                        title: { "\($0) min" },
                        onSelect: { minutes in controller.updateLongBreak { $0.minutes = minutes } }
                    )
                }
            }
        }
    }

    private func ordinal(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)th"
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

            Text("Idle \(controller.config.autoResume.graceMinutes) minutes after a break and Quietwhile takes the screen, counts down \(countdownLabel), then starts the next block. You can always start now, push it back, or end the cycle.")
                .font(.system(size: 11))
                .foregroundStyle(Color.flInkSoft)
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

    private var timerSoundSection: some View {
        section("When time is up") {
            VStack(alignment: .leading, spacing: 12) {
                soundRow(
                    label: "Focus ends",
                    selection: Binding(
                        get: { controller.config.timerEndSound },
                        set: { controller.updateTimerEndSound($0) }
                    )
                )

                soundRow(
                    label: "Break ends",
                    selection: Binding(
                        get: { controller.config.breakEndSound },
                        set: { controller.updateBreakEndSound($0) }
                    )
                )

                Text("Plays when the timer runs out, even with notifications off or a Focus mode on. Choosing one plays it.")
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flInkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                toggleRow(
                    title: "Speak up from the notch",
                    detail: "When a block or a break ends, the notch opens with what's next and the time still running. A minute before focus ends it offers five more. On a Mac without a notch it drops from the top of the menu bar.",
                    isOn: Binding(
                        get: { controller.config.notchAlertsEnabled },
                        set: { controller.updateNotchAlerts(enabled: $0) }
                    )
                )

                if controller.config.notchAlertsEnabled {
                    Button("Show me") { controller.previewNotchIsland() }
                        .buttonStyle(FLLinkButtonStyle(tint: .flAccentDeep))
                }
            }
        }
    }

    private func soundRow(label: String, selection: Binding<TimerEndSound>) -> some View {
        HStack(spacing: FLSpacing.md) {
            Text(label)
                .font(FLTypography.body)
                .foregroundStyle(Color.flInk)
                .frame(width: 120, alignment: .leading)

            Picker(label, selection: selection) {
                ForEach(TimerEndSound.allCases) { sound in
                    Text(sound.displayName).tag(sound)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()
        }
    }

    private var hudSection: some View {
        section("Floating HUD") {
            VStack(alignment: .leading, spacing: 14) {
                toggleRow(
                    title: "Pin the countdown above every window",
                    detail: "A small pill stays on screen during a session so the time left is always one glance away. Drag it anywhere; it snaps to edges and corners. Right-click it for more.",
                    isOn: Binding(
                        get: { controller.config.pinnedHUDEnabled },
                        set: { controller.updatePinnedHUD(enabled: $0) }
                    )
                )

                if controller.config.pinnedHUDEnabled {
                    HStack(spacing: FLSpacing.md) {
                        Text("Size")
                            .font(FLTypography.body)
                            .foregroundStyle(Color.flInk)
                            .frame(width: 120, alignment: .leading)
                        FLSegmentedControl(
                            options: HUDSettings.Size.allCases,
                            selection: Binding(
                                get: { controller.config.hud.size },
                                set: { size in controller.updateHUD { $0.size = size } }
                            ),
                            title: \.displayName,
                            accessibilityLabel: "HUD size"
                        )
                    }

                    HStack(spacing: FLSpacing.md) {
                        Text("While you work")
                            .font(FLTypography.body)
                            .foregroundStyle(Color.flInk)
                            .frame(width: 120, alignment: .leading)
                        FLSegmentedControl(
                            options: HUDSettings.restingOpacityChoices,
                            selection: Binding(
                                get: { controller.config.hud.restingOpacity },
                                set: { opacity in controller.updateHUD { $0.restingOpacity = opacity } }
                            ),
                            title: { $0 >= 1 ? "Don't fade" : "\(Int(($0 * 100).rounded()))%" },
                            accessibilityLabel: "HUD opacity while you work"
                        )
                    }

                    toggleRow(
                        title: "Let clicks pass through it",
                        detail: "For reading: clicks reach whatever is under the HUD. Hold Option to use it.",
                        isOn: Binding(
                            get: { controller.config.hud.clickThrough },
                            set: { enabled in controller.updateHUD { $0.clickThrough = enabled } }
                        )
                    )
                }
            }
        }
    }

    private var strictSection: some View {
        section("Strict mode") {
            VStack(alignment: .leading, spacing: 14) {
                toggleRow(
                    title: "Run every block strict",
                    detail: "During focus you can't end or skip the block, allow a guarded app, remove anything from the Blocked list, or quit Quietwhile. If Quietwhile is force-quit, it reopens and carries on. Breaks stay yours.",
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
                    .foregroundStyle(Color.flInkSoft)
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
                    detail: "Picked to fit the break: something calm for a short one, a walk for a long one, and moving after a long run. Shown in the break notification, on the Focus page, and in the floating HUD.",
                    isOn: Binding(
                        get: { controller.config.breakSuggestions.enabled },
                        set: { value in controller.updateBreakSuggestions { $0.enabled = value } }
                    )
                )

                FlowLayout(spacing: 8) {
                    ForEach(BreakSuggestionKind.allCases) { kind in
                        suggestionChip(kind)
                    }
                }
                .frame(maxWidth: 560, alignment: .leading)
                .disabled(!controller.config.breakSuggestions.enabled)
                .opacity(controller.config.breakSuggestions.enabled ? 1 : 0.5)

                suggestionPreview

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

    @ViewBuilder
    private var suggestionPreview: some View {
        HStack(spacing: 10) {
            Text("Preview")
                .font(FLTypography.caption)
                .foregroundStyle(Color.flInkSoft)
            Menu {
                ForEach(BreakSuggestionKind.allCases) { kind in
                    Button {
                        withAnimation(FLAnimation.standard) { previewKind = kind }
                    } label: {
                        Label(kind.title, systemImage: kind.systemImage)
                    }
                }
            } label: {
                Text(previewKind?.title ?? "Choose one…")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            if previewKind != nil {
                Button("Close") {
                    withAnimation(FLAnimation.standard) { previewKind = nil }
                }
                .buttonStyle(FLLinkButtonStyle())
            }
        }

        if let kind = previewKind, let suggestion = BreakSuggestions.suggestion(of: kind, cycle: 1) {
            BreakGuideView(suggestion: suggestion, isPreview: true)
                .padding(18)
                .frame(maxWidth: 560, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: FLRadius.lg, style: .continuous)
                        .fill(Color.flSunken)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: FLRadius.lg, style: .continuous)
                        .strokeBorder(Color.flHairline, lineWidth: 1)
                )
                .transition(.opacity)
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
            HStack(spacing: 6) {
                Image(systemName: isOn ? "checkmark" : kind.systemImage)
                    .font(.system(size: 11, weight: isOn ? .bold : .regular))
                    .frame(width: 14)
                Text(kind.title)
                    .font(.system(size: 12, weight: isOn ? .semibold : .regular))
            }
            .foregroundStyle(isOn ? Color.flAccentDeep : Color.flInkSoft)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(Capsule().fill(isOn ? Color.flAccentSoft.opacity(0.6) : .clear))
            .overlay(
                Capsule().strokeBorder(
                    isOn ? Color.flAccentDeep.opacity(0.35) : Color.flHairline,
                    style: StrokeStyle(lineWidth: 1, dash: isOn ? [] : [3, 2])
                )
            )
            .contentShape(Capsule())
        }
        .help(isOn ? "On. Click to stop suggesting \(kind.title.lowercased())." : "Off. Click to suggest \(kind.title.lowercased()).")
        .buttonStyle(.plain)
        .accessibilityLabel(kind.title)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    private var hotkeySection: some View {
        section("Keyboard shortcuts") {
            VStack(alignment: .leading, spacing: 12) {
                toggleRow(
                    title: "Global shortcuts",
                    detail: "Work from any app, even when Quietwhile is in the background. Strict blocks ignore stop and skip.",
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
                    title: "Open Quietwhile at login",
                    detail: "Needed for schedules to start on their own.",
                    isOn: Binding(
                        get: { controller.launchAtLogin },
                        set: { controller.setLaunchAtLogin($0) }
                    )
                )

                toggleRow(
                    title: "Ask before ending a session",
                    detail: "Also before skipping a focus block, or quitting while one is running.",
                    isOn: Binding(
                        get: { controller.config.confirmBeforeEnding },
                        set: { controller.updateConfirmBeforeEnding($0) }
                    )
                )

                UpdatesRow()
            }
        }
    }

    private var permissionsSection: some View {
        section("Permissions") {
            PermissionsPanel(
                permissions: controller.permissions,
                guardsWebsites: !controller.config.blockedSites.isEmpty
            )
            .frame(maxWidth: 560)
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
            .frame(maxWidth: 520, alignment: .leading)

            Spacer(minLength: FLSpacing.md)

            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .tint(Color.flAccentDeep)
                .labelsHidden()
                .accessibilityLabel(title)
        }
        // Switches line up on the right edge, as on Blocked and Schedules;
        // the words keep a readable measure.
        .frame(maxWidth: .infinity, alignment: .leading)
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
                    Text("New versions are signed; Quietwhile checks them before installing.")
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
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text("Updates are off in this build. They switch on once Scripts/release/setup_sparkle.sh has added a signing key.")
                .font(FLTypography.caption)
                .foregroundStyle(Color.flInkSoft)
        }
    }
}

/// Lays chips out in rows, wrapping to the next row when one is full.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var indices: [Int] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > width, !rows[rows.count - 1].indices.isEmpty {
                let last = rows[rows.count - 1]
                rows.append(Row(y: last.y + last.height + spacing))
            }
            let current = rows.count - 1
            rows[current].width = rows[current].indices.isEmpty ? size.width : rows[current].width + spacing + size.width
            rows[current].height = max(rows[current].height, size.height)
            rows[current].indices.append(index)
        }
        return rows
    }
}
