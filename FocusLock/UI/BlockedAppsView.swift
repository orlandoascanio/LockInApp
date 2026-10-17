import AppKit
import FocusLockCore
import SwiftUI

struct BlockedAppsView: View {
    @EnvironmentObject private var controller: MenuBarController
    @State private var filter = ""

    private var filteredApps: [BlockedApp] {
        let query = filter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return controller.config.blockedApps
        }

        return controller.config.blockedApps.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.bundleId.localizedCaseInsensitiveContains(query)
        }
    }

    enum Tab: String, CaseIterable, Identifiable {
        case apps = "Apps"
        case websites = "Websites"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .apps

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if tab == .websites {
                BlockedSitesSection()
            } else if controller.config.blockedApps.isEmpty {
                FLEmptyState(
                    systemImage: "shield",
                    title: "Nothing guarded yet",
                    detail: "Add the apps that pull you away, and Quietwhile will hold them back during focus."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 10) {
                        searchField
                        behaviourNote
                    }
                    .padding(.horizontal, FLLayout.pageInset)
                    .padding(.bottom, 18)

                    columnHeaders
                    appRows
                }
            }

            if let message = controller.settingsMessage {
                Text(message)
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flInkSoft)
                    .padding(.horizontal, FLLayout.pageInset)
                    .padding(.bottom, 12)
            }
        }
        .onAppear {
            // Arriving with a browser still unguarded means arriving to fix it.
            if controller.browserPermissionProblem != nil {
                tab = .websites
            }
        }
    }

    private var header: some View {
        HStack(alignment: .bottom, spacing: FLSpacing.md) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Blocked")
                        .font(FLTypography.largeTitle)
                        .foregroundStyle(Color.flInk)
                        .accessibilityAddTraits(.isHeader)

                    Text(subtitle)
                        .font(FLTypography.callout)
                        .foregroundStyle(Color.flInkSoft)
                }

                FLSegmentedControl(
                    options: Tab.allCases,
                    selection: $tab,
                    title: \.rawValue,
                    badge: { $0 == .websites && controller.browserPermissionProblem != nil },
                    accessibilityLabel: "Apps or websites"
                )
            }

            Spacer()

            if controller.isStrictLocked {
                Label("Strict block: you can add, not remove", systemImage: "lock.fill")
                    .font(FLTypography.callout)
                    .foregroundStyle(Color.flInkSoft)
            }

            if tab == .apps {
                Button {
                    controller.addBlockedAppFromPanel()
                } label: {
                    Label("Add app", systemImage: "plus")
                }
                .buttonStyle(FLActionButtonStyle(variant: .primary, minHeight: 34))
            }
        }
        .padding(.horizontal, FLLayout.pageInset)
        .padding(.top, 14)
        .padding(.bottom, 18)
    }

    private var subtitle: String {
        if tab == .websites {
            let active = controller.activeBlockedSites.count
            let total = controller.config.blockedSites.count
            guard total > 0 else { return "Guarded during focus only" }
            return active == total
                ? "\(total) guarded · during focus only"
                : "\(active) of \(total) guarded · during focus only"
        }
        let active = controller.activeBlockedApps.count
        let total = controller.config.blockedApps.count

        if total == 0 {
            return "Guarded during focus only"
        }

        if active == total {
            return "\(total) guarded · during focus only"
        }

        return "\(active) of \(total) guarded · during focus only"
    }

    @FocusState private var filterFocused: Bool

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11.5))
                .foregroundStyle(Color.flInkSoft)

            TextField("Filter applications", text: $filter)
                .textFieldStyle(.plain)
                .font(FLTypography.body)
                .foregroundStyle(Color.flInk)
                .focused($filterFocused)
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(Color.flSunken, in: RoundedRectangle(cornerRadius: FLRadius.md + 1, style: .continuous))
        .overlay(
            // The same moss ring as every other field, not the Mac's accent.
            RoundedRectangle(cornerRadius: FLRadius.md + 1, style: .continuous)
                .strokeBorder(filterFocused ? Color.flAccentDeep : .clear, lineWidth: 1.5)
        )
        .animation(.easeOut(duration: 0.12), value: filterFocused)
    }

    /// What the three behaviours actually do, said where you choose them.
    /// Guard Screen is the reason Quietwhile exists, so it leads.
    private var behaviourNote: some View {
        Text("Guard Screen keeps an app, and your call, running behind “Not now.” Hide Only tucks it out of sight. Quit App closes it, and any call with it.")
            .font(FLTypography.caption)
            .foregroundStyle(Color.flInkSoft)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var columnHeaders: some View {
        HStack(spacing: 0) {
            FLColumnLabel(text: "Application").frame(width: 230, alignment: .leading)
            FLColumnLabel(text: "Behaviour").frame(width: 150, alignment: .leading)
            FLColumnLabel(text: "Blocked today").frame(width: 120, alignment: .leading)
            Spacer(minLength: 0)
            FLColumnLabel(text: "Active")
        }
        .padding(.horizontal, FLLayout.pageInset)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            FLRule().padding(.horizontal, FLLayout.pageInset)
        }
    }

    private var appRows: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredApps) { app in
                    BlockedAppRow(app: app)
                    FLRowDivider(inset: FLLayout.pageInset)
                }
            }
        }
    }
}

private struct BlockedAppRow: View {
    @EnvironmentObject private var controller: MenuBarController
    let app: BlockedApp

    @State private var isHovering = false
    /// Keyboard focus on Remove shows it, so a focus ring never lands on
    /// something invisible.
    @FocusState private var removeFocused: Bool
    /// A behaviour waiting on "this ends your calls" being confirmed.
    @State private var pendingBehavior: BlockerMode??

