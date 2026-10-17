import AppKit
import FocusLockCore
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var controller: MenuBarController

    var body: some View {
        OnboardingFlow(controller: controller, permissions: controller.permissions)
    }
}

/// Every selection uses the same controller calls as the rest of the app.
/// The scrollable content keeps the footer reachable with a long app list.
private struct OnboardingFlow: View {
    @ObservedObject var controller: MenuBarController
    @ObservedObject var permissions: PermissionCenter
    @State private var step: Step = .distractions
    @State private var suggestions = AppSuggestionList(likely: [], frequent: [])
    @State private var hasScannedApps = false
    @State private var showsSites = false
    @State private var siteInput = ""
    @State private var siteError: String?

    enum Step: Int, CaseIterable {
        case distractions, prepare, ready

        var title: String {
            switch self {
            case .distractions: return "Choose"
            case .prepare: return "Prepare"
            case .ready: return "Start"
            }
        }
    }

    private var hasSelection: Bool {
        !controller.activeBlockedApps.isEmpty || !controller.activeBlockedSites.isEmpty
    }

    private var selectedBrowser: SupportedBrowser? {
        controller.onboardingProgress.preferredBrowserBundleID.flatMap(SupportedBrowser.init(rawValue:))
    }

    private var allowedBrowsers: [SupportedBrowser] {
        permissions.installedBrowsers.filter { permissions.state(for: $0) == .granted }
    }

