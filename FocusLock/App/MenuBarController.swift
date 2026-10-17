import AppKit
import FocusLockCore
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers
import WidgetKit

enum FocusPreset: String, CaseIterable, Identifiable {
    case twentyFiveFive
    case fiftyTen
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .twentyFiveFive:
            return "25 / 5"
        case .fiftyTen:
            return "50 / 10"
        case .custom:
            return "Custom"
        }
    }

    var durations: (focus: Int, rest: Int)? {
        switch self {
        case .twentyFiveFive:
            return (25, 5)
        case .fiftyTen:
            return (50, 10)
        case .custom:
            return nil
        }
    }
}

@MainActor
final class MenuBarController: NSObject, ObservableObject {
    @Published var config: AppConfig
    @Published var snapshot: TimerSnapshot
    @Published var history: [SessionHistoryEntry]
    @Published var preset: FocusPreset = .fiftyTen
    /// A short confirmation or error under Settings and Blocked. It clears
    /// itself, so "Added gmail.com." doesn't sit there for the rest of the day.
    @Published var settingsMessage: String? {
        didSet { scheduleSettingsMessageClear() }
    }
    private var settingsMessageClearTask: Task<Void, Never>?
    @Published var exportMessage: String?
    @Published var focusMessage: String?

    /// Which pane the sidebar is showing. Settings, History, and Analytics are
    /// panes rather than separate windows, so navigation lives here.
    @Published var page: MainPage = .focus

    /// The welcome guide takes over the main window while this is set: on a
    /// first launch, or when replayed from the Help menu.
    @Published private(set) var isOnboarding = false
    @Published private(set) var onboardingProgress: OnboardingProgress

    /// Focus minutes per weekday for the current week, and the run of days with
    /// at least one completed session. Cached because both are read on every
    /// redraw but only change when a session ends.
    @Published private(set) var weeklyRhythm: [DailyFocus] = []
    @Published private(set) var weekSummary = WeekFocusSummary(totalMinutes: 0, lastWeekSoFarMinutes: 0, elapsedDays: 1)
    /// The last seven days ending today, for the Focus page's chart.
    @Published private(set) var recentRhythm: [DailyFocus] = []
    @Published private(set) var recentSummary = RecentFocusSummary(totalMinutes: 0, previousMinutes: 0)
    /// The most recent day with a completed block, for welcoming someone back.
    @Published private(set) var lastActiveDay: DailyFocus?
    @Published private(set) var streak: Int = 0
    @Published private(set) var blockedTodayCounts: [String: Int] = [:]
    @Published private(set) var sessionStats: SessionStats = .empty

    /// The emergency exit in progress, if any.
    @Published private(set) var strictEscape: StrictEscape?

    /// The browser that refused Quietwhile permission to read its tabs.
    @Published private(set) var browserPermissionProblem: SupportedBrowser?

    /// The schedule window open right now, whether or not it started a block.
    @Published private(set) var activeScheduleOccurrence: ScheduleOccurrence?

    /// What the last finished run added up to.
    @Published private(set) var lastRecap: RunRecap?

    @Published private(set) var hotkeyFailures: Set<HotkeyAction> = []
    @Published var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

    let permissions = PermissionCenter()

    private let stateStore: StateStore
    private let onboardingStore: OnboardingStore
    private let historyStore: SessionHistoryStore
    private let exportService: ExportService
    private let notificationService: NotificationService
    private let blocker: AppBlocker
    private let timerEngine: TimerEngine
    private let activityStore = BlockActivityStore()
    private let reachLog = ReachLogStore()
    private let focusTimeStore = FocusTimeStore()
    private let domainSampler = BrowserDomainSampler()
    /// Every reach and every block's focus time, for Insights.
    @Published private(set) var reaches: [Reach] = []
    @Published private(set) var focusTimeRecords: [FocusTimeRecord] = []
    private var focusTime = FocusTimeAccumulator()
    private var lastFocusTimeSample: Date?
    private var lastDomainSample = Date.distantPast
    let breakActivity = BreakActivityStore()
    /// This break's suggestion, chosen once when it starts.
    @Published private(set) var breakPick: BreakActivityStore.Pick?
    private let websiteGuard = WebsiteGuard()
    private let hotkeys = HotkeyManager()
    private let watchdog = StrictWatchdog()
    private let overlay = FocusOverlayController()
    private let breakEndedOverlay = BreakEndedWindowController()
    private let autoResumeOverlay = AutoResumeOverlayController()
    private let pinnedHUD = PinnedHUDController()
    private let notchIsland = NotchIslandController()

    private let snoozeMinutes = 5
    /// What "+5 min" adds, to a block, a break, or a break that ran out.
    static let extendMinutes = 5
    /// The end of the focus block the one-minute warning was last shown for,
    /// so it shows once per block, and again if the block is extended.
    private var finalMinuteShownFor: Date?
    /// Set by the tick when a timer ran out on its own; consumed by `apply`.
    private var timerRanOutFrom: SessionPhase?
    private var lastInterceptedBundleId: String?

    /// When autopilot started counting the current wait: the moment the break
    /// ended, or the moment the takeover was last pushed away. In memory only —
    /// quitting ends the cycle anyway.
    private var autoResumeAnchor: Date?

    /// When the current run of back-to-back blocks began, for its recap.
    private var runStartedAt: Date? {
        get { UserDefaults.standard.object(forKey: Self.runStartedKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: Self.runStartedKey) }
    }

    private var lastEyeReminderAt: Date?
    private var lastWebsiteCheck = Date.distantPast
    private var unreadableBrowsersNoticed: Set<SupportedBrowser> = []
    private var lastScheduleCheck = Date.distantPast
    private var lastWidgetSnapshot: WidgetSnapshot?
    private var widgetCommandObserver: DarwinNotificationObserver?

    private var tickTimer: Timer?
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var mainWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var reopenObserver: NSObjectProtocol?
    private var blockerRunning = false
    private var hasSetup = false

    private static let runStartedKey = "LockInRunStartedAt"
    private static let dismissedSchedulesKey = "LockInDismissedScheduleOccurrences"

    var menuBarSymbolName: String {
        switch snapshot.phase {
        case .focus:
            return "lock.fill"
        case .break:
            return "cup.and.saucer.fill"
        default:
            return "lock.open"
        }
    }

    var isSessionActive: Bool {
        snapshot.phase == .focus || snapshot.phase == .break
    }

    /// True while a strict block is running: ending, skipping, allowing a
    /// guarded app, weakening the guard, and quitting are all refused.
    var isStrictLocked: Bool {
        StrictPolicy.isLocked(phase: snapshot.phase, sessionIsStrict: snapshot.isStrict)
    }

    /// The Focus page's Strict chip: this one block, overriding the Settings
    /// default. `nil` follows the default; cleared once a block starts.
    @Published var nextBlockStrictChoice: Bool?

    /// Strict that the chip can't turn off: a strict run continuing after
    /// its break, or a strict schedule window.
    var nextBlockStrictIsForced: Bool {
        if snapshot.phase == .break || snapshot.phase == .breakEnded, snapshot.isStrict {
            return true
        }
        return activeScheduleOccurrence?.schedule.strict == true
    }

    /// Whether the block that Start would begin right now runs strict.
    /// Mirrors the choice `startFocus` makes.
    var nextBlockIsStrict: Bool {
        nextBlockStrictIsForced || (nextBlockStrictChoice ?? config.strict.enabled)
    }

    /// Apps that are actually guarded right now — entries toggled off stay in
    /// the list but are excluded everywhere the count is shown.
    var activeBlockedApps: [BlockedApp] {
        config.blockedApps.filter(\.isEnabled)
    }

    var activeBlockedSites: [BlockedSite] {
        config.blockedSites.filter(\.isEnabled)
    }

    func blockedTodayCount(for app: BlockedApp) -> Int {
        blockedTodayCounts[app.bundleId] ?? 0
    }

    func blockedTodayCount(for site: BlockedSite) -> Int {
        blockedTodayCounts[Self.activityKey(for: site)] ?? 0
    }

    /// What the clock should read. Idle and finished states show the duration
    /// that pressing Start would run, rather than a bare 00:00 that looks like
    /// a session ended badly.
    var displayCountdown: String {
        switch snapshot.phase {
        case .focus, .break, .paused:
            return snapshot.formattedRemaining
        default:
            return String(format: "%02d:00", config.focusMinutes)
        }
    }

    /// What autopilot is about to do, for the main window. `nil` whenever
    /// autopilot has nothing pending — a break that is over is the only moment
    /// it has an opinion.
    var autoResumeStatusLine: String? {
        guard
            config.breakEndBehavior == .autopilot,
            snapshot.phase == .breakEnded,
            let breakEndedAt = snapshot.breakEndedAt
        else {
            return nil
        }

        switch config.autoResume.stage(since: autoResumeAnchor ?? breakEndedAt, now: Date()) {
        case .waiting(let secondsUntilCountdown):
            let minutes = max(1, Int((secondsUntilCountdown / 60).rounded(.up)))
            return "Autopilot takes over in \(minutes) min"
        case .countdown(let remaining):
            return "Autopilot starts focus in \(Self.formatCountdown(remaining))"
        case .start:
            return "Autopilot is starting the next block"
        }
    }

    /// Fraction of the current phase already elapsed, for the HUD ring.
    var phaseProgress: Double {
        let totalMinutes = snapshot.phase == .break ? snapshot.breakMinutes : snapshot.focusMinutes
        let total = TimeInterval(totalMinutes * 60)

        guard total > 0 else {
            return 0
        }

        return min(1, max(0, (total - snapshot.remainingSeconds) / total))
    }

    /// What to do with this break, while one is running or just over.
    var breakSuggestion: BreakSuggestion? {
        guard
            snapshot.phase == .break || snapshot.phase == .breakEnded,
            let pick = breakPick,
            pick.breakKey == currentBreakKey
        else {
            return nil
        }
        return BreakSuggestions.suggestion(of: pick.kind, cycle: snapshot.currentCycle)
    }

    private var currentBreakKey: String {
        Self.breakKey(sessionStartedAt: snapshot.sessionStartedAt, cycle: snapshot.currentCycle)
    }

    private static func breakKey(sessionStartedAt: Date?, cycle: Int) -> String {
        BreakActivityStore.breakKey(sessionStartedAt: sessionStartedAt ?? .distantPast, cycle: cycle)
    }

    /// Chooses this break's suggestion the first time anything asks, so the
    /// notification, the Focus page and the HUD all show the same one, and
    /// the next break can avoid repeating it.
    @discardableResult
    private func ensureBreakPick(sessionStartedAt: Date?, cycle: Int, breakMinutes: Int) -> BreakSuggestion? {
        let key = Self.breakKey(sessionStartedAt: sessionStartedAt, cycle: cycle)
        if let pick = breakActivity.pick, pick.breakKey == key {
            if breakPick != pick { breakPick = pick }
            return BreakSuggestions.suggestion(of: pick.kind, cycle: cycle)
        }
        let context = BreakSuggestions.Context(cycle: cycle, breakMinutes: breakMinutes, previous: breakActivity.pick?.kind)
        guard let suggestion = BreakSuggestions.suggestion(for: context, settings: config.breakSuggestions) else {
            return nil
        }
        let pick = BreakActivityStore.Pick(breakKey: key, kind: suggestion.kind)
        breakActivity.savePick(pick)
        breakPick = pick
        return suggestion
    }