    private var behavior: BlockerMode {
        app.effectiveBehavior(default: controller.config.blockerMode)
    }

    private var quitsCalls: Bool {
        app.isCallingApp && behavior == .quitApp
    }

    private var blockedToday: Int {
        controller.blockedTodayCount(for: app)
    }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 11) {
                FLAppIcon(bundleId: app.bundleId, size: 26, isDimmed: !app.isEnabled)

                VStack(alignment: .leading, spacing: 1) {
                    Text(app.name)
                        .font(.system(size: 13))
                        .foregroundStyle(app.isEnabled ? Color.flInk : Color.flInkSoft)
                        .lineLimit(1)

                    if quitsCalls {
                        Text("Quitting ends its calls")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.flClayInk)
                            .lineLimit(1)
                    } else if isHovering {
                        Text(app.bundleId)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.flInkSoft)
                            .lineLimit(1)
                            .textSelection(.enabled)
                    }
                }
            }
            .frame(width: 230, alignment: .leading)

            behaviorPicker
                .frame(width: 150, alignment: .leading)

            Text(blockedToday > 0 ? "\(blockedToday)×" : "—")
                .font(.system(size: 12.5, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Color.flInkSoft)
                .frame(width: 120, alignment: .leading)

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                // Always present for the keyboard and VoiceOver; only drawn
                // (and clickable) while the pointer is on the row.
                Button {
                    controller.removeBlockedApp(app)
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.flClayInk)
                }
                .buttonStyle(.plain)
                // Not 0: a fully transparent view drops out of the accessibility tree.
                .opacity(isHovering || removeFocused ? 1 : 0.001)
                .allowsHitTesting(isHovering || removeFocused)
                .focused($removeFocused)
                .help("Remove \(app.name)")
                .accessibilityLabel("Remove \(app.name)")

                FLSwitch(
                    isOn: Binding(
                        get: { app.isEnabled },
                        set: { controller.setBlockedApp(app, enabled: $0) }
                    ),
                    label: "Guard \(app.name)"
                )
            }
        }
        .padding(.horizontal, FLLayout.pageInset)
        .frame(height: 50)
        .background(isHovering ? Color.flSunken : .clear)
        .onHover { hovering in
            withAnimation(FLAnimation.quick) {
                isHovering = hovering
            }
        }
        .accessibilityAction(named: "Remove \(app.name)") {
            controller.removeBlockedApp(app)
        }
        .alert(
            "Quit \(app.name) during focus?",
            isPresented: Binding(
                get: { pendingBehavior != nil },
                set: { if !$0 { pendingBehavior = nil } }
            )
        ) {
            Button("Keep Guard Screen", role: .cancel) {
                pendingBehavior = nil
            }
            Button("Quit It Anyway", role: .destructive) {
                if let choice = pendingBehavior {
                    controller.setBlockedApp(app, behavior: choice)
                }
                pendingBehavior = nil
            }
        } message: {
            Text("Quitting \(app.name) ends any call it’s on. Guard Screen keeps the call going and just keeps the window out of reach.")
        }
        .contextMenu {
            Button("Copy Bundle Identifier") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(app.bundleId, forType: .string)
            }
            Divider()
            Button("Remove \(app.name)", role: .destructive) {
                controller.removeBlockedApp(app)
            }
        }
    }

    /// The behaviour badge doubles as its own picker, so per-app overrides are
    /// set where they are read instead of in a separate sheet.
    private var behaviorPicker: some View {
        Menu {
            Button {
                choose(nil)
            } label: {
                Label(
                    "Follow default (\(controller.config.blockerMode.displayName))",
                    systemImage: app.behavior == nil ? "checkmark" : ""
                )
            }

            Divider()

            ForEach(BlockerMode.allCases) { mode in
                Button {
                    choose(mode)
                } label: {
                    Label(mode.displayName, systemImage: app.behavior == mode ? "checkmark" : "")
                }
            }
        } label: {
            HStack(spacing: 5) {
                Text(behavior.displayName)
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundStyle(app.isEnabled ? (quitsCalls ? Color.flClayInk : Color.flInk) : Color.flInkSoft)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(quitsCalls && app.isEnabled ? Color.flClay.opacity(0.12) : Color.flSunken))
            .contentShape(Capsule())
        }
        // `.button` with a plain style keeps the whole label, outline and
        // chevron included; `.borderlessButton` drew only its text.
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Behaviour for \(app.name)")
        .accessibilityValue(behavior.displayName)
    }

    /// Choosing to quit an app you call people on asks first.
    private func choose(_ mode: BlockerMode?) {
        let effective = mode ?? controller.config.blockerMode
        if app.isCallingApp, effective == .quitApp, behavior != .quitApp {
            pendingBehavior = .some(mode)
        } else {
            controller.setBlockedApp(app, behavior: mode)
        }
    }

}

extension BlockedApp {
    /// Apps people sit on calls in. Quitting one hangs up on whoever is there,
    /// which is the one thing Quietwhile promises not to do by default.
    var isCallingApp: Bool {
        Self.callingBundleIds.contains(bundleId.lowercased())
    }

    private static let callingBundleIds: Set<String> = [
        "com.hnc.discord", "com.hnc.discordptb", "com.hnc.discordcanary",
        "com.apple.facetime", "us.zoom.xos", "com.tinyspeck.slackmacgap",
        "com.microsoft.teams", "com.microsoft.teams2", "net.whatsapp.whatsapp",
        "desktop.whatsapp", "com.skype.skype", "ru.keepcoder.telegram",
        "org.telegram.desktop", "org.whispersystems.signal-desktop", "com.webex.meetingmanager",
    ]
}