    var body: some View {
        VStack(spacing: 0) {
            progress.padding(.top, 36).padding(.bottom, 20)

            ScrollView {
                VStack(spacing: FLSpacing.lg) {
                    switch step {
                    case .distractions: distractions
                    case .prepare: prepare
                    case .ready: ready
                    }
                }
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, FLSpacing.xl)
                .padding(.vertical, FLSpacing.lg)
                .id(step)
                .transition(.opacity)
            }

            FLRule()
            footer.padding(.horizontal, FLSpacing.xl).padding(.vertical, FLSpacing.lg)
        }
        .background(Color.flCanvas)
        .task {
            showsSites = !controller.activeBlockedSites.isEmpty
            permissions.refresh()
            if selectedBrowser == nil,
               let url = URL(string: "https://example.com"),
               let app = NSWorkspace.shared.urlForApplication(toOpen: url),
               let bundleID = Bundle(url: app)?.bundleIdentifier,
               let browser = SupportedBrowser(rawValue: bundleID) {
                controller.chooseOnboardingBrowser(browser)
            }
            suggestions = await Task.detached(priority: .userInitiated) {
                AppUsageScanner.suggestions()
            }.value
            hasScannedApps = true
        }
    }

    private var progress: some View {
        HStack(spacing: 28) {
            ForEach(Step.allCases, id: \.rawValue) { item in
                HStack(spacing: 7) {
                    Text("\(item.rawValue + 1)")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 22, height: 22)
                        .background(item == step ? Color.flAccentSoft : Color.flField, in: Circle())
                    Text(item.title).font(FLTypography.caption)
                }
                .foregroundStyle(item.rawValue <= step.rawValue ? Color.flAccentDeep : Color.flInkSoft)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step.rawValue + 1) of 3: \(step.title)")
    }

    private var footer: some View {
        HStack(spacing: FLSpacing.sm) {
            if step != .distractions {
                Button("Back") { go(to: step.rawValue - 1) }
                    .buttonStyle(FLActionButtonStyle(variant: .quiet))
            }
            Spacer()
            if step == .ready {
                Button("Look around first") { controller.finishOnboarding(startingFocus: false) }
                    .buttonStyle(FLActionButtonStyle(variant: .secondary))
                Button("Start \(controller.config.focusMinutes)-minute \(controller.nextBlockIsStrict ? "strict focus" : "focus")") {
                    controller.finishOnboarding(startingFocus: true)
                }
                .buttonStyle(FLActionButtonStyle(variant: .primary))
                .keyboardShortcut(controller.nextBlockIsStrict ? nil : .defaultAction)
            } else {
                Button("Skip setup") { controller.dismissOnboarding() }
                    .buttonStyle(FLActionButtonStyle(variant: .quiet))
                Button(step == .distractions && !hasSelection ? "Use timer only" : "Continue") {
                    if step == .distractions && !hasSelection { controller.chooseTimerOnly() }
                    go(to: step.rawValue + 1)
                }
                .buttonStyle(FLActionButtonStyle(variant: .primary))
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func go(to index: Int) {
        guard let next = Step(rawValue: index) else { return }
        withAnimation(FLAnimation.standard) { step = next }
    }

    private func heading(_ title: String, _ detail: String) -> some View {
        VStack(spacing: FLSpacing.sm) {
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.flInk)
            Text(detail)
                .font(.system(size: 14))
                .foregroundStyle(Color.flInkSoft)
                .lineSpacing(3)
                .frame(maxWidth: 460)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var distractions: some View {
        VStack(spacing: FLSpacing.lg) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().interpolation(.high).frame(width: 52, height: 52)
                .accessibilityHidden(true)
            heading("Welcome to \(AppIdentity.name)",
                    "Choose an app or website that pulls you away. Quietwhile guards your choices during focus.")
            apps
            FLRule()
            DisclosureGroup("Add websites", isExpanded: $showsSites) {
                sites.padding(.top, FLSpacing.md)
            }
            .font(FLTypography.headline)
            .tint(Color.flAccentDeep)
        }
    }

    private var prepare: some View {
        VStack(spacing: FLSpacing.lg) {
            heading("Prepare your block", "Choose how long to focus. You can change the duration before any block.")
            HStack(spacing: FLSpacing.xl) {
                FLDurationField(label: "Focus", minutes: Binding(
                    get: { controller.config.focusMinutes }, set: controller.updateFocusMinutes
                ), range: AppConfig.focusMinutesRange)
                FLDurationField(label: "Break", minutes: Binding(
                    get: { controller.config.breakMinutes }, set: controller.updateBreakMinutes
                ), range: 0...60)
            }
            .padding(FLSpacing.lg)
            .frame(maxWidth: .infinity)
            .background(Color.flField, in: RoundedRectangle(cornerRadius: FLRadius.lg))

            if !controller.activeBlockedSites.isEmpty {
                browserAccess
            } else if !controller.activeBlockedApps.isEmpty {
                Text("App guarding is ready without a macOS permission prompt.")
                    .font(FLTypography.caption).foregroundStyle(Color.flInkSoft)
            }
        }
    }

    private var browserAccess: some View {
        VStack(alignment: .leading, spacing: FLSpacing.md) {
            Label("Website protection", systemImage: "globe")
                .font(FLTypography.headline).foregroundStyle(Color.flInk)
            Text("During focus, Quietwhile reads the current tab’s address and replaces guarded sites with its own page. It never reads page contents or browsing history.")
                .font(FLTypography.body).foregroundStyle(Color.flInkSoft)
                .fixedSize(horizontal: false, vertical: true)
            if permissions.installedBrowsers.isEmpty {
                Text("No supported browser is installed. Your selected sites will stay saved, but cannot be guarded yet.")
                    .font(FLTypography.caption).foregroundStyle(Color.flClayInk)
            } else {
                Picker("Browser you’ll use", selection: Binding<SupportedBrowser?>(
                    get: { selectedBrowser },
                    set: { if let browser = $0 { controller.chooseOnboardingBrowser(browser) } }
                )) {
                    Text("Choose a browser").tag(SupportedBrowser?.none)
                    ForEach(permissions.installedBrowsers) { browser in
                        Text(browser.displayName).tag(Optional(browser))
                    }
                }
                if let browser = selectedBrowser {
                    browserControl(browser)
                } else {
                    Text("Choose a supported browser to allow website protection. Firefox is not supported.")
                        .font(FLTypography.caption).foregroundStyle(Color.flInkSoft)
                }
            }
            Text("You can continue with the timer and any selected apps. Websites need browser access to be guarded.")
                .font(FLTypography.caption).foregroundStyle(Color.flInkSoft)
        }
        .padding(FLSpacing.lg)
        .background(Color.flField, in: RoundedRectangle(cornerRadius: FLRadius.lg))
    }

    @ViewBuilder
    private func browserControl(_ browser: SupportedBrowser) -> some View {
        if permissions.pendingBrowser != nil {
            Text("Waiting for your answer…").font(FLTypography.caption)
        } else {
            switch permissions.state(for: browser) {
            case .granted:
                Label("Websites can be guarded in \(browser.displayName)", systemImage: "checkmark.circle.fill")
                    .font(FLTypography.caption).foregroundStyle(Color.flAccentDeep)
            case .notAsked:
                Button("Allow \(browser.displayName)…") { permissions.requestBrowser(browser) }
                    .buttonStyle(FLActionButtonStyle(variant: .secondary, minHeight: 34))
            case .denied:
                Text("Websites aren’t guarded in \(browser.displayName) yet.")
                    .font(FLTypography.caption).foregroundStyle(Color.flClayInk)
                Button("Open Automation Settings") { permissions.openAutomationSettings() }
                    .buttonStyle(FLLinkButtonStyle())
            }
        }
    }

    private var ready: some View {
        VStack(spacing: FLSpacing.lg) {
            heading("Ready to focus", controller.config.breakMinutes > 0
                    ? "\(controller.config.focusMinutes) \(controller.config.focusMinutes == 1 ? "minute" : "minutes") of focus, followed by a \(controller.config.breakMinutes)-minute break."
                    : "\(controller.config.focusMinutes) \(controller.config.focusMinutes == 1 ? "minute" : "minutes") of focus.")
            VStack(alignment: .leading, spacing: FLSpacing.md) {
                let availableApps = controller.activeBlockedApps.filter {
                    NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.bundleId) != nil
                }
                if !availableApps.isEmpty {
                    summaryRow("Apps ready to guard", availableApps.map(\.name).joined(separator: ", "), symbol: "shield")
                    if availableApps.contains(where: { $0.effectiveBehavior(default: controller.config.blockerMode) == .quitApp }) {
                        summaryRow("Quit App enabled", "Some selected apps are set to quit when opened during focus. Change their behavior under Blocked.", symbol: "exclamationmark.circle", warning: true)
                    } else {
                        Text("These apps stay running in the background, so a call can continue.")
                            .font(FLTypography.caption).foregroundStyle(Color.flInkSoft)
                    }
                }
                let unavailable = controller.activeBlockedApps.count - availableApps.count
                if unavailable > 0 {
                    summaryRow("Apps unavailable", "\(unavailable) selected \(unavailable == 1 ? "app could" : "apps could") not be found on this Mac.", symbol: "exclamationmark.circle", warning: true)
                }
                if !controller.activeBlockedSites.isEmpty {
                    summaryRow("Websites selected", controller.activeBlockedSites.map(\.pattern).joined(separator: ", "), symbol: "globe")
                    if !allowedBrowsers.isEmpty {
                        summaryRow("Website protection available", "Only in \(allowedBrowsers.map(\.displayName).joined(separator: ", ")). Other browsers need their own access.", symbol: "checkmark.circle")
                    }
                    if let browser = selectedBrowser, permissions.state(for: browser) != .granted {
                        summaryRow("Browser access pending", "Websites won’t be guarded in \(browser.displayName) until you allow access.", symbol: "exclamationmark.circle", warning: true)
                    } else if allowedBrowsers.isEmpty {
                        summaryRow("Website protection pending", "Allow a supported browser in the previous step to guard these sites.", symbol: "exclamationmark.circle", warning: true)
                    }
                }
                if !controller.protectionAvailability.isAvailable {
                    summaryRow("Timer available", "This block will run with the timer. You can add protection under Blocked.", symbol: "timer")
                }
                if controller.nextBlockIsStrict {
                    summaryRow("Strict block", "Ending early and quitting will be unavailable until focus ends. You’ll confirm before starting.", symbol: "lock", warning: true)
                }
            }
            .padding(FLSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.flField, in: RoundedRectangle(cornerRadius: FLRadius.lg))
            Text("The countdown also appears in the menu bar. Breaks are unguarded.")
                .font(FLTypography.caption).foregroundStyle(Color.flInkSoft)
        }
    }

    private func summaryRow(_ title: String, _ detail: String, symbol: String, warning: Bool = false) -> some View {
        HStack(alignment: .top, spacing: FLSpacing.md) {
            Image(systemName: symbol)
                .foregroundStyle(warning ? Color.flClayInk : Color.flAccentDeep)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(FLTypography.headline).foregroundStyle(Color.flInk)
                Text(detail).font(FLTypography.body).foregroundStyle(Color.flInkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Apps already on the guarded list that the suggestions do not cover
    /// (added through the picker), so every guarded app shows as a chip.
    private var otherGuardedApps: [BlockedApp] {
        let suggested = Set((suggestions.likely + suggestions.frequent).map(\.bundleId))
        return controller.config.blockedApps.filter { !suggested.contains($0.bundleId) }
    }

    private var apps: some View {
        VStack(spacing: FLSpacing.md) {
            Text("Suggestions from this Mac. Your usage stays here.")
                .font(FLTypography.caption)
                .foregroundStyle(Color.flInkSoft)

            if !hasScannedApps {
                Text("Looking at what you use…")
                    .font(FLTypography.body)
                    .foregroundStyle(Color.flInkSoft)
            } else if suggestions.isEmpty && otherGuardedApps.isEmpty {
                Text("Nothing stood out. Add any app below.")
                    .font(FLTypography.body)
                    .foregroundStyle(Color.flInkSoft)
            } else {
                if !suggestions.likely.isEmpty || !otherGuardedApps.isEmpty {
                    appGrid {
                        ForEach(suggestions.likely) { app in
                            appChip(name: app.name, bundleId: app.bundleId, url: app.url,
                                    evidence: AppSuggestions.evidence(for: app, now: Date()))
                        }
                        ForEach(otherGuardedApps) { app in
                            appChip(name: app.name, bundleId: app.bundleId, url: nil, evidence: nil)
                        }
                    }
                }

                if !suggestions.frequent.isEmpty {
                    VStack(spacing: FLSpacing.sm) {
                        Text("Other apps you open a lot")
                            .font(FLTypography.headline)
                            .foregroundStyle(Color.flInkSoft)
                        appGrid {
                            ForEach(suggestions.frequent) { app in
                                appChip(name: app.name, bundleId: app.bundleId, url: app.url,
                                        evidence: AppSuggestions.evidence(for: app, now: Date()))
                            }
                        }
                    }
                }
            }

            Button("Choose another app…") { controller.addBlockedAppFromPanel() }
                .buttonStyle(FLLinkButtonStyle())

            selectionCount(controller.activeBlockedApps.count, singular: "app", plural: "apps")
        }
    }

    private func appGrid<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: FLSpacing.sm)], spacing: FLSpacing.sm) {
            content()
        }
    }

    private func appChip(name: String, bundleId: String, url: URL?, evidence: String?) -> some View {
        let guarded = controller.config.blockedApps.first { $0.bundleId == bundleId }

        return Button {
            if let guarded, guarded.isEnabled {
                controller.removeBlockedApp(guarded)
            } else if let guarded {
                controller.setBlockedApp(guarded, enabled: true)
            } else if let url {
                controller.addBlockedApp(at: url)
            }
        } label: {
            chipLabel(isSelected: guarded?.isEnabled == true) {
                FLAppIcon(bundleId: bundleId, size: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                    if let evidence {
                        Text(evidence)
                            .font(.system(size: 10.5))
                            .foregroundStyle(Color.flInkSoft)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(evidence.map { "\(name), \($0)" } ?? name)
        .accessibilityAddTraits(guarded?.isEnabled == true ? [.isSelected] : [])
    }

    private static let suggestedSites = [
        "youtube.com", "x.com", "instagram.com", "reddit.com",
        "tiktok.com", "twitch.tv", "netflix.com", "facebook.com"
    ]

    private var siteChoices: [String] {
        let others = controller.config.blockedSites
            .map(\.pattern)
            .filter { !Self.suggestedSites.contains($0) }
        return Self.suggestedSites + others
    }

    private var sites: some View {
        VStack(spacing: FLSpacing.lg) {
            Text("Choose a site to replace with Quietwhile’s “Not now.” page during focus.")
                .font(FLTypography.caption)
                .foregroundStyle(Color.flInkSoft)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: FLSpacing.sm)], spacing: FLSpacing.sm) {
                ForEach(siteChoices, id: \.self) { pattern in
                    siteChip(pattern)
                }
            }

            VStack(spacing: 6) {
                HStack(spacing: FLSpacing.sm) {
                    TextField("another-site.com", text: $siteInput)
                        .flField(width: 240)
                        .onSubmit(addTypedSite)

                    Button("Add") { addTypedSite() }
                        .buttonStyle(FLActionButtonStyle(variant: .secondary, minHeight: 32))
                        .disabled(siteInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if let siteError {
                    Text(siteError)
                        .font(FLTypography.caption)
                        .foregroundStyle(Color.flClayInk)
                }
            }

            Text("Website guarding needs access to your browser. You can allow it in the next step. Firefox is not supported.")
                .font(FLTypography.caption)
                .foregroundStyle(Color.flInkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 440)
        }
    }

    private func siteChip(_ pattern: String) -> some View {
        let guarded = controller.config.blockedSites.first { $0.pattern == pattern }

        return Button {
            if let guarded, guarded.isEnabled {
                controller.removeBlockedSite(guarded)
            } else if let guarded {
                controller.setBlockedSite(guarded, enabled: true)
            } else {
                controller.addBlockedSite(pattern)
            }
        } label: {
            chipLabel(isSelected: guarded?.isEnabled == true) {
                Text(pattern)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(pattern)
        .accessibilityAddTraits(guarded?.isEnabled == true ? [.isSelected] : [])
    }

    private func addTypedSite() {
        let text = siteInput.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        if controller.addBlockedSite(text) {
            siteInput = ""
            siteError = nil
        } else {
            siteError = controller.settingsMessage
        }
    }

    // MARK: - Shared pieces

    private func chipLabel<Content: View>(isSelected: Bool, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: FLSpacing.sm) {
            content()
                .font(FLTypography.body)
                .foregroundStyle(Color.flInk)
                .lineLimit(1)

            Spacer(minLength: 0)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                .font(.system(size: 14))
                .foregroundStyle(isSelected ? Color.flAccentDeep : Color.flInkSoft.opacity(0.7))
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
        .background(
            isSelected ? Color.flAccentSoft.opacity(0.55) : Color.flField,
            in: RoundedRectangle(cornerRadius: FLRadius.lg, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: FLRadius.lg, style: .continuous)
                .strokeBorder(isSelected ? Color.flAccentDeep : Color.flHairline, lineWidth: isSelected ? 1.5 : 1)
        )
        .contentShape(Rectangle())
    }

    private func selectionCount(_ count: Int, singular: String, plural: String) -> some View {
        Text(count == 0 ? "Nothing selected yet" : "\(count) \(count == 1 ? singular : plural) guarded")
            .font(FLTypography.caption)
            .foregroundStyle(count == 0 ? Color.flInkSoft : Color.flAccentDeep)
    }
}
