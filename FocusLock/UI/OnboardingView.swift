import AppKit
import FocusLockCore
import SwiftUI

/// The welcome guide: what LockIn does, what to guard, how long to work, and
/// a first block. Every choice is saved the moment it is made, through the
/// same controller calls the rest of the app uses, so skipping at any point
/// loses nothing.
struct OnboardingView: View {
    @EnvironmentObject private var controller: MenuBarController

    @State private var step: Step = .welcome
    @State private var suggestions = AppSuggestionList(likely: [], frequent: [])
    @State private var hasScannedApps = false
    @State private var siteInput = ""
    @State private var siteError: String?

    enum Step: Int, CaseIterable {
        case welcome
        case apps
        case sites
        case rhythm
        case permissions
        case ready
    }

    var body: some View {
        VStack(spacing: 0) {
            progress
                .padding(.top, 44)

            Spacer(minLength: FLSpacing.lg)

            Group {
                switch step {
                case .welcome: welcome
                case .apps: apps
                case .sites: sites
                case .rhythm: rhythm
                case .permissions: permissions
                case .ready: ready
                }
            }
            .frame(maxWidth: 560)
            .id(step)
            .transition(.opacity)

            Spacer(minLength: FLSpacing.lg)

            footer
                .padding(.horizontal, FLSpacing.xl)
                .padding(.bottom, FLSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.flCanvas)
        .task {
            // Reading a few dozen app bundles is quick, but not main-thread quick.
            let found = await Task.detached(priority: .userInitiated) {
                AppUsageScanner.suggestions()
            }.value
            suggestions = found
            hasScannedApps = true
        }
    }

    // MARK: - Chrome

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases, id: \.rawValue) { item in
                Capsule()
                    .fill(item.rawValue <= step.rawValue ? Color.flAccentDeep : Color.flHairline)
                    .frame(width: item == step ? 22 : 8, height: 4)
            }
        }
        .animation(FLAnimation.standard, value: step)
        .accessibilityElement()
        .accessibilityLabel("Step \(step.rawValue + 1) of \(Step.allCases.count)")
    }

    private var footer: some View {
        HStack(spacing: FLSpacing.sm) {
            if step != .welcome {
                Button("Back") { go(to: step.rawValue - 1) }
                    .buttonStyle(FLActionButtonStyle(variant: .quiet))
            }

            Spacer()

            if step == .ready {
                Button("Look around first") { controller.finishOnboarding(startingFocus: false) }
                    .buttonStyle(FLActionButtonStyle(variant: .secondary))

                Button("Start my first block") { controller.finishOnboarding(startingFocus: true) }
                    .buttonStyle(FLActionButtonStyle(variant: .primary))
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Skip setup") { controller.finishOnboarding(startingFocus: false) }
                    .buttonStyle(FLActionButtonStyle(variant: .quiet))

                Button(step == .welcome ? "Set it up" : "Continue") { go(to: step.rawValue + 1) }
                    .buttonStyle(FLActionButtonStyle(variant: .primary))
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func go(to index: Int) {
        guard let next = Step(rawValue: index) else { return }
        withAnimation(FLAnimation.standard) {
            step = next
        }
    }

    private func heading(_ title: String, _ detail: String) -> some View {
        VStack(spacing: FLSpacing.sm) {
            Text(title)
                .font(.system(size: 30, weight: .regular, design: .serif))
                .foregroundStyle(Color.flInk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(detail)
                .font(.system(size: 14))
                .foregroundStyle(Color.flInkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 460)
        }
    }

    // MARK: - Welcome

    private var welcome: some View {
        VStack(spacing: FLSpacing.xl) {
            VStack(spacing: FLSpacing.md) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 88, height: 88)
                    .accessibilityHidden(true)

                heading(
                    "Welcome to \(AppIdentity.name)",
                    "A focus timer that stops the reflex to open an app “just for a second”, without closing the app."
                )
            }

            VStack(alignment: .leading, spacing: FLSpacing.md) {
                point(
                    "shield",
                    "Pick what pulls you in",
                    "Apps like Discord, and sites like youtube.com."
                )
                point(
                    "timer",
                    "Start a focus block",
                    "From this window, the menu bar, a shortcut, or a schedule."
                )
                point(
                    "hand.raised",
                    "Reach for one and see “Not now.”",
                    "The app is hidden, not quit, so a call keeps going. Breaks are unguarded."
                )
            }
            .frame(maxWidth: 420, alignment: .leading)
        }
    }

    private func point(_ symbol: String, _ title: String, _ detail: String) -> some View {
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
                    .font(FLTypography.body)
                    .foregroundStyle(Color.flInkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Apps

    /// Apps already on the guarded list that the suggestions do not cover
    /// (added through the picker), so every guarded app shows as a chip.
    private var otherGuardedApps: [BlockedApp] {
        let suggested = Set((suggestions.likely + suggestions.frequent).map(\.bundleId))
        return controller.config.blockedApps.filter { !suggested.contains($0.bundleId) }
    }

    private var apps: some View {
        VStack(spacing: FLSpacing.md) {
            heading(
                "Which apps pull you in?",
                "Suggested from what you actually open on this Mac, most used first. That information stays here. Change the list any time under Blocked."
            )

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
                        FLMicroLabel(text: "Other apps you open a lot")
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

            selectionCount(controller.config.blockedApps.count, singular: "app", plural: "apps")
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
            if let guarded {
                controller.removeBlockedApp(guarded)
            } else if let url {
                controller.addBlockedApp(at: url)
            }
        } label: {
            chipLabel(isSelected: guarded != nil) {
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
        .accessibilityAddTraits(guarded != nil ? [.isSelected] : [])
    }

    // MARK: - Sites

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
            heading(
                "And which websites?",
                "During focus, LockIn swaps a guarded site for its own “Not now.” page. No browser extension needed."
            )

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
                        .foregroundStyle(Color.flClay)
                }
            }

            Text("Works in Safari, Chrome, Arc, Brave, Edge, Vivaldi and Opera. Each browser needs your OK once; a later step explains it.")
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
            if let guarded {
                controller.removeBlockedSite(guarded)
            } else {
                controller.addBlockedSite(pattern)
            }
        } label: {
            chipLabel(isSelected: guarded != nil) {
                Text(pattern)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(pattern)
        .accessibilityAddTraits(guarded != nil ? [.isSelected] : [])
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

    // MARK: - Rhythm

    private var rhythm: some View {
        VStack(spacing: FLSpacing.lg) {
            heading(
                "Pick a rhythm",
                "How long you focus, then how long you rest. Any other length is one click away on the Focus page."
            )

            HStack(spacing: FLSpacing.md) {
                rhythmCard(.twentyFiveFive, title: "25 / 5", name: "Short sprints",
                           detail: "Easy to start. Good for reading, admin, and getting unstuck.")
                rhythmCard(.fiftyTen, title: "50 / 10", name: "Deep work",
                           detail: "Long enough to get somewhere. Good for writing and code.")
            }

            VStack(spacing: 0) {
                FLRule()

                HStack(spacing: FLSpacing.md) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Open \(AppIdentity.name) at login")
                            .font(FLTypography.headline)
                            .foregroundStyle(Color.flInk)

                        Text("Schedules can only start a block while LockIn is running.")
                            .font(FLTypography.caption)
                            .foregroundStyle(Color.flInkSoft)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { controller.launchAtLogin },
                        set: { controller.setLaunchAtLogin($0) }
                    ))
                    .toggleStyle(.switch)
                    .tint(Color.flAccentDeep)
                    .labelsHidden()
                    .accessibilityLabel("Open \(AppIdentity.name) at login")
                }
                .padding(.vertical, FLSpacing.md)

                FLRule()
            }
            .frame(maxWidth: 480)
        }
    }

    private func rhythmCard(_ preset: FocusPreset, title: String, name: String, detail: String) -> some View {
        let isSelected = controller.preset == preset

        return Button {
            controller.selectPreset(preset)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(FLTypography.timer(30))
                        .foregroundStyle(Color.flInk)

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundStyle(isSelected ? Color.flAccentDeep : Color.flHairline)
                }

                Text(name)
                    .font(FLTypography.headline)
                    .foregroundStyle(Color.flInk)

                Text(detail)
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flInkSoft)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(FLSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
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
        .buttonStyle(.plain)
        .accessibilityLabel("\(name), \(title)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Permissions

    private var permissions: some View {
        VStack(spacing: FLSpacing.lg) {
            heading(
                "Two things macOS will ask about",
                "Here is what each one is for. Allow them now, or leave them for later: LockIn works either way, and nothing is asked behind your back."
            )

            PermissionsPanel(
                permissions: controller.permissions,
                guardsWebsites: !controller.config.blockedSites.isEmpty
            )
        }
    }

    // MARK: - Ready

    private var ready: some View {
        VStack(spacing: FLSpacing.lg) {
            heading("You’re set", summary)

            VStack(alignment: .leading, spacing: FLSpacing.md) {
                point(
                    "menubar.rectangle",
                    "LockIn lives in the menu bar",
                    "The countdown stays up there, and one click opens the controls."
                )
                if let shortcut = startShortcut {
                    point(
                        "keyboard",
                        "\(shortcut) starts a block from anywhere",
                        "Change or switch off the shortcuts in Settings."
                    )
                }
                point(
                    "lock",
                    "There is more when you want it",
                    "Strict mode, schedules, a desktop widget, and history are in the sidebar."
                )
            }
            .frame(maxWidth: 440, alignment: .leading)
        }
    }

    private var summary: String {
        let appCount = controller.config.blockedApps.count
        let siteCount = controller.config.blockedSites.count
        let rhythm = "\(controller.config.focusMinutes) minutes of focus, then a \(controller.config.breakMinutes)-minute break."

        guard appCount + siteCount > 0 else {
            return "Nothing is guarded yet, so a block is just a timer. Add apps and sites under Blocked whenever you like. \(rhythm)"
        }

        var parts: [String] = []
        if appCount > 0 { parts.append("\(appCount) \(appCount == 1 ? "app" : "apps")") }
        if siteCount > 0 { parts.append("\(siteCount) \(siteCount == 1 ? "site" : "sites")") }
        return "Guarding \(parts.joined(separator: " and ")). \(rhythm)"
    }

    /// Only the untouched default is named: it is the one combination whose
    /// key this view can spell without a keyboard-layout lookup.
    private var startShortcut: String? {
        let hotkeys = controller.config.hotkeys
        guard hotkeys.enabled, let combo = hotkeys.start, combo == HotkeySettings().start else { return nil }
        return combo.modifierSymbols + "S"
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
