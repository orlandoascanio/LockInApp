import FocusLockCore
import SwiftUI

enum MainPage: String, CaseIterable, Identifiable {
    case focus
    case blockedApps
    case schedules
    case history
    case analytics
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
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(PageWashBackground(
            page: controller.page,
            isBreak: controller.page == .focus && controller.snapshot.phase == .break
        ))
    }
}

// MARK: - Page wash

/// Every page's wash stacked, the current one shown, so switching pages
/// crossfades from one colour to the next.
private struct PageWashBackground: View {
    let page: MainPage
    /// A break turns the Focus page slate: rest, never more focus.
    var isBreak = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ForEach(MainPage.allCases) { candidate in
                wash(candidate.wash)
                    .opacity(candidate == page && !isBreak ? 1 : 0)
            }
            wash(.restSlate)
                .opacity(isBreak ? 1 : 0)
        }
        // A crossfade is not motion, but with Reduce Motion on it settles
        // faster so the page doesn't seem to drift. Into a break it takes
        // its time, like an exhale.
        .animation(reduceMotion ? .linear(duration: 0.12) : FLAnimation.entrance, value: page)
        .animation(reduceMotion ? .linear(duration: 0.12) : .easeInOut(duration: 0.9), value: isBreak)
        .ignoresSafeArea()
    }

    private func wash(_ wash: FLPageWash) -> some View {
        LinearGradient(
            colors: [Color(nsColor: wash.top), Color(nsColor: wash.bottom)],
            startPoint: .top,
            endPoint: UnitPoint(x: 0.5, y: 0.7)
        )
    }
}

extension MainPage {
    var wash: FLPageWash {
        switch self {
        case .focus:
            return .terreVerte
        case .blockedApps:
            return .burntSienna
        case .schedules:
            return .yellowOchre
        case .history:
            return .rawUmber
        case .analytics:
            return .paynesGrey
        case .settings:
            return .unbleached
        }
    }

    /// The pages with a place in the tab bar. Settings hangs off the gear.
    static let tabs: [MainPage] = [.focus, .blockedApps, .schedules, .history, .analytics]
}

// MARK: - Top bar

/// A pill of tabs centred in the titlebar, with where you stand (session or
/// streak) and Settings tucked into the right-hand corner.
private struct MainTopBar: View {
    @EnvironmentObject private var controller: MenuBarController
    @Namespace private var selection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Equal flexible sides keep the pill centred and give the corner only
        // the room beside it, so the status shortens instead of running under
        // the tabs.
        HStack(spacing: 12) {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: 1)

            tabPill
                .fixedSize()

            HStack(spacing: 8) {
                Spacer(minLength: 0)
                statusPill
                settingsButton
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .frame(height: 58)
    }

    // MARK: Tabs

    private var tabPill: some View {
        HStack(spacing: 2) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 26, height: 26)
                .padding(.horizontal, 5)
                .accessibilityHidden(true)

