import FocusLockCore
import SwiftUI

/// Websites guarded during focus. No browser extension: LockIn asks the
/// browser for its current tab through Apple Events and swaps a blocked page
/// out for its own.
struct BlockedSitesSection: View {
    @EnvironmentObject private var controller: MenuBarController
    @State private var entry = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            addRow

            if let browser = controller.browserPermissionProblem {
                BrowserPermissionBanner(permissions: controller.permissions) {
                    permissionBanner(for: browser)
                }
            }

            if controller.config.blockedSites.isEmpty {
                FLEmptyState(
                    systemImage: "globe",
                    title: "No websites guarded",
                    detail: "Add a site like youtube.com, or a section like reddit.com/r/all. Subdomains are covered too."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                columnHeaders
                Rectangle().fill(Color.flHairline).frame(height: 1).padding(.horizontal, 26)
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(controller.config.blockedSites) { site in
                            BlockedSiteRow(site: site)
                            Rectangle()
                                .fill(Color.flHairline.opacity(0.5))
                                .frame(height: 1)
                                .padding(.horizontal, 26)
                        }
                    }
                }
            }

            browserNote
        }
    }

    private var addRow: some View {
        HStack(spacing: 10) {
            TextField("youtube.com, or reddit.com/r/all for just a section", text: $entry)
                .flField(width: 360)
                .onSubmit(add)

            Button("Add site", action: add)
                .buttonStyle(FLActionButtonStyle(variant: .primary, minHeight: 34))
                .disabled(entry.trimmingCharacters(in: .whitespaces).isEmpty)

            Spacer()
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 18)
    }

    private func add() {
        if controller.addBlockedSite(entry) {
            entry = ""
        }
    }

    private var columnHeaders: some View {
        HStack(spacing: 0) {
            FLMicroLabel(text: "Website").frame(width: 330, alignment: .leading)
            FLMicroLabel(text: "Blocked today").frame(width: 120, alignment: .leading)
            Spacer(minLength: 0)
            FLMicroLabel(text: "Active")
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 10)
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
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "globe")
                .foregroundStyle(Color.flAccentDeep)
            VStack(alignment: .leading, spacing: 6) {
                Text("\(browser.displayName) needs your OK before websites can be guarded in it")
                    .font(FLTypography.headline)
                    .foregroundStyle(Color.flInk)
                Text("LockIn asks \(browser.displayName) for the address of the tab in front. Only the address, only during focus. Never page contents or history. macOS will ask you to confirm.")
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flInkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Allow \(browser.displayName)…") { controller.permissions.requestBrowser(browser) }
                    .buttonStyle(FLLinkButtonStyle())
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.flAccentSoft.opacity(0.45), in: RoundedRectangle(cornerRadius: FLRadius.lg))
        .padding(.horizontal, 26)
        .padding(.bottom, 16)
    }

    private func deniedBanner(for browser: SupportedBrowser) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.flClay)
            VStack(alignment: .leading, spacing: 6) {
                Text("LockIn isn't allowed to read \(browser.displayName)'s tabs")
                    .font(FLTypography.headline)
                    .foregroundStyle(Color.flInk)
                Text("Turn on \(browser.displayName) under LockIn in System Settings › Privacy & Security › Automation, then try again.")
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flInkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 14) {
                    Button("Open Automation Settings") { controller.openAutomationSettings() }
                        .buttonStyle(FLLinkButtonStyle())
                    Button("I fixed it — try again") { controller.retryBrowserPermission() }
                        .buttonStyle(FLLinkButtonStyle(tint: .flInkSoft))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.flClay.opacity(0.08), in: RoundedRectangle(cornerRadius: FLRadius.lg))
        .padding(.horizontal, 26)
        .padding(.bottom, 16)
    }

    private var browserNote: some View {
        Text("Works in Safari, Chrome, Arc, Brave, Edge, Vivaldi, Opera, and Chromium — macOS asks once per browser for permission. Firefox can't be read this way; ResistGate covers it.")
            .font(.system(size: 11))
            .foregroundStyle(Color.flInkSoft.opacity(0.85))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 26)
            .padding(.vertical, 12)
    }
}

private struct BlockedSiteRow: View {
    @EnvironmentObject private var controller: MenuBarController
    let site: BlockedSite
    @State private var isHovering = false

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
                .font(.system(size: 12.5, design: .serif))
                .monospacedDigit()
                .foregroundStyle(Color.flInkSoft)
                .frame(width: 120, alignment: .leading)

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                if isHovering {
                    Button {
                        controller.removeBlockedSite(site)
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.flClay)
                    }
                    .buttonStyle(.plain)
                    .help("Remove \(site.pattern)")
                    .accessibilityLabel("Remove \(site.pattern)")
                }

                Toggle("", isOn: Binding(
                    get: { site.isEnabled },
                    set: { controller.setBlockedSite(site, enabled: $0) }
                ))
                .toggleStyle(.switch)
                .tint(Color.flAccentDeep)
                .labelsHidden()
                .accessibilityLabel("Guard \(site.pattern)")
            }
        }
        .padding(.horizontal, 26)
        .frame(height: 48)
        .background(isHovering ? Color.flCanvasWarm.opacity(0.6) : .clear)
        .onHover { hovering in
            withAnimation(FLAnimation.quick) {
                isHovering = hovering
            }
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
