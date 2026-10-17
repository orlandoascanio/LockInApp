import FocusLockCore
import SwiftUI

enum MainPage: String, CaseIterable, Identifiable {
    case focus
    case blockedApps
    case schedules
    case history
    case analytics
    case insights
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus:
            return "Focus"
        case .blockedApps:
            return "Blocked"
        case .schedules:
            return "Schedules"
        case .history:
            return "History"
        case .analytics:
            return "Analytics"
        case .insights:
            return "Insights"
        case .settings:
            return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .focus:
            return "timer"
        case .blockedApps:
            return "shield"
        case .schedules:
            return "calendar.badge.clock"
        case .history:
            return "clock.arrow.circlepath"
        case .analytics:
            return "chart.bar.xaxis"
        case .insights:
            return "sparkle.magnifyingglass"
        case .settings:
            return "gearshape"
        }
    }
}

struct MainWindowView: View {
    @EnvironmentObject private var controller: MenuBarController

    var body: some View {
        Group {
            if controller.isOnboarding {
                OnboardingView()
                    .transition(.opacity)
            } else {
                mainLayout
                    .transition(.opacity)
            }
        }
        .animation(FLAnimation.standard, value: controller.isOnboarding)
        .frame(minWidth: 860, minHeight: 600)
    }

    private var mainLayout: some View {
        VStack(spacing: 0) {
            MainTopBar()

            Group {
                switch controller.page {
                case .focus:
                    FocusPageView()
                case .blockedApps:
                    BlockedAppsView()
                case .schedules:
                    SchedulesView()
                case .history:
                    SessionHistoryView()
                case .analytics:
                    AnalyticsView()
                case .insights:
                    InsightsView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        // The top bar starts at the window's top edge, so the title shares
        // the titlebar with the traffic lights.
        .ignoresSafeArea(.container, edges: .top)
        // One canvas behind every page, as a Mac window has; the cards on it
        // carry the structure.
        .background(Color.flCanvas.ignoresSafeArea())
    }
}

extension MainPage {
    /// Every page with a place in the Window menu, in ⌘1–⌘6 order. Settings
    /// has ⌘, instead.
    static let tabs: [MainPage] = [.focus, .blockedApps, .schedules, .history, .analytics, .insights]

    /// The tab bar: four places. Analytics, Insights and History share one
    /// tab, Stats, and a switcher at the top of each.
    static let tabBar: [MainPage] = [.focus, .blockedApps, .schedules, .analytics]

    /// The three views of your focus that live under Stats.
    static let statsPages: [MainPage] = [.analytics, .insights, .history]

    var isStats: Bool {
        Self.statsPages.contains(self)
    }

    /// The tab this page sits under.
    var tab: MainPage {
        isStats ? .analytics : self
    }

    var tabTitle: String {
        self == .analytics ? "Stats" : title
    }

    var tabSymbol: String {
        switch self {
        case .focus:
            return "timer"
        case .blockedApps:
            return "shield.lefthalf.filled"
        case .schedules:
            return "calendar"
        case .analytics, .insights, .history:
            return "chart.bar.xaxis"
        case .settings:
            return "gearshape"
        }
    }
}

// MARK: - Top bar

/// The window's own title beside the traffic lights, as a titled Mac window
/// has, and under it a tab bar of four places, with where you stand (session
/// or streak) and Settings on the right.
private struct MainTopBar: View {
    @EnvironmentObject private var controller: MenuBarController
    @Namespace private var selection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Stats opens on whichever of its views you last had.
    @State private var lastStatsPage: MainPage = .analytics

    var body: some View {
        VStack(spacing: 0) {
            // The titlebar row. AppKit's own title is hidden, because it
            // would be centred over the tabs; this one sits where a unified
            // toolbar puts it.
            HStack {
                Text(AppIdentity.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.flInk)
                    .accessibilityHidden(true)
                Spacer()
            }
            .padding(.leading, 80)
            .frame(height: 32)

            // Equal flexible sides keep the tabs centred and give the corner
            // only the room beside them, so the status shortens instead of
            // running under the tabs.
            HStack(spacing: 12) {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: 1)

                tabBar
                    .fixedSize()

                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    statusPill
                    settingsButton
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            .frame(height: 46)
        }
        .onChange(of: controller.page) { _, page in
            if page.isStats { lastStatsPage = page }
        }
    }

    // MARK: Tabs

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(MainPage.tabBar) { page in
                tab(page)
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Color.flSunken)
        )
        .onMoveCommand { direction in
            let tabs = MainPage.tabBar
            guard let index = tabs.firstIndex(of: controller.page.tab) else { return }
            switch direction {
            case .left where index > 0: select(tabs[index - 1])
            case .right where index < tabs.count - 1: select(tabs[index + 1])
            default: break
            }
        }
        // One picker of pages for VoiceOver, "Focus, 1 of 4", not four buttons.
        .accessibilityRepresentation {
            Picker("Page", selection: Binding(get: { controller.page.tab }, set: { select($0) })) {
                ForEach(MainPage.tabBar) { page in
                    Text(page.tabTitle).tag(page)
                }
            }
            .pickerStyle(.segmented)
        }
        // The chip slides between tabs; with Reduce Motion it just moves.
        .animation(reduceMotion ? nil : FLAnimation.move, value: controller.page.tab)
    }

    private func select(_ page: MainPage) {
        if page == .analytics {
            if !controller.page.isStats { controller.page = lastStatsPage }
        } else {
            controller.page = page
        }
    }

    private func tab(_ page: MainPage) -> some View {
        let isSelected = controller.page.tab == page
        let needsAnswer = page == .blockedApps && controller.browserPermissionProblem != nil

        return Button {
            select(page)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: page.tabSymbol)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 16)
                Text(page.tabTitle)
                    .font(.system(size: 13, weight: .semibold))

                if needsAnswer {
                    Circle()
                        .fill(Color.flWarningInk)
                        .frame(width: 6, height: 6)
                        .accessibilityLabel("Needs your OK")
                }
            }
            .foregroundStyle(isSelected ? Color.flTabSelectedInk : Color.flInkSoft)
            .padding(.horizontal, 14)
            .frame(height: 30)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.flTabSelected)
                        .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                        .matchedGeometryEffect(id: "tab", in: selection)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: Corner

    /// Where you stand: the figure in the weight the eye lands on, the words
    /// around it secondary.
    private var statusPill: some View {
        Button {
            controller.page = .focus
        } label: {
            ViewThatFits(in: .horizontal) {
                statusLine(status.after)
                statusLine(status.afterShort)
                statusLine(status.afterTiny ?? status.afterShort)
            }
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Capsule().fill(isStatusHovered ? Color.flSunken : .clear))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isStatusHovered = $0 }
        .animation(FLAnimation.quick, value: isStatusHovered)
        .help("Go to Focus")
        .accessibilityLabel([status.before, status.figure, status.after].compactMap { $0 }.joined(separator: " "))
    }

    @State private var isStatusHovered = false

    private func statusLine(_ after: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            if let before = status.before {
                Text(before)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(status.tint)
            }
            if let figure = status.figure {
                Text(figure)
                    .font(.system(size: 13, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.flInk)
            }
            if let after {
                Text(after)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.flInkSoft)
            }
        }
    }

    private struct Status {
        var before: String?
        var figure: String?
        var after: String?
        var afterShort: String?
        /// For the narrowest window, where even the short form would be cut.
        var afterTiny: String?
        var tint: Color = .flInkSoft
    }

    private var status: Status {
        let countdown = controller.displayCountdown

        switch controller.snapshot.phase {
        case .focus:
            let label = controller.snapshot.isStrict ? "Strict" : "Guarding"
            return Status(before: label, figure: countdown, tint: .flAccentDeep)
        case .break:
            return Status(before: "Break", figure: countdown, tint: .flRestInk)
        case .breakEnded:
            return Status(before: "Break done", tint: .flRestInk)
        default:
            let streak = controller.streak
            let minutes = controller.sessionStats.focusMinutesToday
            guard streak > 0 else {
                // Someone coming back gets something to pick up from, not a
                // verdict on the days they missed.
                guard let last = controller.lastActiveDay else {
                    return Status(after: "No streak yet", afterShort: "No streak yet")
                }
                let day = Self.dayLabel(last.date)
                return Status(
                    after: "Last focus \(day) · \(FLWeeklyRhythm.duration(last.minutes))",
                    afterShort: "Last focus \(day)",
                    afterTiny: day
                )
            }
            let days = "day streak"
            let today = minutes > 0 ? "\(days) · \(FLWeeklyRhythm.duration(minutes)) today" : days
            return Status(figure: "\(streak)", after: today, afterShort: days, afterTiny: streak == 1 ? "day" : "days")
        }
    }

    /// "Fri" within the last week, "Sep 28" before that.
    private static func dayLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: Date())
        ).day ?? 0
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate(days < 7 ? "EEE" : "MMM d")
        return formatter.string(from: date)
    }

    private var settingsButton: some View {
        let isSelected = controller.page == .settings

        return Button {
            controller.page = .settings
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isSelected ? Color.flTabSelectedInk : Color.flInkSoft)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(isSelected ? Color.flTabSelected : Color.flSunken)
                        .shadow(color: .black.opacity(isSelected ? 0.12 : 0), radius: 3, y: 1)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Settings (⌘,)")
        .accessibilityLabel("Settings")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// The header the three Stats pages share: the title, a switcher between
/// Analytics, Insights and History, and the open page's own controls.
struct StatsHeader<Trailing: View>: View {
    @EnvironmentObject private var controller: MenuBarController
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .bottom, spacing: FLSpacing.md) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Stats")
                    .font(FLTypography.largeTitle)
                    .foregroundStyle(Color.flInk)
                    .accessibilityAddTraits(.isHeader)

                FLSegmentedControl(
                    options: MainPage.statsPages,
                    selection: Binding(get: { controller.page }, set: { controller.page = $0 }),
                    title: \.title,
                    accessibilityLabel: "Stats view"
                )
            }

            Spacer(minLength: FLSpacing.md)

            trailing()
        }
        .padding(.horizontal, FLLayout.pageInset)
        .padding(.top, 14)
        .padding(.bottom, 18)
    }
}