    /// "Another one": swap this break's suggestion for one not seen yet.
    func anotherBreakSuggestion() {
        guard let pick = breakPick, pick.breakKey == currentBreakKey else { return }
        let passedOver = pick.passedOver + [pick.kind]
        let context = BreakSuggestions.Context(
            cycle: snapshot.currentCycle,
            breakMinutes: snapshot.breakMinutes,
            previous: pick.kind,
            passedOver: Set(passedOver)
        )
        guard let next = BreakSuggestions.suggestion(for: context, settings: config.breakSuggestions) else { return }
        let swapped = BreakActivityStore.Pick(breakKey: pick.breakKey, kind: next.kind, passedOver: passedOver)
        breakActivity.savePick(swapped)
        breakPick = swapped
    }

    /// "Did it", or a guide that ran to its end. Counted once per break.
    func markBreakSuggestionDone() {
        guard let pick = breakPick, pick.breakKey == currentBreakKey, !pick.done else { return }
        breakActivity.markDone()
        breakPick = breakActivity.pick
    }

    var nextScheduleOccurrence: ScheduleOccurrence? {
        ScheduleEvaluator.nextOccurrence(in: config.schedules, after: Date())
    }

    /// The current task: the one the running block started with, or the one
    /// the next block will use.
    var currentTask: SessionTask {
        switch snapshot.phase {
        case .idle: return config.task.task
        default: return snapshot.task ?? config.task.task
        }
    }

    var checkInEntry: SessionHistoryEntry? {
        guard snapshot.phase == .break || snapshot.phase == .breakEnded || snapshot.phase == .completed,
              let taskID = snapshot.task?.id else { return nil }
        return history.first { $0.task?.id == taskID && $0.status == .completed }
    }

    override init() {
        let stateStore = StateStore()
        let historyStore = SessionHistoryStore()
        let notificationService = NotificationService()
        let exportService = ExportService()

        self.stateStore = stateStore
        self.historyStore = historyStore
        self.notificationService = notificationService
        self.exportService = exportService
        let config = stateStore.loadConfig()
        self.config = config
        let history = historyStore.loadHistory()
        let onboardingStore = OnboardingStore(baseDirectory: stateStore.baseDirectory)
        self.onboardingStore = onboardingStore
        self.onboardingProgress = onboardingStore.load(isNewInstall: !config.onboardingCompleted && history.isEmpty)
        self.isOnboarding = !config.onboardingCompleted
        self.history = history
        self.timerEngine = TimerEngine(
            stateStore: stateStore,
            historyStore: historyStore,
            notificationService: notificationService
        )
        self.snapshot = timerEngine.snapshot
        self.blocker = AppBlocker(notificationService: notificationService)

        super.init()
        do { try onboardingStore.save(onboardingProgress) }
        catch { FocusLockLog.debug("Could not save local onboarding progress: \(error.localizedDescription)") }

        notificationService.breakSuggestion = { [weak self] cycle, minutes in
            guard let self else { return nil }
            return self.ensureBreakPick(
                sessionStartedAt: self.timerEngine.snapshot.sessionStartedAt,
                cycle: cycle,
                breakMinutes: minutes
            )
        }
        notificationService.isLongBreak = { [weak self] cycle in
            self?.config.longBreak.isLongBreak(afterCycle: cycle) ?? false
        }
        notificationService.appPlaysTimerEndSound = { [weak self] breakEnded in
            guard let self else { return false }
            return (breakEnded ? self.config.breakEndSound : self.config.timerEndSound) != .off
        }

        self.timerEngine.onChange = { [weak self] snapshot in
            Task { @MainActor in
                self?.apply(snapshot)
            }
        }

        self.blocker.delegate = self
        self.blocker.onInterception = { [weak self] app in
            Task { @MainActor in
                self?.recordInterception(key: app.bundleId, reach: (app.bundleId, app.name, .app))
            }
        }

        websiteGuard.onBlocked = { [weak self] visit in
            // The guarded site's own name, so m.youtube.com and youtube.com
            // add up as the one thing that was reached for.
            self?.recordInterception(key: Self.activityKey(for: visit.site), reach: (visit.site.host, visit.site.host, .site))
            self?.notificationService.notice(
                title: "\(visit.site.host) is guarded",
                body: "Quietwhile swapped the page out in \(visit.browser.displayName)."
            )
        }
        websiteGuard.onPermissionDenied = { [weak self] browser in
            self?.browserPermissionProblem = browser
            self?.permissions.refresh(browser)
        }
        permissions.onBrowserGranted = { [weak self] browser in
            guard let self else { return }
            if self.browserPermissionProblem == browser {
                self.browserPermissionProblem = nil
            }
            self.websiteGuard.resetPermissionMemory()
        }

        hotkeys.onAction = { [weak self] action in
            self?.perform(action)
        }

        configureOverlayHandlers()
        configureBreakEndedHandlers()
        notchIsland.onAction = { [weak self] id in
            self?.handleNotchAction(id)
        }
        configureAutoResumeHandlers()
        configurePinnedHUDHandlers()
        reloadHistory()
    }

    private func configurePinnedHUDHandlers() {
        pinnedHUD.onEnd = { [weak self] in
            self?.requestStopSession()
        }
        pinnedHUD.onUnpin = { [weak self] in
            self?.updatePinnedHUD(enabled: false)
            self?.notificationService.notice(
                title: "HUD unpinned",
                body: "Pin it again from Quietwhile in the menu bar, or in Settings.",
                sound: false
            )
        }
        pinnedHUD.onSettingsChange = { [weak self] mutate in
            self?.updateHUD(mutate)
        }
        pinnedHUD.apply(config.hud)
    }

    private func recordInterception(key: String, reach: (key: String, name: String, kind: Reach.Kind)) {
        blockedTodayCounts = activityStore.recordInterception(bundleId: key)
        updateOnboardingProgress { $0.recordInterception(at: Date()) }

        let entry = Reach(
            at: Date(),
            key: reach.key,
            name: reach.name,
            kind: reach.kind,
            blockStartedAt: snapshot.phase == .focus ? snapshot.sessionStartedAt : nil
        )
        reachLog.append(entry)
        reaches.append(entry)
    }

    private static func activityKey(for site: BlockedSite) -> String {
        "site:\(site.pattern)"
    }

    /// Re-reads the history file and everything derived from it. Every code
    /// path that can append an entry goes through here so the sidebar streak
    /// and week chart never lag behind the list.
    private func reloadHistory() {
        history = historyStore.loadHistory()
        if reaches.isEmpty { reaches = reachLog.load() }
        if focusTimeRecords.isEmpty { focusTimeRecords = focusTimeStore.load() }
        updateOnboardingProgress { $0.reconcile(history: history) }
        refreshDerivedStats()
    }

    /// Recomputes the week chart, streak, and today's block counts. Called
    /// whenever history changes rather than on every redraw, since each read
    /// walks the whole history file.
    private func refreshDerivedStats() {
        sessionStats = historyStore.stats()
        weeklyRhythm = historyStore.weeklyRhythm()
        weekSummary = historyStore.weekSummary()
        recentRhythm = historyStore.recentRhythm()
        recentSummary = historyStore.recentSummary()
        lastActiveDay = historyStore.lastActiveDay()
        streak = historyStore.focusStreak()
        blockedTodayCounts = activityStore.countsToday()
        publishWidgetSnapshot()
    }

    private func configureOverlayHandlers() {
        overlay.onBackToFocus = { [weak self] in
            self?.overlay.dismiss()
            self?.returnToLastAllowedApp()
        }
        overlay.onAllow = { [weak self] in
            self?.allowInterceptedAppTemporarily()
        }
        overlay.onEndSession = { [weak self] in
            guard let self else { return }
            self.overlay.dismiss()
            // Changing their mind here is the same as choosing "Back to work".
            if !self.requestStopSession() {
                self.returnToLastAllowedApp()
            }
        }
    }

    private func configureBreakEndedHandlers() {
        breakEndedOverlay.onStartFocus = { [weak self] in
            self?.startFocusFromBreakEndedOverlay()
        }
        breakEndedOverlay.onSnooze = { [weak self] in
            self?.snoozeBreakEndedOverlay()
        }
        breakEndedOverlay.onEndCycle = { [weak self] in
            self?.endCycleFromBreakEndedOverlay()
        }
    }

    private func configureAutoResumeHandlers() {
        autoResumeOverlay.onStartNow = { [weak self] in
            self?.autoResumeOverlay.dismiss()
            self?.startFocus()
        }
        autoResumeOverlay.onPostpone = { [weak self] in
            self?.postponeAutoResume()
        }
        autoResumeOverlay.onEndCycle = { [weak self] in
            self?.autoResumeOverlay.dismiss()
            self?.endCycleFromBreakEndedOverlay()
        }
    }

    func setup() {
        FocusLockLog.debug("MenuBarController setup called")
        guard !hasSetup else {
            FocusLockLog.debug("\(AppIdentity.name) menu bar status item already exists")
            return
        }

        hasSetup = true
        reopenObserver = NotificationCenter.default.addObserver(
            forName: .quietwhileShowMainWindow,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.openMainWindow()
            }
        }

        widgetCommandObserver = DarwinNotificationObserver(
            names: HotkeyAction.allCases.map { SharedContainer.commandNotificationPrefix + $0.rawValue }
        ) { [weak self] name in
            let raw = String(name.dropFirst(SharedContainer.commandNotificationPrefix.count))
            guard let action = HotkeyAction(rawValue: raw) else { return }
            Task { @MainActor in
                self?.perform(action)
            }
        }

