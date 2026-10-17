import FocusLockCore
import SwiftUI

struct FirstDistractionPrompt: View {
    @EnvironmentObject private var controller: MenuBarController

    var body: some View {
        VStack(alignment: .leading, spacing: FLSpacing.md) {
            Text("Choose an app or website to guard during your first block.")
                .font(FLTypography.body)
                .foregroundStyle(Color.flInk)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: FLSpacing.sm) {
                Button("Choose a distraction") { controller.showOnboarding() }
                    .buttonStyle(FLActionButtonStyle(variant: .primary, minHeight: 36))
                Button("Use timer only") {
                    controller.chooseTimerOnly()
                    controller.requestStartFocus()
                }
                .buttonStyle(FLActionButtonStyle(variant: .quiet, minHeight: 36))
            }
        }
    }
}

/// Offered during the first running block, after the timer has provided value.
/// Observes permissions directly so the offer disappears after an answer.
struct FirstBlockNotificationPrompt: View {
    @EnvironmentObject private var controller: MenuBarController
    @ObservedObject var permissions: PermissionCenter

    var body: some View {
        if controller.onboardingProgress.cohortStartedAt != nil,
           controller.onboardingProgress.firstFullBlockCompletedAt == nil,
           !controller.onboardingProgress.notificationsDeferred,
           permissions.notifications == .notAsked {
            VStack(alignment: .leading, spacing: FLSpacing.sm) {
                Text("Get a notification when this block ends\(controller.snapshot.breakMinutes > 0 ? " and your break starts" : ""). Notifications can also tell you when a guarded app is hidden.")
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flInkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: FLSpacing.md) {
                    Button("Enable notifications…") { permissions.requestNotifications() }
                        .buttonStyle(FLLinkButtonStyle())
                    Button("Later") { controller.deferNotificationPrompt() }
                        .buttonStyle(FLLinkButtonStyle())
                }
            }
        }
    }
}

struct WebsiteProtectionAvailabilityNote: View {
    @EnvironmentObject private var controller: MenuBarController
    @ObservedObject var permissions: PermissionCenter

    var body: some View {
        if !controller.activeBlockedSites.isEmpty {
            let allowed = permissions.installedBrowsers.filter {
                permissions.state(for: $0) == .granted && controller.browserPermissionProblem != $0
            }
            if allowed.isEmpty {
                Label("Website protection is pending. Allow a browser under Blocked › Websites.", systemImage: "exclamationmark.circle")
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flClayInk)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Websites guarded in \(allowed.map(\.displayName).joined(separator: ", ")) only")
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flInkSoft)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }
}