// MARK: - Focus page

struct FocusPageView: View {
    @EnvironmentObject private var controller: MenuBarController

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero

                if showsBreakPanel {
                    FLRule()
                    BreakPanel(showsGuide: !isOnBreak)
                        .flBand()
                }

                if let recap = controller.lastRecap, !controller.isSessionActive,
                   controller.snapshot.phase != .breakEnded {
                    FLRule()
                    RecapCard(recap: recap)
                        .flBand(vertical: 18)
                }

                FLRule()

                // The week and the day side by side, a hairline between.
                HStack(alignment: .top, spacing: FLLayout.columnGap) {
                    weeklyRhythm
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    FLColumnRule()
                    TodayBlocks()
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .fixedSize(horizontal: false, vertical: true)
                .flBand()
            }
            .padding(.bottom, 12)
        }
        .flScrollEdges()
        .sheet(isPresented: $showingEscape) {
            StrictEscapeSheet()
                .environmentObject(controller)
        }
    }


    @State private var showingEscape = false
    /// While the goal is being typed, Return belongs to the text field.
    @State private var isTypingGoal = false

    private var isOnBreak: Bool {
        controller.snapshot.phase == .break
    }

    private var showsBreakPanel: Bool {
        switch controller.snapshot.phase {
        case .break:
            // The guide is up beside the dial; the band holds the check-in.
            return controller.checkInEntry != nil
        case .breakEnded:
            return true
        case .completed:
            return controller.checkInEntry != nil
        default:
            return false
        }
    }

    // MARK: Hero
    //
    // One card: the time on the left; on the right, the block read top to
    // bottom the way you set it up: how long, what for, what it guards, then
    // the one button that commits to it and what that commitment means.

    private var hero: some View {
        HStack(alignment: .center, spacing: 36) {
            VStack(spacing: 18) {
                FocusDial(
                    phaseLabel: phaseLabel,
                    countdown: controller.displayCountdown,
                    progress: controller.isSessionActive ? controller.phaseProgress : 0,
                    isBreak: controller.snapshot.phase == .break,
                    isActive: controller.isSessionActive,
                    spokenPhase: spokenPhase
                )

                FLSessionBeads(
                    total: beadTotal,
                    completed: controller.sessionStats.sessionsCompletedToday,
                    isRunning: controller.isSessionActive
                )
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 16) {
                if isOnBreak {
                    // The break is the thing to do now; the next block can
                    // wait until it's over.
                    BreakSuggestionGuide()
                } else {
                    if !controller.isSessionActive {
                        durationSetup
                    }

                    FocusGoalBar(onTypingChange: { isTypingGoal = $0 })
                }

                if controller.offersFirstDistraction {
                    FirstDistractionPrompt()
                } else {
                    guardCell
                }

                if !controller.offersFirstDistraction {
                    commitBlock
                        .padding(.top, 2)
                }

                if controller.snapshot.phase == .focus {
                    FirstBlockNotificationPrompt(permissions: controller.permissions)
                }

                if let message = controller.focusMessage {
                    Text(message)
                        .font(FLTypography.callout)
                        .foregroundStyle(Color.flClayInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(width: 420, alignment: .leading)
        }
        .padding(.horizontal, FLLayout.pageInset)
        .padding(.top, 14)
        .padding(.bottom, 30)
    }

    private var beadTotal: Int {
        let completed = controller.sessionStats.sessionsCompletedToday
        return max(4, completed + (controller.isSessionActive ? 1 : 0))
    }

    private var phaseLabel: String {
        switch controller.snapshot.phase {
        case .focus:
            let strict = controller.snapshot.isStrict ? " · Strict" : ""
            return "Focus · \(controller.snapshot.focusMinutes) / \(controller.snapshot.breakMinutes)\(strict)"
        case .break:
            let kind = controller.currentBreakIsLong ? "Long break" : "Break"
            return "\(kind) · block \(controller.snapshot.currentCycle) done"
        case .breakEnded:
            return "Break ended"
        default:
            let strict = controller.nextBlockIsStrict ? " · Strict" : ""
            return "Ready · \(controller.config.focusMinutes) / \(controller.config.breakMinutes)\(strict)"
        }
    }

    /// The dial's phase in words, for VoiceOver: "50 / 10" is shorthand for
    /// the eye, not the ear.
    private var spokenPhase: String {
        let focus = controller.isSessionActive ? controller.snapshot.focusMinutes : controller.config.focusMinutes
        let rest = controller.isSessionActive ? controller.snapshot.breakMinutes : controller.config.breakMinutes
        let durations = "\(focus) minute focus, \(rest) minute break"
        switch controller.snapshot.phase {
        case .focus:
            return (controller.snapshot.isStrict ? "Strict focus, " : "Focus, ") + durations
        case .break:
            return "Break after block \(controller.snapshot.currentCycle)"
        case .breakEnded:
            return "Break ended"
        default:
            return (controller.nextBlockIsStrict ? "Ready, strict, " : "Ready, ") + durations
        }
    }

    // MARK: Set up

    private var durationSetup: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                FLSegmentedControl(
                    options: FocusPreset.allCases,
                    selection: Binding(
                        get: { controller.preset },
                        set: { controller.selectPreset($0) }
                    ),
                    title: \.title,
                    accessibilityLabel: "Block length"
                )

                Spacer(minLength: 0)

                strictChip
            }

            if controller.preset == .custom {
                HStack(spacing: 20) {
                    FLDurationField(
                        label: "Focus",
                        minutes: Binding(
                            get: { controller.config.focusMinutes },
                            set: { controller.updateFocusMinutes($0) }
                        ),
                        range: AppConfig.focusMinutesRange
                    )

                    FLDurationField(
                        label: "Break",
                        minutes: Binding(
                            get: { controller.config.breakMinutes },
                            set: { controller.updateBreakMinutes($0) }
                        ),
                        range: 0...60
                    )
                }
            }
        }
    }

    /// Strict decided where you commit, for this one block. Settings holds
    /// the default it starts from; a strict run or schedule can't be undone
    /// here.
    private var strictChip: some View {
        let isOn = controller.nextBlockIsStrict
        let isForced = controller.nextBlockStrictIsForced

        return Button {
            controller.nextBlockStrictChoice = !isOn
        } label: {
            HStack(spacing: 5) {
                Image(systemName: isOn ? "lock.fill" : "lock.open")
                    .font(.system(size: 10.5, weight: .semibold))
                Text("Strict")
                    .font(.system(size: 12.5, weight: .semibold))
            }
            .foregroundStyle(isOn ? Color.flAccentDeep : Color.flInkSoft)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(Capsule().fill(isOn ? Color.flAccentSoft : Color.flSunken))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isForced)
        .help(isForced
              ? "This block is strict because the run or schedule it belongs to is"
              : isOn ? "This block can’t be ended early. Click to make it a normal block."
                     : "Make this block strict: it can’t be ended early")
        .accessibilityLabel("Strict block")
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
    }

    /// What the block takes away, said before you start it, in one well:
    /// the apps, that the call you are on carries on, and anything that
    /// stops a guard from working.
    private var guardCell: some View {
        VStack(alignment: .leading, spacing: 10) {
            guardLine

            if let browser = controller.browserPermissionProblem, !controller.config.blockedSites.isEmpty {
                unguardedBrowserWarning(browser)
            }
        }
    }

    private var guardLine: some View {
        HStack(spacing: 12) {
            if controller.activeBlockedApps.isEmpty && controller.activeBlockedSites.isEmpty {
                Image(systemName: "shield")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.flInkSoft)
                    .frame(width: 26)
                Text(controller.config.blockedApps.isEmpty && controller.config.blockedSites.isEmpty
                     ? "Nothing guarded yet"
                     : "Everything guarded is switched off")
                    .font(FLTypography.body)
                    .foregroundStyle(Color.flInkSoft)
            } else {
                if !controller.activeBlockedApps.isEmpty {
                    FLAppPile(apps: controller.activeBlockedApps.map {
                        FLAppPile.BlockedAppSummary(id: $0.bundleId, bundleId: $0.bundleId)
                    })
                } else {
                    Image(systemName: "globe")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.flAccentDeep)
                        .frame(width: 26)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(guardedNames)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.flInk)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(guardPromise.text)
                        .font(FLTypography.callout)
                        .foregroundStyle(guardPromise.isWarning ? Color.flClayInk : Color.flInkSoft)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if !isOnBreak {
                        WebsiteProtectionAvailabilityNote(permissions: controller.permissions)
                    }
                }
            }

            Spacer(minLength: FLSpacing.sm)

            Button {
                controller.page = .blockedApps
            } label: {
                HStack(spacing: 3) {
                    Text(controller.config.blockedApps.isEmpty && controller.config.blockedSites.isEmpty ? "Add" : "Manage")
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                }
            }
            .buttonStyle(FLLinkButtonStyle())
        }
        // `.contain` keeps Manage its own button for VoiceOver.
        .accessibilityElement(children: .contain)
    }

    private var guardedNames: String {
        let apps = controller.activeBlockedApps.map(\.name)
        let sites = controller.activeBlockedSites.count
        if isOnBreak {
            return breakFreedom(apps: apps, sites: sites)
        }
        // Counts, not a list: the icons beside this already say which apps,
        // and a list of names runs out of room by the third.
        var parts: [String] = []
        switch apps.count {
        case 0: break
        case 1: parts.append(apps[0])
        default: parts.append("\(apps.count) apps")
        }
        if sites > 0 {
            parts.append("\(sites) website\(sites == 1 ? "" : "s")")
        }
        let verb = controller.snapshot.phase == .focus ? "Guarding" : "Guards"
        return "\(verb) " + parts.joined(separator: " and ")
    }

    /// "Discord and 2 sites are yours until 1:23 PM": what the break hands
    /// back, which is the moment someone on a call wants to know it.
    private func breakFreedom(apps: [String], sites: Int) -> String {
        var things = Array(apps.prefix(2))
        if apps.count > 2 { things.append("\(apps.count - 2) more") }
        if sites > 0 { things.append("\(sites) site\(sites == 1 ? "" : "s")") }
        let list: String
        switch things.count {
        case 0: list = "Everything"
        case 1: list = things[0]
        default: list = things.dropLast().joined(separator: ", ") + " and " + things[things.count - 1]
        }
        let plural = things.count > 1 || (apps.isEmpty && sites > 1)
        let until = controller.snapshot.phaseEndsAt.map { " until \(Self.time($0))" } ?? ""
        return "\(list) \(plural ? "are" : "is") yours\(until)"
    }

    private var guardPromise: (text: String, isWarning: Bool) {
        if isOnBreak {
            return ("Guarding picks up again when the next block starts", false)
        }
        let mode = controller.config.blockerMode
        if let caller = controller.activeBlockedApps.first(where: {
            $0.isCallingApp && $0.effectiveBehavior(default: mode) == .quitApp
        }) {
            return ("\(caller.name) quits if opened, which ends any call it’s on", true)
        }
        switch mode {
        case .guardScreen:
            return ("Guard Screen · calls keep going", false)
        case .hideOnly:
            return ("Hide Only · apps tucked out of sight", false)
        case .quitApp:
            return ("Quit App · guarded apps close", false)
        }
    }

    /// Without the browser's OK, Quietwhile can't see its tabs, so guarded sites
    /// open freely. That must not hide below the fold.
    private func unguardedBrowserWarning(_ browser: SupportedBrowser) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11.5))
                .foregroundStyle(Color.flWarningInk)

            Text("Websites aren’t guarded in \(browser.displayName) yet")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.flInk)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: FLSpacing.sm)

            Button("Allow…") {
                controller.page = .blockedApps
            }
            .buttonStyle(FLLinkButtonStyle(tint: .flWarningInk))
        }
    }

    // MARK: Commit

    private func extendButton(minHeight: CGFloat, label: String? = nil) -> some View {
        Button(label ?? "+\(MenuBarController.extendMinutes) min") {
            controller.extendCurrentPhase()
        }
        .buttonStyle(FLActionButtonStyle(variant: .quiet, minHeight: minHeight))
        .help(controller.snapshot.phase == .focus ? "Add five minutes to this block" : "Add five minutes to the break")
    }

    /// The one button, and in plain words what pressing it means. While a
    /// block runs the time is the loud thing; every way out stays quiet.
    @ViewBuilder
    private var commitBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                switch controller.snapshot.phase {
                case .focus where controller.isStrictLocked:
                    Label("Strict until \(endLabel)", systemImage: "lock.fill")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Color.flInk)
                        .labelStyle(LockLabelStyle())

                    Button("Emergency exit…") {
                        showingEscape = true
                    }
                    .buttonStyle(FLActionButtonStyle(variant: .quiet, minHeight: 36))

                case .focus:
                    Button("End session") {
                        controller.requestStopSession()
                    }
                    .buttonStyle(FLActionButtonStyle(variant: .secondary, minHeight: 36))

                    Button("Skip to break") {
                        controller.requestSkipPhase()
                    }
                    .buttonStyle(FLActionButtonStyle(variant: .quiet, minHeight: 36))

                    extendButton(minHeight: 36)

                case .break:
                    // A break's ways back to work are offered, never urged.
                    Button("Start next block") {
                        controller.requestSkipPhase()
                    }
                    .buttonStyle(FLActionButtonStyle(variant: .quiet, minHeight: 32))

                    Button("End session") {
                        controller.requestStopSession()
                    }
                    .buttonStyle(FLActionButtonStyle(variant: .quiet, minHeight: 32))

                    extendButton(minHeight: 32)

                case .breakEnded:
                    startButton

                    extendButton(minHeight: 44, label: "+\(MenuBarController.extendMinutes) min break")

                    Button("End cycle") {
                        controller.requestStopSession()
                    }
                    .buttonStyle(FLActionButtonStyle(variant: .secondary, minHeight: 44))

                default:
                    startButton
                }
            }

            consequenceLine
        }
    }

    /// A strict block can't be taken back, so it never starts on a stray
    /// Return and its button says what it is.
    @ViewBuilder
    private var startButton: some View {
        if controller.nextBlockIsStrict {
            Button("Start strict block") {
                controller.startFocus()
            }
            .buttonStyle(FLActionButtonStyle(variant: .primary, minHeight: 44, fullWidth: true))
        } else {
            Button("Start focus") {
                controller.startFocus()
            }
            .buttonStyle(FLActionButtonStyle(variant: .primary, minHeight: 44, fullWidth: true))
            .keyboardShortcut(isTypingGoal ? nil : .defaultAction)
        }
    }

    @ViewBuilder
    private var consequenceLine: some View {
        let startsBlock = !controller.isSessionActive
        if startsBlock && controller.nextBlockIsStrict {
            let ends = Date().addingTimeInterval(TimeInterval(controller.config.focusMinutes * 60))
            Label(
                "Can’t be ended until \(Self.time(ends)) · the emergency exit waits \(Self.wait(controller.config.strict.escapeWaitSeconds))",
                systemImage: "lock.fill"
            )
            .font(FLTypography.caption)
            .foregroundStyle(Color.flInk)
            .labelStyle(LockLabelStyle())
            .fixedSize(horizontal: false, vertical: true)
        } else if !isOnBreak {
            // In a break the freedom line already says when focus resumes.
            Text(scheduleLine)
                .font(FLTypography.caption)
                .foregroundStyle(Color.flInkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private static func wait(_ seconds: Int) -> String {
        guard seconds >= 60 else { return "\(seconds) s" }
        let minutes = seconds / 60
        let remainder = seconds % 60
        return remainder == 0 ? "\(minutes) min" : "\(minutes) min \(remainder) s"
    }

    private var endLabel: String {
        controller.snapshot.phaseEndsAt.map(Self.time) ?? "the end"
    }

    private var scheduleLine: String {
        switch controller.snapshot.phase {
        case .focus:
            guard let endsAt = controller.snapshot.phaseEndsAt else {
                return "Guard is on"
            }
            if controller.snapshot.breakMinutes > 0 {
                let kind = controller.currentBreakIsLong ? "long break" : "break"
                return "\(controller.snapshot.breakMinutes) min \(kind) at \(Self.time(endsAt))"
            }
            return "Ends at \(Self.time(endsAt))"

        case .break:
            guard let endsAt = controller.snapshot.phaseEndsAt else {
                return "Guard paused during the break"
            }
            return "Focus resumes at \(Self.time(endsAt))"

        case .breakEnded:
            return controller.autoResumeStatusLine ?? "Ready for the next block"

        default:
            if let occurrence = controller.activeScheduleOccurrence {
                return "\(occurrence.schedule.name) runs until \(Self.time(occurrence.end)) — stopped for today"
            }
            let ends = Date().addingTimeInterval(TimeInterval(controller.config.focusMinutes * 60))
            if controller.config.breakMinutes > 0 {
                return "Ends at \(Self.time(ends)) · break follows automatically"
            }
            return "Ends at \(Self.time(ends))"
        }
    }

    private static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    // MARK: Weekly rhythm

    private var weeklyRhythm: some View {
        VStack(alignment: .leading, spacing: 18) {
            FLSectionHeader(title: "Last 7 days", subtitle: controller.recentSummary.detail) {
                Text(formatted(minutes: controller.recentSummary.totalMinutes))
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.flInk)
            }

            FLWeeklyRhythm(
                days: controller.recentRhythm.map { day in
                    FLWeeklyRhythm.DailyFocusColumn(
                        id: day.date,
                        label: day.label,
                        dayName: Self.dayName(day.date),
                        minutes: day.minutes,
                        sessions: day.sessions,
                        categories: day.categories.map { ($0.name, $0.minutes) },
                        isToday: day.isToday,
                        isFuture: day.isFuture
                    )
                },
                goalMinutes: controller.config.dailyFocusGoalMinutes
            )
        }
    }

    private static func dayName(_ date: Date) -> String {
        let calendar = Calendar.current
        let index = calendar.component(.weekday, from: date) - 1
        let symbols = calendar.weekdaySymbols
        return symbols.indices.contains(index) ? symbols[index] : ""
    }

    private func formatted(minutes: Int) -> String {
        guard minutes >= 60 else {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }
}

/// A lock glyph in the accent beside plain ink: a limit stated, not a button.
private struct LockLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            configuration.icon
                .foregroundStyle(Color.flAccentDeep)
                .imageScale(.small)
            configuration.title
        }
    }
}