        QuietwhileCommandCenter.shared.controller = self
        applyAppearance()
        setupMainMenu()
        setupStatusItem()
        // No permission is asked for here: the welcome guide and Settings do
        // that, after saying what each one is for.
        syncPresetFromConfig()
        registerHotkeys()
        startTicking()
        syncBlocker()
        syncWatchdog()
        showMainWindowAfterLaunch()
    }

    deinit {
        tickTimer?.invalidate()
        if let reopenObserver {
            NotificationCenter.default.removeObserver(reopenObserver)
        }
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        blocker.stop()
    }

    // MARK: - Quitting

    /// Whether macOS is logging out, restarting, or shutting down — the only
    /// quits a strict block lets through.
    private var isSystemQuit: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              event.eventClass == kCoreEventClass, event.eventID == kAEQuitApplication,
              let reason = event.attributeDescriptor(forKeyword: kAEQuitReason)?.enumCodeValue else {
            return false
        }
        return [kAELogOut, kAEReallyLogOut, kAEShowRestartDialog, kAERestart,
                kAEShowShutdownDialog, kAEShutDown].contains(reason)
    }

    func shouldAllowTermination() -> Bool {
        // Logging out, restarting and shutting down are never held up.
        guard !isSystemQuit else { return true }
        guard !isStrictLocked else {
            refuseStrict("Quietwhile can't quit during a strict block. It ends at \(phaseEndLabel), or use the emergency exit.")
            return false
        }
        guard isSessionActive, config.confirmBeforeEnding else { return true }

        let message = snapshot.phase == .focus
            ? "\(remainingLabel) left in this focus block. Quitting stops guarding, and the block is saved in History as abandoned."
            : "A session is running. Quitting ends it, and the next focus block won’t start."
        return confirmEnding(title: "Quit \(AppIdentity.name)?", message: message, confirm: "Quit", keep: "Keep Running")
    }

    /// Quitting mid-session ends it: stop guarding and record an interrupted
    /// focus block as abandoned before the process exits. A strict block is
    /// left on disk instead, so the relaunch picks it back up.
    func handleAppWillTerminate() {
        flushFocusTime()
        blocker.stop()
        websiteGuard.stop(waitUntilRestored: true)
        pinnedHUD.dismiss()
        hotkeys.unregisterAll()
        if !snapshot.isStrict {
            timerEngine.recordAbandonmentIfNeeded()
        }
    }

    // MARK: - Welcome guide

    var protectionAvailability: ProtectionAvailability {
        ProtectionAvailability(
            apps: activeBlockedApps.filter {
                NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.bundleId) != nil
            }.count,
            sites: activeBlockedSites.count,
            authorisedBrowsers: permissions.installedBrowsers.filter {
                permissions.state(for: $0) == .granted && browserPermissionProblem != $0
            }.count
        )
    }

    var offersFirstDistraction: Bool {
        onboardingProgress.cohortStartedAt != nil
            && onboardingProgress.firstBlockStartedAt == nil
            && !onboardingProgress.timerOnlyChosen
            && activeBlockedApps.isEmpty && activeBlockedSites.isEmpty
            && !isSessionActive
    }

    private func updateOnboardingProgress(_ update: (inout OnboardingProgress) -> Void) {
        var progress = onboardingProgress
        update(&progress)
        guard progress != onboardingProgress else { return }
        onboardingProgress = progress
        do { try onboardingStore.save(progress) }
        catch { FocusLockLog.debug("Could not save local onboarding progress: \(error.localizedDescription)") }
    }

    func chooseTimerOnly() {
        updateOnboardingProgress { $0.timerOnlyChosen = true }
    }

    func deferNotificationPrompt() {
        updateOnboardingProgress { $0.notificationsDeferred = true }
    }

    func chooseOnboardingBrowser(_ browser: SupportedBrowser) {
        updateOnboardingProgress { $0.preferredBrowserBundleID = browser.bundleIdentifier }
    }

    func dismissOnboarding() {
        updateOnboardingProgress {
            if $0.guideDismissedAt == nil { $0.guideDismissedAt = Date() }
        }
        closeOnboarding()
    }

    private func closeOnboarding() {
        isOnboarding = false
        settingsMessage = nil
        config.onboardingCompleted = true
        saveConfig()
        page = .focus
    }

    func showOnboarding() {
        guard !isSessionActive else { return }
        isOnboarding = true
        openMainWindow()
    }

    func finishOnboarding(startingFocus: Bool) {
        // Replaying the guide can follow a strict setting. Ask before closing
        // the summary, so Cancel keeps the user's place and choices.
        if startingFocus && nextBlockIsStrict && !confirmStrictStart() { return }
        updateOnboardingProgress {
            if $0.guideCompletedAt == nil { $0.guideCompletedAt = Date() }
        }
        closeOnboarding()
        if startingFocus {
            startFocus()
        }
    }

    // MARK: - Task and check-in

    func updateTask(_ update: (inout FocusTaskSettings) -> Void) {
        update(&config.task)
        saveConfig()
        publishWidgetSnapshot()
    }

    func saveCheckIn(outcome: CheckInOutcome, note: String) {
        guard let entry = checkInEntry, let taskID = entry.task?.id else { return }
        do {
            try historyStore.saveCheckIn(taskID: taskID, checkIn: SessionCheckIn(outcome: outcome, note: note))
            reloadHistory()
            var clearedGoal = false
            updateTask { clearedGoal = $0.clearCompletedGoal(matching: entry.task, outcome: outcome) }
            focusMessage = clearedGoal
                ? "Check-in saved. Goal cleared — set the next one when you're ready."
                : "Check-in saved."
        } catch {
            focusMessage = "Could not save your check-in: \(error.localizedDescription)"
        }
    }

    func copyRecap() {
        guard let recap = lastRecap, !recap.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(recap.text, forType: .string)
        focusMessage = "Recap copied."
    }

    // MARK: - Session control

    /// - Parameters:
    ///   - strict: forces strict on or off for this block; `nil` follows the
    ///     settings, and a run that was already strict stays strict.
    ///   - occurrence: the schedule window starting this block, if any.
    ///   - continuingFromBreak: cuts a running break short and starts the
    ///     run's next block, which is what skipping a break means.
    func startFocus(
        strict: Bool? = nil,
        occurrence: ScheduleOccurrence? = nil,
        minutes: Int? = nil,
        continuingFromBreak: Bool = false
    ) {
        let skippingBreak = continuingFromBreak && snapshot.phase == .break
        guard !isSessionActive || skippingBreak else { return }
        focusMessage = nil
        let continuing = snapshot.phase == .breakEnded || skippingBreak
        let cycle = continuing ? snapshot.currentCycle + 1 : 1
        if cycle == 1 {
            runStartedAt = Date()
            lastRecap = nil
        }
        let runIsStrict = continuing && snapshot.isStrict
        let isStrict = strict
            ?? (runIsStrict
                || (occurrence ?? activeScheduleOccurrence)?.schedule.strict == true
                || (nextBlockStrictChoice ?? config.strict.enabled))
        // The chip speaks for one block; the next one starts from Settings again.
        nextBlockStrictChoice = nil

        dismissBreakEndedPrompt()
        autoResumeOverlay.dismiss()
        autoResumeAnchor = nil
        strictEscape = nil
        lastEyeReminderAt = nil
        saveConfig()
        reloadHistory()
        timerEngine.startFocus(
            focusMinutes: minutes.map(AppConfig.normalizedFocusMinutes) ?? config.focusMinutes,
            breakMinutes: config.longBreak.breakMinutes(afterCycle: cycle, shortBreak: config.breakMinutes),
            blockedAppsCount: activeBlockedApps.count + activeBlockedSites.count,
            strictMode: isStrict,
            task: config.task.task,
            // Continuing a run keeps counting; anything else starts one.
            cycle: cycle
        )
        if let startedAt = timerEngine.snapshot.sessionStartedAt {
            updateOnboardingProgress {
                $0.recordStart(at: startedAt, minutes: timerEngine.snapshot.focusMinutes,
                               protection: protectionAvailability, history: history)
            }
        }
        reloadHistory()
        syncBlocker()
        syncPinnedHUD()
        syncWatchdog()
    }

    // MARK: - Asking first

    /// Start, from places that can't show what a strict block costs before
    /// you press: the menu, its ⌘N, the global shortcut, the menu bar. A
    /// strict block can't be taken back, so it asks first, with Cancel as the
    /// answer to a stray Return. Anything else just starts.
    func requestStartFocus() {
        guard !nextBlockIsStrict || confirmStrictStart() else { return }
        guard !isSessionActive || snapshot.phase == .breakEnded else { return }
        startFocus()
    }

    /// Asks before a strict block begins from a route that couldn't show its
    /// cost first. Cancel is the answer to a stray Return.
    private func confirmStrictStart() -> Bool {
        let ends = Date().addingTimeInterval(TimeInterval(config.focusMinutes * 60))
        let wait = config.strict.escapeWaitSeconds
        let waitLabel = wait >= 60 ? "\(wait / 60) min\(wait % 60 == 0 ? "" : " \(wait % 60) s")" : "\(wait) s"
        return ConfirmationAlert.ask(
            title: "Start a strict block?",
            message: "It can’t be ended, skipped or quit until \(Self.clockLabel(ends)). The emergency exit asks you to type a sentence, then waits \(waitLabel).",
            confirm: "Start Strict Block",
            keep: "Cancel"
        ).confirmed && nextBlockIsStrict
    }

    private static func clockLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// What someone meant when they pressed End, from anywhere a person can
    /// press it. Shortcuts and the Focus filter call `stopSession` directly:
    /// automation should not sit waiting on a dialog nobody is looking at.
    /// - Returns: whether the session was ended.
    @discardableResult
    func requestStopSession() -> Bool {
        // A strict block refuses on its own terms, and a finished break has
        // nothing left to lose.
        guard isSessionActive, !isStrictLocked, config.confirmBeforeEnding else {
            stopSession()
            return true
        }

        let phase = snapshot.phase
        let message = phase == .focus
            ? "\(remainingLabel) left in this focus block. Guarding stops, and the block is saved in History as cancelled."
            : "You’re on a break. The next focus block won’t start."
        guard confirmEnding(title: "End this session?", message: message, confirm: "End Session", keep: "Keep Going"),
              snapshot.phase == phase
        else {
            return false
        }
        stopSession()
        return true
    }

    func requestSkipPhase() {
        // From a break, skipping starts the next block; a strict one asks
        // first, the same as every other way of starting one.
        if snapshot.phase == .break || snapshot.phase == .breakEnded {
            let phase = snapshot.phase
            guard !nextBlockIsStrict || confirmStrictStart(), snapshot.phase == phase else { return }
            skipPhase()
            return
        }
        // Only cutting a focus block short gives something up.
        guard snapshot.phase == .focus, !isStrictLocked, config.confirmBeforeEnding else {
            skipPhase()
            return
        }
        guard confirmEnding(
            title: "Skip to the break?",
            message: "\(remainingLabel) left in this focus block. Guarding stops until the next block starts.",
            confirm: "Skip to Break",
            keep: "Keep Focusing"
        ), snapshot.phase == .focus else {
            return
        }
        skipPhase()
    }

    func requestRemoveSchedule(_ schedule: FocusSchedule) {
        let answer = ConfirmationAlert.ask(
            title: "Delete “\(schedule.name)”?",
            message: "Its days, times and settings will be gone. This can’t be undone.",
            confirm: "Delete Schedule",
            keep: "Cancel"
        )
        if answer.confirmed {
            removeSchedule(schedule)
        }
    }

    /// Confirmations go after a few seconds; longer messages, which are
    /// usually errors or instructions, stay long enough to read.
    private func scheduleSettingsMessageClear() {
        settingsMessageClearTask?.cancel()
        guard let message = settingsMessage else { return }
        let seconds: Double = message.count > 40 ? 10 : 4
        settingsMessageClearTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self, self.settingsMessage == message else { return }
            self.settingsMessage = nil
        }
    }

    func updateConfirmBeforeEnding(_ enabled: Bool) {
        config.confirmBeforeEnding = enabled
        saveConfig()
    }

    /// Asks, and remembers a ticked "Don't ask again" if the answer was yes.
    private func confirmEnding(title: String, message: String, confirm: String, keep: String) -> Bool {
        let answer = ConfirmationAlert.ask(title: title, message: message, confirm: confirm, keep: keep, suppressible: true)
        if answer.confirmed, answer.suppress {
            updateConfirmBeforeEnding(false)
        }
        return answer.confirmed
    }

    private var remainingLabel: String {
        let minutes = Int((Double(snapshot.remainingSeconds) / 60).rounded())
        if minutes < 1 { return "Less than a minute is" }
        return minutes == 1 ? "1 minute is" : "\(minutes) minutes are"
    }

    func stopSession() {
        guard !isStrictLocked else {
            refuseStrict("This is a strict block. It ends at \(phaseEndLabel), or use the emergency exit.")
            return
        }
        endSession()
    }

    /// Ends whatever is running without asking the strict lock. Only reached
    /// through `stopSession` or a completed emergency exit.
    private func endSession() {
        dismissCurrentScheduleOccurrence()
        dismissBreakEndedPrompt()
        autoResumeOverlay.dismiss()
        autoResumeAnchor = nil
        strictEscape = nil
        timerEngine.stopSession()
        reloadHistory()
        syncBlocker()
        syncPinnedHUD()
        syncWatchdog()
        finishRun()
    }

    /// Skip: focus goes to the break (refused in a strict block), a break goes
    /// straight to the next block.
    func skipPhase() {
        switch snapshot.phase {
        case .focus:
            guard !isStrictLocked else {
                refuseStrict("Skipping isn't available in a strict block.")
                return
            }
            timerEngine.skipFocus()
            reloadHistory()
        case .break:
            startFocus(continuingFromBreak: true)
        case .breakEnded:
            startFocus()
        default:
            break
        }
    }

    func perform(_ action: HotkeyAction) {
        switch action {
        case .start:
            if !isSessionActive {
                requestStartFocus()
            }
        case .stop:
            if isSessionActive || snapshot.phase == .breakEnded {
                requestStopSession()
            }
        case .skip:
            requestSkipPhase()
        case .extend:
            extendCurrentPhase()
        case .show:
            openMainWindow()
        }
    }

    private var phaseEndLabel: String {
        snapshot.phaseEndsAt.map(Self.shortTime) ?? "the end of the block"
    }

    private func refuseStrict(_ message: String) {
        NSSound.beep()
        focusMessage = message
        page = .focus
        openMainWindow()
    }

    // MARK: - Strict mode

    func beginEscape(typed: String) -> Bool {
        var escape = strictEscape ?? StrictEscape(waitSeconds: TimeInterval(config.strict.escapeWaitSeconds))
        guard escape.request(typed: typed, at: Date()) else { return false }
        strictEscape = escape
        return true
    }

    func cancelEscape() {
        strictEscape = nil
    }

    private func syncEscape(now: Date) {
        guard let escape = strictEscape else { return }
        guard isStrictLocked else {
            strictEscape = nil
            return
        }
        if escape.isReady(at: now) {
            FocusLockLog.debug("strict block ended through the emergency exit")
            endSession()
            focusMessage = "Strict block ended early. It's in your history as cancelled."
        } else {
            // Republish so the countdown in the sheet ticks.
            objectWillChange.send()
        }
    }

    func updateStrictMode(enabled: Bool) {
        guard !isStrictLocked else {
            refuseStrict("Strict mode can't be changed during a strict block.")
            return
        }
        config.strict.enabled = enabled
        saveConfig()
        syncWatchdog()
    }

    func updateEscapeWait(seconds: Int) {
        guard !isStrictLocked else { return }
        config.strict.escapeWaitSeconds = seconds
        saveConfig()
    }

    /// Armed only while a strict block runs; the agent itself stays installed
    /// while anything could start a strict block, and is removed otherwise.
    private func syncWatchdog() {
        let anyStrictSource = config.strict.enabled || config.schedules.contains { $0.isEnabled && $0.strict }
        if snapshot.isStrict && (snapshot.phase == .focus || snapshot.phase == .break) {
            watchdog.arm()
        } else {
            watchdog.disarm()
            if !anyStrictSource {
                watchdog.uninstall()
            }
        }
    }

    // MARK: - Schedules

    func addSchedule() {
        config.schedules.append(FocusSchedule(name: config.schedules.isEmpty ? "Work" : "Schedule \(config.schedules.count + 1)"))
        saveConfig()
        publishWidgetSnapshot()
    }

    func updateSchedule(_ schedule: FocusSchedule) {
        guard let index = config.schedules.firstIndex(where: { $0.id == schedule.id }) else { return }
        // A strict schedule running now cannot be loosened until it is over.
        if isStrictLocked, config.schedules[index].strict, !schedule.strict || !schedule.isEnabled,
           activeScheduleOccurrence?.schedule.id == schedule.id {
            refuseStrict("This schedule's strict block is running. Change it when the block ends.")
            return
        }
        config.schedules[index] = schedule
        saveConfig()
        syncWatchdog()
        publishWidgetSnapshot()
    }

    func removeSchedule(_ schedule: FocusSchedule) {
        if isStrictLocked, activeScheduleOccurrence?.schedule.id == schedule.id {
            refuseStrict("This schedule's strict block is running. Remove it when the block ends.")
            return
        }
        config.schedules.removeAll { $0.id == schedule.id }
        saveConfig()
        syncWatchdog()
        publishWidgetSnapshot()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            settingsMessage = "Could not change Open at Login: \(error.localizedDescription)"
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
        if SMAppService.mainApp.status == .requiresApproval {
            settingsMessage = "Approve Quietwhile in System Settings › General › Login Items."
        }
    }

    private var dismissedScheduleKeys: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: Self.dismissedSchedulesKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue.suffix(50)), forKey: Self.dismissedSchedulesKey) }
    }

    /// Stopping during a schedule window means "not today" for that window,
    /// not "start again in half a second".
    private func dismissCurrentScheduleOccurrence() {
        guard let occurrence = activeScheduleOccurrence else { return }
        dismissedScheduleKeys.insert(occurrence.key)
    }

    private var scheduleWantsNextBlock: Bool {
        guard let occurrence = activeScheduleOccurrence else { return false }
        return !dismissedScheduleKeys.contains(occurrence.key) && occurrence.contains(Date())
    }

    private func syncSchedules(now: Date) {
        let occurrence = ScheduleEvaluator.activeOccurrence(in: config.schedules, at: now)
        if occurrence != activeScheduleOccurrence {
            activeScheduleOccurrence = occurrence
        }
        guard let occurrence, !dismissedScheduleKeys.contains(occurrence.key) else { return }

        switch snapshot.phase {
        case .idle, .completed, .cancelled:
            FocusLockLog.debug("schedule \(occurrence.schedule.name) starting a block")
            let firstOfWindow = snapshot.sessionStartedAt.map { $0 < occurrence.start } ?? true
            let strict = occurrence.schedule.strict || config.strict.enabled
            startFocus(occurrence: occurrence)
            if firstOfWindow {
                notificationService.scheduleStarted(name: occurrence.schedule.name, strict: strict)
            }
        case .breakEnded:
            startFocus(occurrence: occurrence)
        case .focus, .break, .paused:
            break
        }
    }

    // MARK: - Durations and guarding

    func selectPreset(_ newPreset: FocusPreset) {
        preset = newPreset

        guard let durations = newPreset.durations else {
            return
        }

        config.focusMinutes = durations.focus
        config.breakMinutes = durations.rest
        saveConfig()
        publishWidgetSnapshot()
    }

    func updateFocusMinutes(_ minutes: Int) {
        config.focusMinutes = AppConfig.normalizedFocusMinutes(minutes)
        preset = matchingPreset() ?? .custom
        saveConfig()
        publishWidgetSnapshot()
    }

    func updateBreakMinutes(_ minutes: Int) {
        config.breakMinutes = min(60, max(0, minutes))
        preset = matchingPreset() ?? .custom
        saveConfig()
        publishWidgetSnapshot()
    }

    func updateBlockerMode(_ blockerMode: BlockerMode) {
        guard !isStrictLocked else {
            refuseStrict("Guarding behaviour can't change during a strict block.")
            return
        }
        config.blockerMode = blockerMode
        saveConfig()
        syncBlocker()
    }

    func updateBreakEndBehavior(_ behavior: BreakEndBehavior) {
        config.breakEndBehavior = behavior
        saveConfig()
        syncAutoResume()
    }

    func updateAutoResumeGrace(minutes: Int) {
        config.autoResume = AutoResumePlanner(
            graceMinutes: minutes,
            countdownSeconds: config.autoResume.countdownSeconds
        )
        saveConfig()
        syncAutoResume()
    }

    func updateAutoResumeCountdown(seconds: Int) {
        config.autoResume = AutoResumePlanner(
            graceMinutes: config.autoResume.graceMinutes,
            countdownSeconds: seconds
        )
        saveConfig()
        syncAutoResume()
    }

    func updateAppearance(_ appearance: AppearancePreference) {
        config.appearance = appearance
        saveConfig()
        applyAppearance()
    }

    /// Set on the application, so every window — the main one, the guard
    /// screen, the HUD — follows without being told separately. The popover
    /// is the exception: it takes the menu bar's look unless told, so it is
    /// told too.
    private func applyAppearance() {
        switch config.appearance {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
        popover.appearance = NSApp.appearance
    }

    func updateTimerEndSound(_ sound: TimerEndSound) {
        config.timerEndSound = sound
        saveConfig()
        // Picking one is the only way to know what it sounds like.
        play(sound)
    }

    func updateBreakEndSound(_ sound: TimerEndSound) {
        config.breakEndSound = sound
        saveConfig()
        play(sound)
    }

    /// The sound for a timer that ran out of `phase`.
    private func playTimerEndSound(ranOutOf phase: SessionPhase) {
        play(phase == .break ? config.breakEndSound : config.timerEndSound)
    }

    private func play(_ sound: TimerEndSound) {
        guard let name = sound.systemSoundName else { return }
        let played = NSSound(named: NSSound.Name(name))?.play() ?? false
        FocusLockLog.debug("timer-end sound \(name) played: \(played)")
    }

    func updatePinnedHUD(enabled: Bool) {
        config.pinnedHUDEnabled = enabled
        saveConfig()
        syncPinnedHUD()
    }

    func updateHUD(_ change: (inout HUDSettings) -> Void) {
        change(&config.hud)
        saveConfig()
        pinnedHUD.apply(config.hud)
    }

    func updateBreakSuggestions(_ update: (inout BreakSuggestionSettings) -> Void) {
        update(&config.breakSuggestions)
        saveConfig()
    }

    /// Per-app behaviour override. `nil` puts the app back on the global
    /// default from Settings.
    func setBlockedApp(_ app: BlockedApp, behavior: BlockerMode?) {
        guard let index = config.blockedApps.firstIndex(where: { $0.bundleId == app.bundleId }) else {
            return
        }
        guard !isStrictLocked else {
            refuseStrict("Guarding behaviour can't change during a strict block.")
            return
        }

        config.blockedApps[index].behavior = behavior
        saveConfig()
        syncBlocker()
    }

    func setBlockedApp(_ app: BlockedApp, enabled: Bool) {
        guard let index = config.blockedApps.firstIndex(where: { $0.bundleId == app.bundleId }) else {
            return
        }
        guard enabled || !isStrictLocked else {
            refuseStrict("Guarded apps can't be switched off during a strict block.")
            return
        }

        config.blockedApps[index].isEnabled = enabled
        saveConfig()
        syncBlocker()
    }

    func addBlockedAppFromPanel() {
        FocusLockLog.debug("app picker opened")
        let panel = NSOpenPanel()
        panel.title = "Choose an app to guard"
        panel.message = "Select an application from your Mac."
        panel.prompt = "Add"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true
        panel.treatsFilePackagesAsDirectories = false
        panel.allowedContentTypes = [.applicationBundle]

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        FocusLockLog.debug("selected app URL: \(url.path)")
        addBlockedApp(at: url)
    }

    func addBlockedApp(at url: URL) {
        let app: BlockedApp

        switch AppBundleMetadataExtractor.extractBlockedApp(from: url) {
        case .success(let extractedApp):
            app = extractedApp
            FocusLockLog.debug("extracted bundle identifier: \(app.bundleId)")
        case .failure(let error):
            settingsMessage = error.localizedDescription
            FocusLockLog.debug("rejected app reason: \(error.localizedDescription)")
            return
        }

        switch AppBlocker.validate(app, existingApps: config.blockedApps) {
        case .success:
            config.blockedApps.append(app)
            config.blockedApps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            settingsMessage = "Added \(app.name)."
            saveConfig()
            syncBlocker()
            FocusLockLog.debug("app added successfully: \(app.name) (\(app.bundleId))")
        case .failure(let error):
            settingsMessage = error.localizedDescription
            FocusLockLog.debug("rejected app reason: \(error.localizedDescription)")
        }
    }

    func removeBlockedApp(_ app: BlockedApp) {
        guard !isStrictLocked else {
            refuseStrict("Guarded apps can't be removed during a strict block.")
            return
        }
        config.blockedApps.removeAll { $0.bundleId == app.bundleId }
        settingsMessage = "Removed \(app.name)."
        saveConfig()
        syncBlocker()
    }

    /// Returns false if the text does not name a website.
    @discardableResult
    func addBlockedSite(_ input: String) -> Bool {
        guard let site = BlockedSite(input: input) else {
            settingsMessage = "“\(input)” doesn't look like a website. Try something like youtube.com."
            return false
        }
        guard !config.blockedSites.contains(where: { $0.pattern == site.pattern }) else {
            settingsMessage = "\(site.pattern) is already on the list."
            return false
        }
        config.blockedSites.append(site)
        config.blockedSites.sort { $0.pattern < $1.pattern }
        settingsMessage = "Added \(site.pattern)."
        saveConfig()
        syncBlocker()
        return true
    }

    func setBlockedSite(_ site: BlockedSite, enabled: Bool) {
        guard let index = config.blockedSites.firstIndex(where: { $0.id == site.id }) else { return }
        guard enabled || !isStrictLocked else {
            refuseStrict("Guarded websites can't be switched off during a strict block.")
            return
        }
        config.blockedSites[index].isEnabled = enabled
        saveConfig()
        syncBlocker()
    }

    func removeBlockedSite(_ site: BlockedSite) {
        guard !isStrictLocked else {
            refuseStrict("Guarded websites can't be removed during a strict block.")
            return
        }
        config.blockedSites.removeAll { $0.id == site.id }
        settingsMessage = "Removed \(site.pattern)."
        saveConfig()
        syncBlocker()
    }

    /// After the user has changed the Automation setting, try the browser again.
    func retryBrowserPermission() {
        if let browser = browserPermissionProblem {
            permissions.refresh(browser)
        }
        browserPermissionProblem = nil
        websiteGuard.resetPermissionMemory()
    }

    func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Hotkeys

    func updateHotkeys(_ update: (inout HotkeySettings) -> Void) {
        update(&config.hotkeys)
        saveConfig()
        registerHotkeys()
    }

    /// Lets the shortcut recorder capture a combo that is currently
    /// registered, which would otherwise fire instead of being recorded.
    func suspendHotkeys(_ suspended: Bool) {
        if suspended {
            hotkeys.unregisterAll()
        } else {
            registerHotkeys()
        }
    }

    private func registerHotkeys() {
        hotkeyFailures = hotkeys.register(config.hotkeys)
        setupMainMenu()
    }

    // MARK: - Windows

    func openMainWindow() {
        updateOnboardingProgress { $0.recordVisit(at: Date()) }
        popover.performClose(nil)
        mainWindow = presentWindow(
            existingWindow: mainWindow,
            title: AppIdentity.name,
            // The LockIn-era key, so the window opens where you left it.
            frameAutosaveName: "LockIn",
            size: NSSize(width: 980, height: 720),
            rootView: MainWindowView().environmentObject(self)
        )
        // SwiftUI installs its Settings-scene menu after launch. Restore our
        // app commands once the actual main window has been presented.
        setupMainMenu()
    }

    func openAbout() {
        if let aboutWindow {
            show(aboutWindow, activating: true)
            return
        }

        let hosting = NSHostingView(rootView: AboutView().environmentObject(self))
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "About \(AppIdentity.name)"
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = FLColor.canvas
        window.isMovableByWindowBackground = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.contentView = hosting
        window.center()
        aboutWindow = window
        show(window, activating: true)
    }

    func revealDataFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([stateStore.baseDirectory])
    }

    /// These destinations are panes of the one window, so "open" means select
    /// the pane and bring that window forward.
    func openSettings() {
        FocusLockLog.debug("settings pane opened")
        page = .settings
        openMainWindow()
    }

    func openHistory() {
        FocusLockLog.debug("history pane opened")
        reloadHistory()
        page = .history
        openMainWindow()
    }

    func openAnalytics() {
        FocusLockLog.debug("analytics pane opened")
        reloadHistory()
        page = .analytics
        openMainWindow()
    }

    func exportCSVFromPanel() {
        exportHistoryFromPanel(kind: .csv)
    }

    func exportJSONFromPanel() {
        exportHistoryFromPanel(kind: .json)
    }

    func stats() -> SessionStats {
        historyStore.stats()
    }

    func quit() {
        // The app delegate asks `shouldAllowTermination`; asking here as well
        // would put the same question twice.
        NSApp.terminate(nil)
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        updateOnboardingProgress { $0.recordVisit(at: Date()) }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover()
        }
    }

    private func apply(_ newSnapshot: TimerSnapshot) {
        let previousPhase = snapshot.phase
        if previousPhase == .focus {
            updateOnboardingProgress { $0.updateProtection(protectionAvailability) }
        }
        snapshot = newSnapshot

        // History only changes when the phase does; re-reading the file every
        // tick would be wasteful.
        if previousPhase != newSnapshot.phase {
            if previousPhase == .focus {
                flushFocusTime()
            }
            reloadHistory()
            syncWatchdog()
            if newSnapshot.phase == .completed {
                finishRun()
            }
        }

        if newSnapshot.phase == .break {
            // Also covers a relaunch in the middle of a break.
            ensureBreakPick(
                sessionStartedAt: newSnapshot.sessionStartedAt,
                cycle: newSnapshot.currentCycle,
                breakMinutes: newSnapshot.breakMinutes
            )
        }

        updateStatusItem()
        syncBlocker()
        syncPinnedHUD()
        if let ranOutFrom = timerRanOutFrom, previousPhase != newSnapshot.phase {
            timerRanOutFrom = nil
            presentTimerRanOut(from: ranOutFrom)
        }
        handleBreakEndedTransition(from: previousPhase, to: newSnapshot.phase)
        syncAutoResume()

        if overlay.isShowing {
            overlay.updateCountdown(snapshot.formattedRemaining)
        }
    }

    /// A run is over: work out what it added up to, for the recap card.
    private func finishRun() {
        guard let runStartedAt else { return }
        self.runStartedAt = nil
        let recap = RunRecap.make(from: history, since: runStartedAt)
        guard !recap.isEmpty else { return }
        lastRecap = recap
    }

    // MARK: - Widget

    private func publishWidgetSnapshot() {
        let next = ScheduleEvaluator.nextOccurrence(in: config.schedules, after: Date())
        let widget = WidgetSnapshot(
            phase: snapshot.phase,
            phaseEndsAt: isSessionActive ? snapshot.phaseEndsAt : nil,
            focusMinutes: isSessionActive ? snapshot.focusMinutes : config.focusMinutes,
            breakMinutes: isSessionActive ? snapshot.breakMinutes : config.breakMinutes,
            goal: currentTask.goal,
            isStrict: snapshot.isStrict && isSessionActive,
            focusMinutesToday: sessionStats.focusMinutesToday,
            sessionsToday: sessionStats.sessionsCompletedToday,
            streak: streak,
            weekMinutes: weeklyRhythm.map(\.minutes),
            nextScheduleName: next?.schedule.name,
            nextScheduleStart: next?.start,
            updatedAt: lastWidgetSnapshot?.updatedAt ?? Date()
        )
        guard widget != lastWidgetSnapshot else { return }
        var stamped = widget
        stamped.updatedAt = Date()
        lastWidgetSnapshot = stamped
        if SharedContainer.save(stamped) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// The HUD is only on screen while a session is running and the preference
    /// is on, so an idle Quietwhile leaves no residue over your work.
    private func syncPinnedHUD() {
        guard config.pinnedHUDEnabled, isSessionActive else {
            pinnedHUD.dismiss()
            return
        }

        pinnedHUD.apply(config.hud)
        pinnedHUD.show()
        pinnedHUD.update(
            countdown: snapshot.formattedRemaining,
            phaseLabel: hudPhaseLabel,
            goal: hudGoal,
            progress: phaseProgress,
            canEnd: !isStrictLocked,
            tone: hudTone
        )
    }

    private var hudPhaseLabel: String {
        switch snapshot.phase {
        case .break:
            return "Break"
        default:
            return snapshot.isStrict ? "Focus · Strict" : "Focus"
        }
    }

    /// Your goal during focus; during a break, what to do with it.
    private var hudGoal: String? {
        if snapshot.phase == .break, let suggestion = breakSuggestion {
            return suggestion.title
        }
        let goal = snapshot.task?.goal ?? ""
        return goal.isEmpty ? nil : goal
    }

    private var hudTone: HUDTone {
        if snapshot.remainingSeconds <= 60 { return .finalMinute }
        return snapshot.phase == .break ? .rest : .focus
    }

    var guardedSummaryLine: String {
        if snapshot.phase == .break, let suggestion = breakSuggestion {
            return suggestion.title
        }
        let names = activeBlockedApps.map(\.name) + activeBlockedSites.map(\.host)
        guard !names.isEmpty else {
            return "Nothing guarded"
        }

        let shown = names.prefix(3).joined(separator: ", ")
        let extra = names.count - min(3, names.count)
        return extra > 0 ? "\(shown) +\(extra)" : shown
    }

    private func setupStatusItem() {
        guard statusItem == nil else {
            FocusLockLog.debug("\(AppIdentity.name) menu bar status item already exists")
            return
        }

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = statusItem
        // Persist the item's slot and keep it forced-visible so it is not
        // silently dropped when the menu bar is crowded across launches.
        statusItem.autosaveName = "LockInStatusItem"
        statusItem.isVisible = true
        statusItem.behavior = []
        FocusLockLog.debug("NSStatusItem created")

        popover.behavior = .transient
        popover.delegate = self
        // The popover takes the size its content asks for, which changes as a
        // session starts and ends.
        let popoverContent = NSHostingController(
            rootView: MenuBarPopoverView()
                .environmentObject(self)
        )
        popoverContent.sizingOptions = .preferredContentSize
        popover.contentViewController = popoverContent

        if let button = statusItem.button {
            FocusLockLog.debug("Status item button exists")
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = AppIdentity.name
            assignIdleIcon(to: button)
        } else {
            FocusLockLog.debug("Status item button missing")
        }

        updateStatusItem()
    }

    private func updateStatusItem() {
        guard let button = statusItem?.button else {
            FocusLockLog.debug("Status item button missing")
            return
        }

        updateTitleForActiveSession(countdown: statusCountdownTitle)
        button.toolTip = statusTooltip
    }

    private var statusCountdownTitle: String? {
        guard snapshot.phase == .focus || snapshot.phase == .break else {
            return nil
        }
        return snapshot.formattedRemaining
    }

    func updateTitleForActiveSession(countdown: String?) {
        guard let button = statusItem?.button else {
            FocusLockLog.debug("Status item button missing")
            return
        }

        if let countdown {
            button.image = nil
            button.title = countdown
        } else {
            button.title = ""
            assignIdleIcon(to: button)
        }
    }

    private func assignIdleIcon(to button: NSStatusBarButton) {
        let image = NSImage(
            systemSymbolName: "timer",
            accessibilityDescription: AppIdentity.name
        ) ?? NSImage(systemSymbolName: "target", accessibilityDescription: AppIdentity.name)

        if let image {
            image.isTemplate = true
            button.image = image
            FocusLockLog.debug("Icon assigned")
        } else {
            button.image = nil
            button.title = "LI"
            FocusLockLog.debug("Icon assignment failed; using LI fallback")
        }
    }

    private var statusTooltip: String {
        switch snapshot.phase {
        case .focus:
            return "\(AppIdentity.name): \(snapshot.formattedRemaining) focus remaining\(snapshot.isStrict ? " (strict)" : "")"
        case .break:
            return "\(AppIdentity.name): \(snapshot.formattedRemaining) break remaining"
        default:
            return AppIdentity.name
        }
    }

    private func showPopover() {
        guard let button = statusItem?.button else {
            openSettings()
            return
        }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        FocusLockLog.debug("popover opened")
    }

    private func showMainWindowAfterLaunch() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            Task { @MainActor in
                self?.openMainWindow()
            }
        }
    }

    private func startTicking() {
        tickTimer?.invalidate()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick(now: Date = Date()) {
        let phaseBeforeTick = timerEngine.snapshot.phase
        timerEngine.refresh()
        if TimerEndSound.timerRanOut(from: phaseBeforeTick, to: timerEngine.snapshot.phase) {
            playTimerEndSound(ranOutOf: phaseBeforeTick)
            pinnedHUD.pulse()
            // The engine's change reaches `apply` on the next pass, so the
            // island is told there, once the new phase is in place.
            timerRanOutFrom = phaseBeforeTick
        }
        syncFinalMinute()
        syncEscape(now: now)

        if now.timeIntervalSince(lastScheduleCheck) >= 5 {
            lastScheduleCheck = now
            syncSchedules(now: now)
        }

        if snapshot.phase == .focus, now.timeIntervalSince(lastWebsiteCheck) >= 1 {
            lastWebsiteCheck = now
            checkFrontmostBrowser()
        }

        syncEyeReminder(now: now)
        sampleFocusTime(now: now)
    }

    /// Reading a tab from a browser that has never been asked would make
    /// macOS put up its dialog mid-block with no explanation. Such a browser
    /// is flagged for the Blocked page instead, where the request is explained.
    private func checkFrontmostBrowser() {
        let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        guard websiteGuard.isActive, let browser = frontmost.flatMap(SupportedBrowser.init(rawValue:)) else {
            return
        }

        switch permissions.browsers[browser] {
        case .granted:
            websiteGuard.check(frontmostBundleIdentifier: frontmost)
        case .notAsked, .denied:
            guard browserPermissionProblem != browser else { return }
            browserPermissionProblem = browser
            if unreadableBrowsersNoticed.insert(browser).inserted {
                notificationService.notice(
                    title: "Websites aren’t guarded in \(browser.displayName) yet",
                    body: "Open Quietwhile › Blocked to allow it."
                )
            }
        case nil:
            // Not looked up yet; the answer arrives before the next tick or two.
            permissions.refresh(browser)
        }
    }

    /// 20-20-20 inside long blocks: every 20 minutes of focus, a quiet nudge.
    /// The last few minutes before a break are skipped — the break is coming.
    private func syncEyeReminder(now: Date) {
        guard
            config.breakSuggestions.eyeReminderDuringFocus,
            snapshot.phase == .focus,
            let startedAt = snapshot.sessionStartedAt,
            snapshot.remainingSeconds > 180
        else {
            return
        }
        let anchor = lastEyeReminderAt ?? startedAt
        guard now.timeIntervalSince(anchor) >= BreakSuggestions.eyeReminderInterval else { return }
        lastEyeReminderAt = now
        notificationService.eyeReminder()
    }

    private func syncBlocker() {
        if snapshot.phase == .focus {
            updateOnboardingProgress { $0.updateProtection(protectionAvailability) }
        }
        guard AppBlocker.shouldRun(for: snapshot.phase) else {
            if blockerRunning {
                blocker.stop()
                blockerRunning = false
            }
            websiteGuard.stop()
            overlay.dismiss()
            return
        }

        if blockerRunning {
            blocker.update(blockedApps: config.blockedApps, blockerMode: config.blockerMode)
        } else {
            blocker.start(blockedApps: config.blockedApps, blockerMode: config.blockerMode)
            blockerRunning = true
        }
        websiteGuard.update(sites: config.blockedSites, endsAt: snapshot.phaseEndsAt)
    }

    private func handleBreakEndedTransition(from previousPhase: SessionPhase, to newPhase: SessionPhase) {
        guard newPhase == .breakEnded, previousPhase != .breakEnded else {
            return
        }

        // Inside a schedule window the next block is the schedule's call.
        if scheduleWantsNextBlock {
            startFocus()
            return
        }

        switch config.breakEndBehavior {
        case .startImmediately:
            startFocus()
        case .ask, .autopilot:
            // Autopilot still asks first — it only takes the screen once the
            // grace period has gone by with no answer.
            autoResumeAnchor = snapshot.breakEndedAt
            showBreakEndedPrompt()
        }
    }

    /// Runs on every tick while a break is over and unanswered. Waits out the
    /// grace period, then puts the takeover up and lets it count down.
    private func syncAutoResume(now: Date = Date()) {
        guard
            config.breakEndBehavior == .autopilot,
            snapshot.phase == .breakEnded,
            let breakEndedAt = snapshot.breakEndedAt
        else {
            autoResumeOverlay.dismiss()
            return
        }

        let anchor = autoResumeAnchor ?? breakEndedAt
        autoResumeAnchor = anchor

        let awayMinutes = Int(max(0, now.timeIntervalSince(breakEndedAt)) / 60)

        switch config.autoResume.stage(since: anchor, now: now) {
        case .waiting:
            autoResumeOverlay.dismiss()
        case .countdown(let remaining):
            let progress = config.autoResume.countdownProgress(remainingSeconds: remaining)

            if autoResumeOverlay.isShowing {
                autoResumeOverlay.update(
                    countdown: Self.formatCountdown(remaining),
                    progress: progress,
                    awayMinutes: awayMinutes
                )
            } else {
                dismissBreakEndedPrompt()
                autoResumeOverlay.show(
                    countdown: Self.formatCountdown(remaining),
                    progress: progress,
                    awayMinutes: awayMinutes,
                    focusMinutes: config.focusMinutes,
                    postponeMinutes: config.autoResume.graceMinutes
                )
            }
        case .start:
            // Nobody has touched the machine in a long while: it is asleep, or
            // the desk is empty. Starting a block now would log focus that never
            // happened, so hold the takeover and hand out a fresh countdown when
            // they come back to it.
            guard systemIdleSeconds < Self.unattendedIdleSeconds else {
                autoResumeAnchor = now.addingTimeInterval(-config.autoResume.graceSeconds)
                FocusLockLog.debug("autopilot held: no input for \(Int(systemIdleSeconds))s")
                return
            }

            autoResumeOverlay.dismiss()
            FocusLockLog.debug("autopilot started the next focus block")
            startFocus()
        }
    }

    /// Zero keyboard or mouse input for this long means the user is not there.
    /// Long enough that sitting through a video without touching anything does
    /// not read as absence.
    private static let unattendedIdleSeconds: TimeInterval = 25 * 60

    private var systemIdleSeconds: TimeInterval {
        guard let anyInputEvent = CGEventType(rawValue: ~0) else {
            return 0
        }

        return CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: anyInputEvent)
    }

    /// "Not yet" restarts the wait rather than cancelling it — the whole point
    /// is that the nudge comes back.
    private func postponeAutoResume() {
        autoResumeOverlay.dismiss()
        autoResumeAnchor = Date()
        showBreakEndedPrompt()
    }

    private static func formatCountdown(_ seconds: TimeInterval) -> String {
        let whole = max(0, Int(seconds.rounded(.up)))
        return String(format: "%02d:%02d", whole / 60, whole % 60)
    }

    static func shortTime(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private func saveConfig() {
        do {
            try stateStore.saveConfig(config)
        } catch {
            settingsMessage = "Could not save settings: \(error.localizedDescription)"
        }
    }

    private func syncPresetFromConfig() {
        preset = matchingPreset() ?? .custom
    }

    private func matchingPreset() -> FocusPreset? {
        FocusPreset.allCases.first { preset in
            guard let durations = preset.durations else {
                return false
            }
            return durations.focus == config.focusMinutes && durations.rest == config.breakMinutes
        }
    }

    private enum ExportKind {
        case csv
        case json

        var defaultName: String {
            switch self {
            case .csv:
                return "quietwhile-history.csv"
            case .json:
                return "quietwhile-history.json"
            }
        }

        var contentTypes: [UTType] {
            switch self {
            case .csv:
                return [.commaSeparatedText]
            case .json:
                return [.json]
            }
        }
    }

    private func exportHistoryFromPanel(kind: ExportKind) {
        reloadHistory()

        let panel = NSSavePanel()
        panel.title = "Export \(AppIdentity.name) history"
        panel.nameFieldStringValue = kind.defaultName
        panel.allowedContentTypes = kind.contentTypes

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            switch kind {
            case .csv:
                try exportService.exportCSV(history, to: url)
            case .json:
                try exportService.exportJSON(history, to: url)
            }
            exportMessage = "Exported \(url.lastPathComponent)."
        } catch {
            exportMessage = "Export failed. Please choose another location."
        }
    }

    private func presentWindow<Content: View>(
        existingWindow: NSWindow?,
        title: String,
        frameAutosaveName: String,
        size: NSSize,
        rootView: Content,
        activating: Bool = true
    ) -> NSWindow {
        if let existingWindow {
            show(existingWindow, activating: activating)
            return existingWindow
        }

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.minSize = NSSize(width: min(size.width, 860), height: min(size.height, 600))
        window.isReleasedWhenClosed = false

        // The canvas runs edge to edge under the titlebar, with the window's
        // name and tabs drawn on it, as a unified toolbar would; a stock
        // titlebar would cut a band across the top.
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = FLColor.canvas
        window.isMovableByWindowBackground = true

        window.contentView = NSHostingView(rootView: rootView)
        window.center()
        window.setFrameAutosaveName(frameAutosaveName)
        show(window, activating: activating)
        // AppKit hands first responder to the first text field it finds — the
        // goal field — which opens the window with the goal selected, one
        // keystroke from being typed over.
        DispatchQueue.main.async {
            window.makeFirstResponder(nil)
        }
        return window
    }

    private func show(_ window: NSWindow, activating: Bool) {
        NSApp.setActivationPolicy(.regular)
        if activating {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.makeMain()
            NSApp.activate(ignoringOtherApps: true)
        } else {
            window.orderFrontRegardless()
        }
    }
}