            ForEach(MainPage.tabs) { page in
                tab(page)
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.flInk.opacity(0.06)))
        .overlay(Capsule().strokeBorder(Color.flHairline.opacity(0.7), lineWidth: 1))
        .onMoveCommand { direction in
            let tabs = MainPage.tabs
            guard let index = tabs.firstIndex(of: controller.page) else { return }
            switch direction {
            case .left where index > 0: controller.page = tabs[index - 1]
            case .right where index < tabs.count - 1: controller.page = tabs[index + 1]
            default: break
            }
        }
        // One picker of pages for VoiceOver, "Focus, 1 of 5", not five buttons.
        .accessibilityRepresentation {
            Picker("Page", selection: Binding(get: { controller.page }, set: { controller.page = $0 })) {
                ForEach(MainPage.tabs) { page in
                    Text(page.title).tag(page)
                }
            }
            .pickerStyle(.segmented)
        }
        // The chip slides between tabs; with Reduce Motion it just moves.
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.86), value: controller.page)
    }

    private func tab(_ page: MainPage) -> some View {
        let isSelected = controller.page == page
        let needsAnswer = page == .blockedApps && controller.browserPermissionProblem != nil

        return Button {
            controller.page = page
        } label: {
            HStack(spacing: 5) {
                Text(page.title)
                    .font(.system(size: 12.5, weight: .semibold))

                if needsAnswer {
                    Circle()
                        .fill(Color.flWarningInk)
                        .frame(width: 6, height: 6)
                        .accessibilityLabel("Needs your OK")
                }
            }
            .foregroundStyle(isSelected ? Color.flTabSelectedInk : Color.flInkSoft)
            .padding(.horizontal, 15)
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

    /// Where you stand, set as type rather than a badge: the number in the
    /// serif the dial uses, the words around it small.
    private var statusPill: some View {
        Button {
            controller.page = .focus
        } label: {
            ViewThatFits(in: .horizontal) {
                statusLine(status.after)
                statusLine(status.afterShort)
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
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(status.tint)
            }
            if let figure = status.figure {
                Text(figure)
                    .font(.system(size: 17, weight: .regular, design: .serif))
                    .monospacedDigit()
                    .foregroundStyle(Color.flInk)
            }
            if let after {
                Text(after)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.flInkSoft)
            }
        }
    }

    private struct Status {
        var before: String?
        var figure: String?
        var after: String?
        var afterShort: String?
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
                    afterShort: "Last focus \(day)"
                )
            }
            let days = "day streak"
            let today = minutes > 0 ? "\(days) · \(FLWeeklyRhythm.duration(minutes)) today" : days
            return Status(figure: "\(streak)", after: today, afterShort: days)
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
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? Color.flTabSelectedInk : Color.flInkSoft)
                .frame(width: 30, height: 30)
                .background(
                    Circle().fill(isSelected ? Color.flTabSelected : Color.flInk.opacity(0.06))
                )
                .overlay(Circle().strokeBorder(Color.flHairline.opacity(isSelected ? 0 : 0.7), lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Settings")
        .accessibilityLabel("Settings")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
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
                }

                if let recap = controller.lastRecap, !controller.isSessionActive,
                   controller.snapshot.phase != .breakEnded {
                    FLRule()
                    RecapCard(recap: recap)
                }

                FLRule()

                weeklyRhythm

                FLRule()

                TodayBlocks()
            }
            .padding(.bottom, Self.fadeHeight)
        }
        // The page runs on below the fold; a soft edge says so.
        .mask(
            VStack(spacing: 0) {
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: Self.fadeHeight)
            }
        )
        .sheet(isPresented: $showingEscape) {
            StrictEscapeSheet()
                .environmentObject(controller)
        }
    }

    private static let fadeHeight: CGFloat = 28

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
    // The time on the left; on the right, the block read top to bottom the
    // way you set it up: how long, what for, what it guards, then the one
    // button that commits to it and what that commitment means.

    private var hero: some View {
        HStack(alignment: .center, spacing: 44) {
            VStack(spacing: 16) {
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

            VStack(alignment: .leading, spacing: 20) {
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
                    guardLine
                }

                if !isOnBreak {
                    WebsiteProtectionAvailabilityNote(permissions: controller.permissions)
                }

                if let browser = controller.browserPermissionProblem, !controller.config.blockedSites.isEmpty {
                    unguardedBrowserWarning(browser)
                }

                if !controller.offersFirstDistraction {
                    commitBlock
                }

                if controller.snapshot.phase == .focus {
                    FirstBlockNotificationPrompt(permissions: controller.permissions)
                }

                if let message = controller.focusMessage {
                    Text(message)
                        .font(FLTypography.caption)
                        .foregroundStyle(Color.flClayInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(width: 440, alignment: .leading)
        }
        .padding(.horizontal, 26)
        .padding(.top, 18)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity)
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
            return "Break · block \(controller.snapshot.currentCycle) done"
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
            .frame(height: 30)
            .background(Capsule().fill(isOn ? Color.flAccentSoft.opacity(0.55) : .clear))
            .overlay(Capsule().strokeBorder(isOn ? Color.flAccentDeep.opacity(0.4) : Color.flHairline, lineWidth: 1))
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

    /// What the block takes away, said before you start it — and that the
    /// call you are on carries on.
    private var guardLine: some View {
        HStack(spacing: 12) {
            if controller.activeBlockedApps.isEmpty && controller.activeBlockedSites.isEmpty {
                Text(controller.config.blockedApps.isEmpty && controller.config.blockedSites.isEmpty
                     ? "Nothing guarded yet"
                     : "Everything guarded is switched off")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.flInkSoft)
            } else {
                if !controller.activeBlockedApps.isEmpty {
                    FLAppPile(apps: controller.activeBlockedApps.map {
                        FLAppPile.BlockedAppSummary(id: $0.bundleId, bundleId: $0.bundleId)
                    })
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(guardedNames)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.flInk)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(guardPromise.text)
                        .font(FLTypography.caption)
                        .foregroundStyle(guardPromise.isWarning ? Color.flClayInk : Color.flInkSoft)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: FLSpacing.sm)

            Button {
                controller.page = .blockedApps
            } label: {
                HStack(spacing: 5) {
                    Text(controller.config.blockedApps.isEmpty && controller.config.blockedSites.isEmpty ? "Add" : "Manage")
                        .font(.system(size: 12, weight: .medium))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(Color.flAccentDeep)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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
        var names = apps.prefix(2).joined(separator: ", ")
        if apps.count > 2 {
            names += " and \(apps.count - 2) more"
        }
        let verb = controller.snapshot.phase == .focus ? "Guarding" : "Guards"
        var parts: [String] = names.isEmpty ? [] : ["\(verb) \(names)"]
        if sites > 0 {
            parts.append("\(sites) site\(sites == 1 ? "" : "s") selected")
        }
        return parts.joined(separator: " · ")
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
            return ("Guard Screen · apps keep running, calls keep going", false)
        case .hideOnly:
            return ("Hide Only · apps keep running, just out of sight", false)
        case .quitApp:
            return ("Quit App · guarded apps close if opened", false)
        }
    }

    /// Without the browser's OK, Quietwhile can't see its tabs, so guarded sites
    /// open freely. That must not hide below the fold.
    private func unguardedBrowserWarning(_ browser: SupportedBrowser) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(Color.flWarningInk)

            Text("Websites aren’t guarded in \(browser.displayName) yet. It needs your OK first.")
                .font(.system(size: 12.5))
                .foregroundStyle(Color.flInk)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: FLSpacing.sm)

            Button {
                controller.page = .blockedApps
            } label: {
                HStack(spacing: 5) {
                    Text("Allow…")
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(Color.flWarningInk)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.flWarning.opacity(0.12), in: RoundedRectangle(cornerRadius: FLRadius.md, style: .continuous))
    }

    // MARK: Commit

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

                case .breakEnded:
                    startButton

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
            .buttonStyle(FLActionButtonStyle(variant: .primary, minHeight: 44))
        } else {
            Button("Start focus") {
                controller.startFocus()
            }
            .buttonStyle(FLActionButtonStyle(variant: .primary, minHeight: 44))
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
            if controller.config.breakMinutes > 0 {
                return "\(controller.config.breakMinutes) min break at \(Self.time(endsAt))"
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                FLMicroLabel(text: "Last 7 days")
                Text("· \(formatted(minutes: controller.recentSummary.totalMinutes))")
                    .font(FLTypography.caption.weight(.semibold))
                    .foregroundStyle(Color.flInk)
                Spacer()
                Text(controller.recentSummary.detail)
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flInkSoft)
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
        .padding(.horizontal, 26)
        .padding(.vertical, 20)
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
