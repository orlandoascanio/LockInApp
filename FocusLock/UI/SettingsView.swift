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
                // Groups lie on the canvas, a hairline between each.
                VStack(alignment: .leading, spacing: 0) {
                    switch tab {
                    case .general:
                        // Durations live on the Focus page, next to Start.
                        group(timerSoundSection)
                        group(appearanceSection)
                        group(hudSection)
                        group(generalSection)
                        group(permissionsSection, isLast: true)
                    case .blocking:
                        group(behaviourSection)
                        group(strictSection, isLast: true)
                    case .breaks:
                        group(longBreakSection)
                        group(sessionSection)
                        group(breakSuggestionsSection, isLast: true)
                    case .shortcuts:
                        group(hotkeySection, isLast: true)
                    }
                }
                .frame(maxWidth: Self.columnWidth, alignment: .leading)
                .padding(.horizontal, FLLayout.pageInset)
                .padding(.bottom, FLLayout.pageInset)
                .frame(maxWidth: .infinity)
            }
            .flScrollEdges(top: 0)

            if let message = controller.settingsMessage {
                Text(message)
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flInkSoft)
                    .frame(maxWidth: Self.columnWidth, alignment: .leading)
                    .padding(.horizontal, FLLayout.pageInset)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// One readable column, centred, as System Settings keeps its panes.
    private static let columnWidth: CGFloat = 660

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Settings")
                .font(FLTypography.largeTitle)
                .foregroundStyle(Color.flInk)
                .accessibilityAddTraits(.isHeader)

            FLSegmentedControl(
                options: Tab.allCases,
                selection: $tab,
                title: \.rawValue,
                accessibilityLabel: "Settings section"
            )
        }
        .frame(maxWidth: Self.columnWidth, alignment: .leading)
        .padding(.horizontal, FLLayout.pageInset)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
    }

    private var appearanceSection: some View {
        FLGroup(title: "Appearance") {
            FLSettingRow(title: "Look", detail: "Follow macOS, or keep Quietwhile light or dark.") {
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
    }

    // MARK: Sections

    private var behaviourSection: some View {
        FLGroup(title: "Default guarding behaviour", footer: "Individual apps can override this from the Blocked list.") {
            VStack(alignment: .leading, spacing: 10) {
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
                    .font(FLTypography.callout)
                    .foregroundStyle(Color.flInkSoft)
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 8)
        }
    }

    private var longBreakSection: some View {
        FLGroup(title: "Long break") {
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
                FLRowDivider()
                choiceRow(
                    label: "After",
                    options: LongBreakSettings.everyOptions,
                    selection: controller.config.longBreak.every,
                    title: { "\($0) blocks" },
                    onSelect: { every in controller.updateLongBreak { $0.every = every } }
                )
                FLRowDivider()
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

    private func ordinal(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)th"
    }

    private var sessionSection: some View {
        FLGroup(
            title: "When a break ends",
            footer: controller.config.breakEndBehavior == .autopilot
                ? "Idle \(controller.config.autoResume.graceMinutes) minutes after a break and Quietwhile takes the screen, counts down \(countdownLabel), then starts the next block. You can always start now, push it back, or end the cycle."
                : nil
        ) {
            VStack(alignment: .leading, spacing: 10) {
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
                    .font(FLTypography.callout)
                    .foregroundStyle(Color.flInkSoft)
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 8)

            if controller.config.breakEndBehavior == .autopilot {
                autopilotDetails
            }
        }
    }

    /// Only shown once autopilot is chosen — the two numbers that decide how
    /// patient it is before it takes the screen.
    @ViewBuilder
    private var autopilotDetails: some View {
        FLRowDivider()
        choiceRow(
            label: "Nudge after",
            options: AutoResumePlanner.graceOptions,
            selection: controller.config.autoResume.graceMinutes,
            title: { "\($0) min" },
            onSelect: { controller.updateAutoResumeGrace(minutes: $0) }
        )
        FLRowDivider()
        choiceRow(
            label: "Warning",
            options: AutoResumePlanner.countdownOptions,
            selection: controller.config.autoResume.countdownSeconds,
            title: { $0 < 60 ? "\($0) sec" : "\($0 / 60) min" },
            onSelect: { controller.updateAutoResumeCountdown(seconds: $0) }
        )
    }

    private var countdownLabel: String {
        let seconds = controller.config.autoResume.countdownSeconds
        return seconds < 60 ? "\(seconds) seconds" : "\(seconds / 60) minute\(seconds == 60 ? "" : "s")"
    }

    /// A number picked from a short list: a pop-up on the right of its row.
    private func choiceRow(
        label: String,
        detail: String? = nil,
        options: [Int],
        selection: Int,
        title: @escaping (Int) -> String,
        onSelect: @escaping (Int) -> Void
    ) -> some View {
        FLSettingRow(title: label, detail: detail) {
            FLMenuPicker(
                options: options.contains(selection) ? options : (options + [selection]).sorted(),
                selection: selection,
                title: title,
                onSelect: onSelect,
                width: 112,
                accessibilityLabel: label
            )
        }
    }

    private var timerSoundSection: some View {
        FLGroup(
            title: "When time is up",
            footer: "Sounds play when the timer runs out, even with notifications off or a Focus mode on. Choosing one plays it."
        ) {
            soundRow(
                label: "Focus ends",
                selection: Binding(
                    get: { controller.config.timerEndSound },
                    set: { controller.updateTimerEndSound($0) }
                )
            )
            FLRowDivider()
            soundRow(
                label: "Break ends",
                selection: Binding(
                    get: { controller.config.breakEndSound },
                    set: { controller.updateBreakEndSound($0) }
                )
            )
            FLRowDivider()
            FLSettingRow(
                title: "Speak up from the notch",
                detail: "When a block or a break ends, the notch opens with what's next and the time still running. A minute before focus ends it offers five more. On a Mac without a notch it drops from the top of the menu bar."
            ) {
                HStack(spacing: 12) {
                    if controller.config.notchAlertsEnabled {
                        Button("Show me") { controller.previewNotchIsland() }
                            .buttonStyle(FLInlineButtonStyle())
                    }
                    FLSwitch(
                        isOn: Binding(
                            get: { controller.config.notchAlertsEnabled },
                            set: { controller.updateNotchAlerts(enabled: $0) }
                        ),
                        label: "Speak up from the notch"
                    )
                }
            }
        }
    }

    private func soundRow(label: String, selection: Binding<TimerEndSound>) -> some View {
        FLSettingRow(title: label) {
            FLMenuPicker(
                options: TimerEndSound.allCases,
                selection: selection.wrappedValue,
                title: \.displayName,
                onSelect: { selection.wrappedValue = $0 },
                width: 140,
                accessibilityLabel: label
            )
        }
    }

    private var hudSection: some View {
        FLGroup(title: "Floating HUD") {
            toggleRow(
                title: "Pin the countdown above every window",
                detail: "A small pill stays on screen during a session so the time left is always one glance away. Drag it anywhere; it snaps to edges and corners. Right-click it for more.",
                isOn: Binding(
                    get: { controller.config.pinnedHUDEnabled },
                    set: { controller.updatePinnedHUD(enabled: $0) }
                )
            )

            if controller.config.pinnedHUDEnabled {
                FLRowDivider()
                FLSettingRow(title: "Size") {
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
                FLRowDivider()
                FLSettingRow(title: "While you work", detail: "How far it fades when the pointer is elsewhere.") {
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
                FLRowDivider()
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

    private var strictSection: some View {
        FLGroup(title: "Strict mode", footer: "Schedules can make their own blocks strict too.") {
            toggleRow(
                title: "Run every block strict",
                detail: "During focus you can't end or skip the block, allow a guarded app, remove anything from the Blocked list, or quit Quietwhile. If Quietwhile is force-quit, it reopens and carries on. Breaks stay yours.",
                isOn: Binding(
                    get: { controller.config.strict.enabled },
                    set: { controller.updateStrictMode(enabled: $0) }
                )
            )
            .disabled(controller.isStrictLocked)

            FLRowDivider()

            choiceRow(
                label: "Emergency exit wait",
                detail: "The emergency exit asks you to type a sentence, then waits this long before ending the block.",
                options: [60, 120, 300, 600],
                selection: controller.config.strict.escapeWaitSeconds,
                title: { "\($0 / 60) min" },
                onSelect: { controller.updateEscapeWait(seconds: $0) }
            )
            .disabled(controller.isStrictLocked)
        }
    }

    private var breakSuggestionsSection: some View {
        FLGroup(title: "Break suggestions") {
            toggleRow(
                title: "Suggest something to do on each break",
                detail: "Picked to fit the break: something calm for a short one, a walk for a long one, and moving after a long run. Shown in the break notification, on the Focus page, and in the floating HUD.",
                isOn: Binding(
                    get: { controller.config.breakSuggestions.enabled },
                    set: { value in controller.updateBreakSuggestions { $0.enabled = value } }
                )
            )

            FLRowDivider()

            VStack(alignment: .leading, spacing: 12) {
                FlowLayout(spacing: 8) {
                    ForEach(BreakSuggestionKind.allCases) { kind in
                        suggestionChip(kind)
                    }
                }
                .disabled(!controller.config.breakSuggestions.enabled)
                .opacity(controller.config.breakSuggestions.enabled ? 1 : 0.5)

                suggestionPreview
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)

            FLRowDivider()

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

    @ViewBuilder
    private var suggestionPreview: some View {
        HStack(spacing: 10) {
            Text("Preview")
                .font(FLTypography.callout)
                .foregroundStyle(Color.flInkSoft)
            FLMenuPicker(
                options: BreakSuggestionKind.allCases,
                selection: previewKind,
                title: \.title,
                onSelect: { kind in withAnimation(FLAnimation.standard) { previewKind = kind } },
                placeholder: "Choose one…",
                accessibilityLabel: "Preview a break suggestion"
            )

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
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: FLRadius.lg, style: .continuous)
                        .fill(Color.flRestSurface)
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
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(isOn ? Color.flAccentDeep : Color.flInkSoft)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(Capsule().fill(isOn ? Color.flAccentSoft : Color.flSunken))
            .contentShape(Capsule())
        }
        .help(isOn ? "On. Click to stop suggesting \(kind.title.lowercased())." : "Off. Click to suggest \(kind.title.lowercased()).")
        .buttonStyle(.plain)
        .accessibilityLabel(kind.title)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    private var hotkeySection: some View {
        FLGroup(title: "Keyboard shortcuts") {
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
                    FLRowDivider()
                    ShortcutRecorder(action: action)
                }
            }
        }
    }

    private var generalSection: some View {
        FLGroup(title: "General") {
            toggleRow(
                title: "Open Quietwhile at login",
                detail: "Needed for schedules to start on their own.",
                isOn: Binding(
                    get: { controller.launchAtLogin },
                    set: { controller.setLaunchAtLogin($0) }
                )
            )
            FLRowDivider()
            toggleRow(
                title: "Ask before ending a session",
                detail: "Also before skipping a focus block, or quitting while one is running.",
                isOn: Binding(
                    get: { controller.config.confirmBeforeEnding },
                    set: { controller.updateConfirmBeforeEnding($0) }
                )
            )
            FLRowDivider()
            UpdatesRow()
        }
    }

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Permissions")
                .font(FLTypography.title)
                .foregroundStyle(Color.flInk)
                .accessibilityAddTraits(.isHeader)
            PermissionsPanel(
                permissions: controller.permissions,
                guardsWebsites: !controller.config.blockedSites.isEmpty
            )
        }
    }

    // MARK: Building blocks

    @ViewBuilder
    private func group(_ content: some View, isLast: Bool = false) -> some View {
        content
            .padding(.vertical, 20)
        if !isLast {
            FLRule()
        }
    }

    private func toggleRow(title: String, detail: String, isOn: Binding<Bool>) -> some View {
        FLToggleRow(title: title, detail: detail, isOn: isOn)
    }
}

private struct UpdatesRow: View {
    @ObservedObject private var updates = UpdateController.shared

    var body: some View {
        if updates.isAvailable {
            FLSettingRow(
                title: "Check for updates automatically",
                detail: "New versions are signed; Quietwhile checks them before installing."
            ) {
                HStack(spacing: 12) {
                    Button("Check Now") { updates.checkForUpdates() }
                        .buttonStyle(FLInlineButtonStyle())
                    FLSwitch(
                        isOn: Binding(
                            get: { updates.automaticallyChecks },
                            set: { updates.automaticallyChecks = $0 }
                        ),
                        label: "Check for updates automatically"
                    )
                }
            }
        } else {
            FLSettingRow(
                title: "Updates",
                detail: "Off in this build. They switch on once Scripts/release/setup_sparkle.sh has added a signing key."
            ) {
                EmptyView()
            }
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