extension MenuBarController: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        FocusLockLog.debug("popover closed")
    }
}

// MARK: - Main menu

extension MenuBarController: NSMenuItemValidation {
    private static let appName = AppIdentity.name

    func setupMainMenu() {
        let mainMenu = NSMenu()
        mainMenu.addItem(makeAppMenuItem())
        mainMenu.addItem(makeEditMenuItem())
        mainMenu.addItem(makeSessionMenuItem())
        mainMenu.addItem(makeHistoryMenuItem())
        mainMenu.addItem(makeWindowMenuItem())
        mainMenu.addItem(makeHelpMenuItem())
        NSApp.mainMenu = mainMenu
    }

    private func makeAppMenuItem() -> NSMenuItem {
        let appName = Self.appName
        let item = NSMenuItem()
        let menu = NSMenu()
        item.submenu = menu

        let about = NSMenuItem(title: "About \(appName)", action: #selector(menuOpenAbout(_:)), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        if UpdateController.shared.isAvailable {
            let updates = NSMenuItem(title: "Check for Updates…", action: #selector(menuCheckForUpdates(_:)), keyEquivalent: "")
            updates.target = self
            menu.addItem(updates)
        }
        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(menuOpenSettings(_:)), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())

        let servicesMenu = NSMenu()
        let servicesItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        servicesItem.submenu = servicesMenu
        menu.addItem(servicesItem)
        NSApp.servicesMenu = servicesMenu
        menu.addItem(.separator())

        menu.addItem(withTitle: "Hide \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = NSMenuItem(
            title: "Hide Others",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(hideOthers)
        menu.addItem(
            withTitle: "Show All",
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        )
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit \(appName)", action: #selector(menuQuit(_:)), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        return item
    }

    private func makeEditMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Edit")
        item.submenu = menu

        menu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(redo)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        menu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        menu.addItem(withTitle: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        return item
    }

    private func makeSessionMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Session")
        item.submenu = menu

        let start = NSMenuItem(title: "Start Focus", action: #selector(menuStartFocus(_:)), keyEquivalent: "n")
        start.target = self
        menu.addItem(start)

        let skip = NSMenuItem(title: "Skip to Break", action: #selector(menuSkip(_:)), keyEquivalent: "")
        skip.target = self
        menu.addItem(skip)

        let extend = NSMenuItem(title: "Add 5 Minutes", action: #selector(menuExtend(_:)), keyEquivalent: "=")
        extend.target = self
        menu.addItem(extend)

        let stop = NSMenuItem(title: "End Session", action: #selector(menuStopSession(_:)), keyEquivalent: ".")
        stop.target = self
        menu.addItem(stop)
        return item
    }

    private func makeHistoryMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "History")
        item.submenu = menu

        let history = NSMenuItem(title: "Session History", action: #selector(menuOpenHistory(_:)), keyEquivalent: "y")
        history.target = self
        menu.addItem(history)

        let analytics = NSMenuItem(title: "Analytics", action: #selector(menuOpenAnalytics(_:)), keyEquivalent: "y")
        analytics.keyEquivalentModifierMask = [.command, .shift]
        analytics.target = self
        menu.addItem(analytics)
        menu.addItem(.separator())

        let exportCSV = NSMenuItem(title: "Export to CSV…", action: #selector(menuExportCSV(_:)), keyEquivalent: "e")
        exportCSV.target = self
        menu.addItem(exportCSV)

        let exportJSON = NSMenuItem(title: "Export to JSON…", action: #selector(menuExportJSON(_:)), keyEquivalent: "e")
        exportJSON.keyEquivalentModifierMask = [.command, .shift]
        exportJSON.target = self
        menu.addItem(exportJSON)
        return item
    }

    private func makeWindowMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Window")
        item.submenu = menu

        let mainWindow = NSMenuItem(
            title: "\(Self.appName) Window",
            action: #selector(menuOpenMainWindow(_:)),
            keyEquivalent: "0"
        )
        mainWindow.target = self
        menu.addItem(mainWindow)
        menu.addItem(.separator())

        // ⌘1–⌘6 for the pages in the tab bar, in its order.
        for (index, page) in MainPage.tabs.enumerated() {
            let item = NSMenuItem(title: page.title, action: #selector(menuShowPage(_:)), keyEquivalent: "\(index + 1)")
            item.tag = index
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())

        menu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        menu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        NSApp.windowsMenu = menu
        return item
    }

    private func makeHelpMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Help")
        item.submenu = menu

        let guide = NSMenuItem(title: "Welcome Guide", action: #selector(menuShowOnboarding(_:)), keyEquivalent: "")
        guide.target = self
        menu.addItem(guide)
        menu.addItem(.separator())

        let website = NSMenuItem(title: "\(Self.appName) Website", action: #selector(menuOpenWebsite(_:)), keyEquivalent: "")
        website.target = self
        menu.addItem(website)

        let report = NSMenuItem(title: "Report a Problem…", action: #selector(menuReportProblem(_:)), keyEquivalent: "")
        report.target = self
        menu.addItem(report)
        return item
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(menuStartFocus(_:)):
            // Says what it starts, as the window's button does.
            menuItem.title = nextBlockIsStrict ? "Start Strict Block…" : "Start Focus"
            return !isSessionActive
        case #selector(menuStopSession(_:)):
            // After a break ends there is still a cycle to end, as the
            // window's "End cycle" says.
            menuItem.title = snapshot.phase == .breakEnded ? "End Cycle" : "End Session"
            return (isSessionActive || snapshot.phase == .breakEnded) && !isStrictLocked
        case #selector(menuSkip(_:)):
            // The window's words for the same two actions.
            menuItem.title = snapshot.phase == .focus ? "Skip to Break" : "Start Next Block"
            return (isSessionActive || snapshot.phase == .breakEnded) && !isStrictLocked
        case #selector(menuExtend(_:)):
            menuItem.title = snapshot.phase == .focus ? "Add 5 Minutes to Focus" : "Add 5 Minutes to Break"
            return canExtend
        case #selector(menuShowPage(_:)):
            return !isOnboarding
        case #selector(menuExportCSV(_:)), #selector(menuExportJSON(_:)):
            return !history.isEmpty
        case #selector(menuShowOnboarding(_:)):
            return !isSessionActive
        default:
            return true
        }
    }

    @objc private func menuStartFocus(_ sender: Any?) { requestStartFocus() }
    @objc private func menuStopSession(_ sender: Any?) { requestStopSession() }
    @objc private func menuSkip(_ sender: Any?) { requestSkipPhase() }
    @objc private func menuExtend(_ sender: Any?) { extendCurrentPhase() }
    @objc private func menuOpenSettings(_ sender: Any?) { openSettings() }
    @objc private func menuOpenMainWindow(_ sender: Any?) { openMainWindow() }
    @objc private func menuShowPage(_ sender: NSMenuItem) {
        guard MainPage.tabs.indices.contains(sender.tag) else { return }
        page = MainPage.tabs[sender.tag]
        openMainWindow()
    }
    @objc private func menuOpenHistory(_ sender: Any?) { openHistory() }
    @objc private func menuOpenAnalytics(_ sender: Any?) { openAnalytics() }
    @objc private func menuExportCSV(_ sender: Any?) { exportCSVFromPanel() }
    @objc private func menuExportJSON(_ sender: Any?) { exportJSONFromPanel() }
    @objc private func menuCheckForUpdates(_ sender: Any?) { UpdateController.shared.checkForUpdates() }
    @objc private func menuOpenAbout(_ sender: Any?) { openAbout() }
    @objc private func menuShowOnboarding(_ sender: Any?) { showOnboarding() }
    @objc private func menuOpenWebsite(_ sender: Any?) { NSWorkspace.shared.open(AppLinks.website) }
    @objc private func menuReportProblem(_ sender: Any?) { NSWorkspace.shared.open(AppBuildInfo.current.feedbackURL) }
    @objc private func menuQuit(_ sender: Any?) { quit() }
}

extension MenuBarController: AppBlockerDelegate {
    nonisolated func appBlocker(_ blocker: AppBlocker, didIntercept app: InterceptedApp) {
        Task { @MainActor in
            self.presentOverlay(for: app)
        }
    }
}

private extension MenuBarController {
    func startFocusFromBreakEndedOverlay() {
        dismissBreakEndedPrompt()
        startFocus()
    }

    func snoozeBreakEndedOverlay() {
        extendCurrentPhase()
    }

    func endCycleFromBreakEndedOverlay() {
        dismissBreakEndedPrompt()
        dismissCurrentScheduleOccurrence()
        timerEngine.endCycle()
        reloadHistory()
        syncBlocker()
        syncWatchdog()
        finishRun()
    }

    func presentOverlay(for app: InterceptedApp) {
        lastInterceptedBundleId = app.bundleId

        overlay.show(
            appName: app.name,
            countdown: snapshot.formattedRemaining,
            allowSnooze: !isStrictLocked,
            allowEnd: !isStrictLocked,
            snoozeMinutes: snoozeMinutes
        )
    }

    func returnToLastAllowedApp() {
        guard let bundleId = blocker.lastAllowedApplication?.bundleId else {
            return
        }

        NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            .first?
            .activate()
    }

    func allowInterceptedAppTemporarily() {
        overlay.dismiss()

        guard !isStrictLocked else { return }
        guard let bundleId = lastInterceptedBundleId else {
            return
        }

        blocker.allowTemporarily(
            bundleId: bundleId,
            duration: TimeInterval(snoozeMinutes * 60)
        )

        // Re-activate the app the user explicitly chose to allow.
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {
            running.unhide()
            running.activate()
        }
    }
}

// MARK: - Extending and the notch island

extension MenuBarController {
    /// A block or a break is running, or a break ran out and is waiting.
    var canExtend: Bool {
        isSessionActive || snapshot.phase == .breakEnded
    }

    /// Whether the break that follows (or is running after) this block is
    /// the long one.
    var currentBreakIsLong: Bool {
        snapshot.breakMinutes > 0 && config.longBreak.isLongBreak(afterCycle: snapshot.currentCycle)
    }

    /// Five more minutes of whatever is running: more focus, a longer break,
    /// or a break that ran out starting again. Strict blocks allow it too —
    /// it only ever adds focus or postpones the next block.
    /// - Returns: the timer as it is now; `snapshot` only catches up once
    ///   the engine's change has been applied.
    @discardableResult
    func extendCurrentPhase() -> TimerSnapshot? {
        guard canExtend else { return nil }
        let wasWaiting = snapshot.phase == .breakEnded
        if wasWaiting {
            dismissBreakEndedPrompt()
            autoResumeOverlay.dismiss()
            autoResumeAnchor = nil
        }
        guard timerEngine.extend(byMinutes: Self.extendMinutes) else { return nil }
        let extended = timerEngine.snapshot
        reloadHistory()

        if config.notchAlertsEnabled, let endsAt = extended.phaseEndsAt {
            let isFocus = extended.phase == .focus
            notchIsland.present(NotchMoment(
                kind: .extended,
                tone: isFocus ? .focus : .rest,
                symbol: "plus",
                eyebrow: "+\(Self.extendMinutes) min",
                title: "\(isFocus ? "Focus" : "Break") until \(Self.shortTime(endsAt))",
                countsDownTo: endsAt,
                lifetime: 2.5
            ))
        }
        return extended
    }

    func updateLongBreak(_ update: (inout LongBreakSettings) -> Void) {
        var longBreak = config.longBreak
        update(&longBreak)
        // Rebuilt so the ranges are enforced on whatever was changed.
        config.longBreak = LongBreakSettings(enabled: longBreak.enabled, minutes: longBreak.minutes, every: longBreak.every)
        saveConfig()
    }

    func updateNotchAlerts(enabled: Bool) {
        config.notchAlertsEnabled = enabled
        saveConfig()
        if enabled {
            previewNotchIsland()
        } else {
            notchIsland.dismiss()
        }
    }

    /// Shows what the island looks like, from Settings.
    func previewNotchIsland() {
        notchIsland.present(NotchMoment(
            kind: .runDone,
            tone: .focus,
            symbol: "checkmark",
            eyebrow: "Preview",
            title: "This is where Quietwhile speaks up.",
            detail: "When a block or a break ends, and a minute before focus does.",
            set: setProgress(position: 2, done: true),
            lifetime: 4
        ))
    }

    // MARK: Prompt when a break ends

    func showBreakEndedPrompt() {
        guard config.notchAlertsEnabled else {
            breakEndedOverlay.show()
            return
        }
        notchIsland.present(breakOverMoment())
    }

    func dismissBreakEndedPrompt() {
        breakEndedOverlay.dismiss()
        notchIsland.dismiss()
    }

    // MARK: Moments

    /// Called from the tick when a timer ran out on its own, never when
    /// someone pressed Skip or End.
    func presentTimerRanOut(from previous: SessionPhase) {
        guard config.notchAlertsEnabled, previous == .focus else { return }
        switch snapshot.phase {
        case .break:
            notchIsland.present(focusDoneMoment())
        case .completed:
            notchIsland.present(NotchMoment(
                kind: .runDone,
                tone: .done,
                symbol: "checkmark",
                eyebrow: "Block done · \(snapshot.focusMinutes) min",
                title: "That’s the block.",
                detail: currentTask.goal.isEmpty ? nil : currentTask.goal,
                actions: [.init(id: "start", title: nextBlockIsStrict ? "Start strict block" : "Start another", role: .primary)],
                lifetime: 9
            ))
        default:
            break
        }
    }

    /// One minute before focus ends, the chance to keep going — offered
    /// before the block is over rather than after, when it can still be taken
    /// without breaking the thread.
    func syncFinalMinute() {
        guard
            config.notchAlertsEnabled,
            snapshot.phase == .focus,
            snapshot.focusMinutes >= 5,
            let endsAt = snapshot.phaseEndsAt,
            endsAt != finalMinuteShownFor,
            snapshot.remainingSeconds <= 60,
            snapshot.remainingSeconds > 45,
            notchIsland.currentMoment?.holdsUntilAnswered != true
        else {
            return
        }
        finalMinuteShownFor = endsAt

        let breakLine: String
        if snapshot.breakMinutes > 0 {
            breakLine = "Your \(currentBreakIsLong ? "long " : "")break starts at \(Self.shortTime(endsAt))."
        } else {
            breakLine = "The block ends at \(Self.shortTime(endsAt))."
        }
        let goal = currentTask.goal
        notchIsland.present(NotchMoment(
            kind: .finalMinute,
            tone: .finalMinute,
            symbol: "hourglass",
            eyebrow: "One minute left",
            title: goal.isEmpty ? "Land the thought you’re on." : goal,
            detail: breakLine,
            countsDownTo: endsAt,
            actions: [.init(id: "extend", title: "+\(Self.extendMinutes) min focus", role: .secondary)],
            lifetime: 9
        ))
    }

    private func focusDoneMoment() -> NotchMoment {
        let isLong = currentBreakIsLong
        let suggestion = breakSuggestion?.title
        let detail = suggestion ?? (isLong ? "Get properly away from the desk." : "Step away from the screen for a bit.")
        return NotchMoment(
            kind: .focusDone,
            tone: .rest,
            symbol: isLong ? "sun.max.fill" : "leaf.fill",
            eyebrow: isLong ? "Set done · \(config.longBreak.every) blocks" : "Block \(snapshot.currentCycle) done · \(snapshot.focusMinutes) min",
            title: "\(isLong ? "Long break" : "Break") · \(snapshot.breakMinutes) min",
            detail: detail,
            countsDownTo: snapshot.phaseEndsAt,
            set: setProgress(position: config.longBreak.positionInSet(cycle: snapshot.currentCycle), done: true),
            actions: [.init(id: "skip", title: "Skip break", role: .secondary)],
            lifetime: 9
        )
    }

    private func breakOverMoment() -> NotchMoment {
        let nextCycle = snapshot.currentCycle + 1
        let nextEarnsLong = config.longBreak.isLongBreak(afterCycle: nextCycle) && config.breakMinutes > 0
        var detail = "Block \(nextCycle) · \(config.focusMinutes) min"
        if nextEarnsLong {
            detail += " — the long break comes after this one."
        }
        return NotchMoment(
            kind: .breakOver,
            tone: .focus,
            symbol: "arrow.forward",
            eyebrow: currentBreakIsLong ? "Long break over" : "Break over",
            title: "Back to it.",
            detail: detail,
            set: setProgress(position: config.longBreak.positionInSet(cycle: nextCycle), done: false),
            actions: [
                .init(id: "start", title: nextBlockIsStrict ? "Start strict block" : "Start focus", role: .primary),
                .init(id: "extend", title: "+\(Self.extendMinutes) min break", role: .secondary),
                .init(id: "endCycle", title: "End cycle", role: .quiet)
            ],
            holdsUntilAnswered: true
        )
    }

    private func setProgress(position: Int, done: Bool) -> NotchMoment.SetProgress? {
        guard config.longBreak.enabled, config.breakMinutes > 0 else { return nil }
        return .init(position: position, total: config.longBreak.every, positionDone: done)
    }

    func handleNotchAction(_ id: String) {
        switch id {
        case "start":
            notchIsland.dismiss()
            if snapshot.phase == .breakEnded {
                startFocusFromBreakEndedOverlay()
            } else {
                requestStartFocus()
            }
        case "extend":
            extendCurrentPhase()
        case "skip":
            notchIsland.dismiss()
            requestSkipPhase()
        case "endCycle":
            notchIsland.dismiss()
            endCycleFromBreakEndedOverlay()
        default:
            notchIsland.dismiss()
        }
    }
}

// MARK: - Focus time, for Insights

extension MenuBarController {
    func updateTrackFocusTime(enabled: Bool) {
        config.trackFocusTime = enabled
        saveConfig()
        if !enabled {
            // What was counted so far in this block is kept; nothing more is.
            flushFocusTime()
        }
    }

    /// Forgets every reach and all focus time. History itself is untouched.
    func clearInsightsData() {
        focusTime = FocusTimeAccumulator()
        lastFocusTimeSample = nil
        reachLog.reset()
        focusTimeStore.reset()
        reaches = []
        focusTimeRecords = []
    }

    /// Counts the time since the last tick against whatever app is in front,
    /// during focus only and only while someone is at the keyboard.
    func sampleFocusTime(now: Date) {
        guard config.trackFocusTime, snapshot.phase == .focus, let blockStart = snapshot.sessionStartedAt else {
            lastFocusTimeSample = nil
            return
        }
        focusTime.begin(blockStartedAt: blockStart)
        defer { lastFocusTimeSample = now }
        guard let last = lastFocusTimeSample else { return }

        // Two minutes without a key or the mouse is someone away from the
        // desk, not time spent in the app they left in front.
        guard systemIdleSeconds < 120,
              let app = NSWorkspace.shared.frontmostApplication,
              let bundleId = app.bundleIdentifier
        else {
            return
        }
        focusTime.addApp(bundleId: bundleId, name: app.localizedName ?? bundleId, seconds: now.timeIntervalSince(last))

        guard let browser = SupportedBrowser(rawValue: bundleId),
              permissions.browsers[browser] == .granted,
              now.timeIntervalSince(lastDomainSample) >= Self.domainSampleSeconds
        else {
            return
        }
        lastDomainSample = now
        domainSampler.host(in: browser) { [weak self] host in
            guard let self, let host, self.snapshot.sessionStartedAt == blockStart else { return }
            self.focusTime.addSite(host: host, seconds: Self.domainSampleSeconds)
        }
    }

    /// How often the front tab is read: enough for totals, rare enough that
    /// the browser never notices.
    static let domainSampleSeconds: TimeInterval = 5

    func flushFocusTime() {
        lastFocusTimeSample = nil
        guard let record = focusTime.finish() else { return }
        focusTimeStore.append(record)
        focusTimeRecords.append(record)
    }
}
