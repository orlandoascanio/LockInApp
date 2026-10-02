import FocusLockCore
import SwiftUI

/// What LockIn asks macOS for, why, and where each one stands. Used wherever a
/// permission comes up, so the explanation always arrives before the system
/// dialog does.
struct PermissionsPanel: View {
    @ObservedObject var permissions: PermissionCenter

    /// Browsers only matter once there is a website to guard.
    let guardsWebsites: Bool

    var body: some View {
        VStack(spacing: FLSpacing.sm) {
            card {
                row(
                    symbol: "bell",
                    title: "Notifications",
                    detail: "A short note when a block ends, a break starts, or a guarded app is hidden. Nothing else."
                ) {
                    control(
                        permissions.notifications,
                        label: "notifications",
                        isPending: false,
                        allow: permissions.requestNotifications,
                        openSettings: permissions.openNotificationSettings
                    )
                }
            }

            card {
                row(
                    symbol: "globe",
                    title: "Your browser’s current tab",
                    detail: "To guard a website, LockIn asks the browser for the address of the tab in front. Only the address, only during focus. Never page contents, and never your history."
                ) {
                    EmptyView()
                }

                if !guardsWebsites {
                    note("No websites are guarded, so there is nothing to allow yet.")
                } else if permissions.installedBrowsers.isEmpty {
                    note("None of the supported browsers are installed on this Mac.")
                } else {
                    VStack(spacing: 0) {
                        ForEach(permissions.installedBrowsers) { browser in
                            FLRule().opacity(0.6)
                            browserRow(browser)
                        }
                    }
                    .padding(.top, FLSpacing.sm)
                }
            }

            Text("Either can be changed later in System Settings › Privacy & Security, or here in Settings.")
                .font(FLTypography.caption)
                .foregroundStyle(Color.flInkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, FLSpacing.xs)
        }
        .onAppear { permissions.refresh() }
    }

    private func browserRow(_ browser: SupportedBrowser) -> some View {
        HStack(spacing: FLSpacing.sm) {
            FLAppIcon(bundleId: browser.bundleIdentifier, size: 22)

            Text(browser.displayName)
                .font(FLTypography.body)
                .foregroundStyle(Color.flInk)

            Spacer(minLength: FLSpacing.sm)

            control(
                permissions.state(for: browser),
                label: browser.displayName,
                isPending: permissions.pendingBrowser == browser,
                allow: { permissions.requestBrowser(browser) },
                openSettings: permissions.openAutomationSettings
            )
        }
        .padding(.vertical, 9)
    }

    @ViewBuilder
    private func control(
        _ state: PermissionState,
        label: String,
        isPending: Bool,
        allow: @escaping () -> Void,
        openSettings: @escaping () -> Void
    ) -> some View {
        if isPending {
            Text("Waiting for your answer…")
                .font(FLTypography.caption)
                .foregroundStyle(Color.flInkSoft)
        } else {
            switch state {
            case .granted:
                Label("Allowed", systemImage: "checkmark.circle.fill")
                    .font(FLTypography.caption.weight(.semibold))
                    .foregroundStyle(Color.flAccentDeep)
            case .denied:
                HStack(spacing: FLSpacing.sm) {
                    Text("Not allowed")
                        .font(FLTypography.caption.weight(.semibold))
                        .foregroundStyle(Color.flClay)
                    Button("Open Settings") { openSettings() }
                        .buttonStyle(FLLinkButtonStyle())
                }
            case .notAsked:
                Button("Allow…") { allow() }
                    .buttonStyle(FLActionButtonStyle(variant: .secondary, minHeight: 30))
                    .accessibilityLabel("Allow \(label)")
            }
        }
    }

    private func row<Trailing: View>(
        symbol: String,
        title: String,
        detail: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(alignment: .top, spacing: FLSpacing.md) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(Color.flAccentDeep)
                .frame(width: 34, height: 34)
                .background(Color.flAccentSoft, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(FLTypography.headline)
                    .foregroundStyle(Color.flInk)

                Text(detail)
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flInkSoft)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: FLSpacing.sm)

            trailing()
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(FLTypography.caption)
            .foregroundStyle(Color.flInkSoft)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 34 + FLSpacing.md)
            .padding(.top, FLSpacing.sm)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(FLSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.flField, in: RoundedRectangle(cornerRadius: FLRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FLRadius.lg, style: .continuous)
                .strokeBorder(Color.flHairline, lineWidth: 1)
        )
    }
}
