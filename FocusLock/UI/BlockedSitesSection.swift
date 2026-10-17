import FocusLockCore
import SwiftUI

/// Websites guarded during focus. No browser extension: Quietwhile asks the
/// browser for its current tab through Apple Events and swaps a blocked page
/// out for its own.
struct BlockedSitesSection: View {
    @EnvironmentObject private var controller: MenuBarController
    @State private var entry = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                addRow

                if let browser = controller.browserPermissionProblem {
                    BrowserPermissionBanner(permissions: controller.permissions) {
                        permissionBanner(for: browser)
                    }
                }
            }
            .padding(.horizontal, FLLayout.pageInset)
            .padding(.bottom, 18)

            if controller.config.blockedSites.isEmpty {
                FLEmptyState(
                    systemImage: "globe",
                    title: "No websites guarded",
                    detail: "Add a site like youtube.com, or a section like reddit.com/r/all. Subdomains are covered too."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                columnHeaders
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(controller.config.blockedSites) { site in
                            BlockedSiteRow(site: site)
                            FLRowDivider(inset: FLLayout.pageInset)
                        }
                    }
                }
            }

            browserNote
                .padding(.horizontal, FLLayout.pageInset)
                .padding(.vertical, 12)
        }
    }

    private var addRow: some View {
        HStack(spacing: 10) {
            TextField("youtube.com, or reddit.com/r/all for just a section", text: $entry)
                .flField()
                .frame(maxWidth: 420)
                .onSubmit(add)

            Button("Add site", action: add)
                .buttonStyle(FLActionButtonStyle(variant: .primary, minHeight: 30))
                .disabled(entry.trimmingCharacters(in: .whitespaces).isEmpty)

            Spacer()
        }
    }

    private func add() {
        if controller.addBlockedSite(entry) {
            entry = ""
        }
    }

    private var columnHeaders: some View {
        HStack(spacing: 0) {
            FLColumnLabel(text: "Website").frame(width: 330, alignment: .leading)
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

    @ViewBuilder
    private func permissionBanner(for browser: SupportedBrowser) -> some View {
        if controller.permissions.state(for: browser) == .denied {
            deniedBanner(for: browser)
        } else {
            askBanner(for: browser)
        }
    }

    /// The browser has never been asked: say what the request is for, and let
    /// the button bring up the macOS dialog.
    private func askBanner(for browser: SupportedBrowser) -> some View {
        FLCallout(
            tone: .warning,
            systemImage: "globe",
            title: "\(browser.displayName) needs your OK before websites can be guarded in it",
            detail: "Quietwhile asks \(browser.displayName) for the address of the tab in front. Only the address, only during focus. Never page contents or history. macOS will ask you to confirm."
        ) {
            Button("Allow \(browser.displayName)…") { controller.permissions.requestBrowser(browser) }
                .buttonStyle(FLActionButtonStyle(variant: .secondary, minHeight: 28))
        }
    }

    private func deniedBanner(for browser: SupportedBrowser) -> some View {
        FLCallout(
            tone: .problem,
            systemImage: "exclamationmark.triangle.fill",
            title: "Quietwhile isn't allowed to read \(browser.displayName)'s tabs",
            detail: "Turn on \(browser.displayName) under Quietwhile in System Settings › Privacy & Security › Automation, then try again."
        ) {
            Button("Open Automation Settings") { controller.openAutomationSettings() }
                .buttonStyle(FLActionButtonStyle(variant: .secondary, minHeight: 28))
            Button("I fixed it — try again") { controller.retryBrowserPermission() }
                .buttonStyle(FLLinkButtonStyle(tint: .flInkSoft))
        }
    }

    private var browserNote: some View {
        Text("Works in Safari, Chrome, Arc, Brave, Edge, Vivaldi, Opera, and Chromium — macOS asks once per browser for permission. Firefox can’t be guarded.")
            .font(FLTypography.caption)
            .foregroundStyle(Color.flInkSoft)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct BlockedSiteRow: View {
    @EnvironmentObject private var controller: MenuBarController
    let site: BlockedSite
    @State private var isHovering = false
    /// Keyboard focus on Remove shows it, so a focus ring never lands on
    /// something invisible.
    @FocusState private var removeFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 11) {
                Image(systemName: "globe")
                    .font(.system(size: 15))
                    .foregroundStyle(site.isEnabled ? Color.flAccentDeep : Color.flInkSoft)
                    .frame(width: 26)
                Text(site.pattern)
                    .font(.system(size: 13))
                    .foregroundStyle(site.isEnabled ? Color.flInk : Color.flInkSoft)
                    .lineLimit(1)
                    .textSelection(.enabled)
            }
            .frame(width: 330, alignment: .leading)

            let count = controller.blockedTodayCount(for: site)
            Text(count > 0 ? "\(count)×" : "—")
                .font(.system(size: 12.5, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Color.flInkSoft)
                .frame(width: 120, alignment: .leading)

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                // Present for the keyboard and VoiceOver; drawn on hover.
                Button {
                    controller.removeBlockedSite(site)
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
                .help("Remove \(site.pattern)")
                .accessibilityLabel("Remove \(site.pattern)")

                FLSwitch(
                    isOn: Binding(
                        get: { site.isEnabled },
                        set: { controller.setBlockedSite(site, enabled: $0) }
                    ),
                    label: "Guard \(site.pattern)"
                )
            }
        }
        .padding(.horizontal, FLLayout.pageInset)
        .frame(height: 46)
        .background(isHovering ? Color.flSunken : .clear)
        .onHover { hovering in
            withAnimation(FLAnimation.quick) {
                isHovering = hovering
            }
        }
        .accessibilityAction(named: "Remove \(site.pattern)") {
            controller.removeBlockedSite(site)
        }
        .contextMenu {
            Button("Remove \(site.pattern)", role: .destructive) {
                controller.removeBlockedSite(site)
            }
        }
    }
}

/// Redraws its content when a permission changes: the controller publishes
/// which browser has a problem, but not the state of each permission.
private struct BrowserPermissionBanner<Content: View>: View {
    @ObservedObject var permissions: PermissionCenter
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
    }
}
