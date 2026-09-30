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
            tabPicker

            if tab == .websites {
                BlockedSitesSection()
            } else if controller.config.blockedApps.isEmpty {
                FLEmptyState(
                    systemImage: "shield",
                    title: "Nothing guarded yet",
                    detail: "Add the apps that pull you away, and LockIn will hold them back during focus."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                searchField
                columnHeaders
                Rectangle().fill(Color.flHairline).frame(height: 1).padding(.horizontal, 26)
                appRows
                Spacer(minLength: 0)
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

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { option in
                let isSelected = tab == option
                Button {
                    tab = option
                } label: {
                    HStack(spacing: 6) {
                        Text(option.rawValue)
                        if option == .websites, controller.browserPermissionProblem != nil {
                            Circle().fill(Color.flClay).frame(width: 6, height: 6)
                        }
                    }
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.flCanvas : Color.flInkSoft)
                    .padding(.horizontal, 18)
                    .frame(height: 28)
                    .background(Capsule().fill(isSelected ? Color.flAccentDeep : .clear))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.flCanvasWarm))
        .overlay(Capsule().strokeBorder(Color.flHairline, lineWidth: 1))
        .fixedSize()
        .padding(.horizontal, 26)
        .padding(.bottom, 18)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Blocked")
                    .font(FLTypography.display)
                    .foregroundStyle(Color.flInk)

                Text(subtitle)
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flInkSoft)
            }

            Spacer()

            if tab == .apps {
                Button("＋  Add app") {
                    controller.addBlockedAppFromPanel()
                }
                .buttonStyle(FLActionButtonStyle(variant: .primary, minHeight: 36))
            }

            if controller.isStrictLocked {
                Label("Strict block: you can add, not remove", systemImage: "lock.fill")
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flInkSoft)
                    .padding(.leading, 12)
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, 28)
        .padding(.bottom, 20)
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
            return "Behaviour applies during focus only"
        }

        if active == total {
            return "\(total) guarded · behaviour applies during focus only"
        }

        return "\(active) of \(total) guarded · behaviour applies during focus only"
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11.5))
                .foregroundStyle(Color.flInkSoft)

            TextField("Filter applications", text: $filter)
                .textFieldStyle(.plain)
                .font(FLTypography.body)
                .foregroundStyle(Color.flInk)
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(Color.flField, in: RoundedRectangle(cornerRadius: FLRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FLRadius.md, style: .continuous)
                .strokeBorder(Color.flHairline, lineWidth: 1)
        )
        .padding(.horizontal, 26)
        .padding(.bottom, 18)
    }

    private var columnHeaders: some View {
        HStack(spacing: 0) {
            FLMicroLabel(text: "Application").frame(width: 230, alignment: .leading)
            FLMicroLabel(text: "Behaviour").frame(width: 150, alignment: .leading)
            FLMicroLabel(text: "Blocked today").frame(width: 120, alignment: .leading)
            Spacer(minLength: 0)
            FLMicroLabel(text: "Active")
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 10)
    }

    private var appRows: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredApps) { app in
                    BlockedAppRow(app: app)
                    Rectangle()
                        .fill(Color.flHairline.opacity(0.5))
                        .frame(height: 1)
                        .padding(.horizontal, 26)
                }
            }
        }
    }
}

private struct BlockedAppRow: View {
    @EnvironmentObject private var controller: MenuBarController
    let app: BlockedApp

    @State private var isHovering = false

    private var behavior: BlockerMode {
        app.effectiveBehavior(default: controller.config.blockerMode)
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

                    if isHovering {
                        Text(app.bundleId)
                            .font(.system(size: 10))
                            .foregroundStyle(Color.flInkSoft.opacity(0.8))
                            .lineLimit(1)
                            .textSelection(.enabled)
                    }
                }
            }
            .frame(width: 230, alignment: .leading)

            behaviorPicker
                .frame(width: 150, alignment: .leading)

            Text(blockedToday > 0 ? "\(blockedToday)×" : "—")
                .font(.system(size: 12.5, design: .serif))
                .monospacedDigit()
                .foregroundStyle(Color.flInkSoft)
                .frame(width: 120, alignment: .leading)

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                if isHovering {
                    Button {
                        controller.removeBlockedApp(app)
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.flClay)
                    }
                    .buttonStyle(.plain)
                    .help("Remove \(app.name)")
                    .accessibilityLabel("Remove \(app.name)")
                }

                Toggle("", isOn: Binding(
                    get: { app.isEnabled },
                    set: { controller.setBlockedApp(app, enabled: $0) }
                ))
                .toggleStyle(.switch)
                .tint(Color.flAccentDeep)
                .labelsHidden()
                .accessibilityLabel("Guard \(app.name)")
            }
        }
        .padding(.horizontal, 26)
        .frame(height: 52)
        .background(isHovering ? Color.flCanvasWarm.opacity(0.6) : .clear)
        .onHover { hovering in
            withAnimation(FLAnimation.quick) {
                isHovering = hovering
            }
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
                controller.setBlockedApp(app, behavior: nil)
            } label: {
                Label(
                    "Follow default (\(controller.config.blockerMode.displayName))",
                    systemImage: app.behavior == nil ? "checkmark" : ""
                )
            }

            Divider()

            ForEach(BlockerMode.allCases) { mode in
                Button {
                    controller.setBlockedApp(app, behavior: mode)
                } label: {
                    Label(mode.displayName, systemImage: app.behavior == mode ? "checkmark" : "")
                }
            }
        } label: {
            FLBadge(
                text: behavior.displayName,
                tint: app.isEnabled ? .flAccentDeep : .flInkSoft,
                borderTint: app.isEnabled ? Color.flAccentDeep.opacity(0.3) : Color.flHairline
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Behaviour for \(app.name)")
    }
}
