import AppKit
import FocusLockCore
import SwiftUI
import UniformTypeIdentifiers

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
    @Published var settingsMessage: String?
    @Published var exportMessage: String?
    @Published var streamMessage: String?

    /// Everyone working alongside the host. Fed by chat later; by hand today.
    @Published var roster = AudienceRoster()

    /// When the current run began. Kept after the run ends so the recap is
    /// still there when you go looking for it, and replaced only when the
    /// next run starts.
    @Published private(set) var runStartedAt: Date?

    /// Which pane the sidebar is showing. Settings, History, and Analytics are
    /// panes rather than separate windows, so navigation lives here.
    @Published var page: MainPage = .focus

    /// Focus minutes per weekday for the current week, and the run of days with
    /// at least one completed session. Cached because both are read on every
    /// redraw but only change when a session ends.
    @Published private(set) var weeklyRhythm: [DailyFocus] = []
    @Published private(set) var streak: Int = 0
    @Published private(set) var blockedTodayCounts: [String: Int] = [:]
    @Published private(set) var sessionStats: SessionStats = .empty

    private let stateStore: StateStore
    private let historyStore: SessionHistoryStore
    private let exportService: ExportService
    private let notificationService: NotificationService
    private let blocker: AppBlocker
    private let timerEngine: TimerEngine
    private let activityStore = BlockActivityStore()
    private let overlay = FocusOverlayController()
    private let breakEndedOverlay = BreakEndedWindowController()
    private let autoResumeOverlay = AutoResumeOverlayController()
    private let pinnedHUD = PinnedHUDController()

    private let snoozeMinutes = 5
    private let breakSnoozeMinutes = 2
    private var lastInterceptedBundleId: String?

    /// When autopilot started counting the current wait: the moment the break
    /// ended, or the moment the takeover was last pushed away. In memory only —
    /// quitting ends the cycle anyway.
    private var autoResumeAnchor: Date?

    private var tickTimer: Timer?
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var mainWindow: NSWindow?
    private var streamWindow: NSWindow?
    private var reopenObserver: NSObjectProtocol?
    private var blockerRunning = false
    private var hasSetup = false

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

    /// Apps that are actually guarded right now — entries toggled off stay in
    /// the list but are excluded everywhere the count is shown.
    var activeBlockedApps: [BlockedApp] {
        config.blockedApps.filter(\.isEnabled)
    }

    func blockedTodayCount(for app: BlockedApp) -> Int {
        blockedTodayCounts[app.bundleId] ?? 0
    }

    /// What the clock should read. Idle and finished states show the duration
    /// that pressing Start would run, rather than a bare 00:00 that looks like
    /// a session ended badly.
    var displayCountdown: String {
        switch snapshot.phase {
        case .focus, .break, .paused:
            return snapshot.formattedRemaining
        case .breakEnded:
            return String(format: "%02d:00", config.focusMinutes)
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
            snapshot.task?.shared != true,
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

    override init() {
        let stateStore = StateStore()
        let historyStore = SessionHistoryStore()
        let notificationService = NotificationService()
        let exportService = ExportService()

        self.stateStore = stateStore
        self.historyStore = historyStore
        self.notificationService = notificationService
        self.exportService = exportService
        self.config = stateStore.loadConfig()
        self.history = historyStore.loadHistory()
        self.timerEngine = TimerEngine(
            stateStore: stateStore,
            historyStore: historyStore,
            notificationService: notificationService
        )
        self.snapshot = timerEngine.snapshot
        self.blocker = AppBlocker(notificationService: notificationService)

        super.init()

        self.timerEngine.onChange = { [weak self] snapshot in
            Task { @MainActor in
                self?.apply(snapshot)
            }
        }

        self.blocker.delegate = self
        self.blocker.onInterception = { [weak self] app in
            Task { @MainActor in
                self?.recordInterception(of: app)
            }
        }

        configureOverlayHandlers()
        configureBreakEndedHandlers()
        configureAutoResumeHandlers()
        configurePinnedHUDHandlers()
        refreshDerivedStats()
    }

    private func configurePinnedHUDHandlers() {
        pinnedHUD.onEnd = { [weak self] in
            self?.stopSession()
        }
        pinnedHUD.onUnpin = { [weak self] in
            self?.updatePinnedHUD(enabled: false)
        }
    }

    private func recordInterception(of app: InterceptedApp) {
        blockedTodayCounts = activityStore.recordInterception(bundleId: app.bundleId)
    }

    /// Re-reads the history file and everything derived from it. Every code
    /// path that can append an entry goes through here so the sidebar streak
    /// and week chart never lag behind the list.
    private func reloadHistory() {
        history = historyStore.loadHistory()
        refreshDerivedStats()
    }

    /// Recomputes the week chart, streak, and today's block counts. Called
    /// whenever history changes rather than on every redraw, since each read
    /// walks the whole history file.
    private func refreshDerivedStats() {
        sessionStats = historyStore.stats()
        weeklyRhythm = historyStore.weeklyRhythm()
        streak = historyStore.focusStreak()
        blockedTodayCounts = activityStore.countsToday()
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
            self?.overlay.dismiss()
            self?.stopSession()
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
        syncRosterSettings()
        reopenObserver = NotificationCenter.default.addObserver(
            forName: .lockInShowMainWindow,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.openMainWindow()
            }
        }

        setupMainMenu()
        setupStatusItem()
        notificationService.requestAuthorization()
        syncPresetFromConfig()
        startTicking()
        syncBlocker()
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

    /// Quitting mid-session ends it: stop guarding and record an interrupted
    /// focus block as abandoned before the process exits.
    func handleAppWillTerminate() {
        blocker.stop()
        pinnedHUD.dismiss()
        timerEngine.recordAbandonmentIfNeeded()
    }

    func updateStream(_ update: (inout StreamSettings) -> Void) {
        update(&config.stream)
        streamWindow?.appearance = NSAppearance(named: config.stream.darkAppearance ? .darkAqua : .aqua)
        saveConfig()
    }

    var streamTask: SessionTask {
        switch snapshot.phase {
        case .idle: return config.stream.task
        default: return snapshot.task ?? config.stream.task
        }
    }

    var checkInEntry: SessionHistoryEntry? {
        guard snapshot.phase == .break || snapshot.phase == .breakEnded || snapshot.phase == .completed,
              let taskID = snapshot.task?.id else { return nil }
        return history.first { $0.task?.id == taskID && $0.status == .completed }
    }

    func saveCheckIn(outcome: CheckInOutcome, note: String) {
        guard let entry = checkInEntry, let taskID = entry.task?.id else { return }
        do {
            try historyStore.saveCheckIn(taskID: taskID, checkIn: SessionCheckIn(outcome: outcome, note: note))
            reloadHistory()
            var clearedGoal = false
            updateStream { clearedGoal = $0.clearCompletedGoal(matching: entry.task, outcome: outcome) }
            streamMessage = clearedGoal
                ? "Check-in saved. Your note stays private. Goal cleared — set the next one when you're ready."
                : "Check-in saved. Your note stays private."
        } catch {
            streamMessage = "Could not save your check-in: \(error.localizedDescription)"
        }
    }

    private var audienceAlerts = AudienceAlertThrottle()

    /// Silent by default. A sound can reach the broadcast through desktop
    /// audio and a banner can reach it through a display capture, so both are
    /// opt-in and the banner never carries a viewer's words.
    private func alertIfSomeoneIsWaiting() {
        updateStatusItem()
        guard !config.stream.autoApproveTasks else { return }
        guard audienceAlerts.shouldAlert(waiting: roster.held.count, at: Date()) else { return }

        if config.stream.alertSound {
            NSSound(named: "Tink")?.play()
        }
        if config.stream.alertBanner {
            notificationService.audienceTasksWaiting(count: roster.held.count)
        }
    }

    func submitAudienceTask(name: String, text: String) {
        defer { alertIfSomeoneIsWaiting() }
        switch roster.submit(name: name, text: text) {
        case .admitted:
            streamMessage = "\(name) is on the wall."
        case .held:
            streamMessage = "\(name) is waiting for you to approve them."
        case .rejected(.empty):
            streamMessage = "That needs both a name and a task."
        case .rejected(.blocked):
            streamMessage = "\(name) is blocked for this stream."
        case .rejected(.tooSoon):
            streamMessage = "\(name) just posted — give it a moment."
        case .rejected(.containsLink):
            streamMessage = "Refused: that reads as a link, and links do not go on the wall."
        case .rejected(.blockedWord):
            streamMessage = "Refused: that contains a word on your blocked list."
        }
    }

    func handleAudienceMessage(from name: String, message: String) {
        guard let command = AudienceCommand.parse(message) else { return }
        roster.apply(command, from: name)
        alertIfSomeoneIsWaiting()
    }

    func syncRosterSettings() {
        roster.autoApprove = config.stream.autoApproveTasks
        roster.blockedTerms = AudienceFilter.defaultTerms
            .union(AudienceFilter.terms(fromFileAt: blockedWordsURL))
    }

    /// One term per line. Kept beside the other LockIn data so it survives an
    /// app update and can be edited without the app running.
    var blockedWordsURL: URL {
        stateStore.configURL.deletingLastPathComponent().appendingPathComponent("blocked-words.txt")
    }

    func revealBlockedWordsFile() {
        if !FileManager.default.fileExists(atPath: blockedWordsURL.path) {
            let template = """
            # One blocked word or phrase per line. Lines starting with # are ignored.
            # LockIn already folds spacing, punctuation, accents, repeated letters,
            # and digits-for-letters, so one entry catches its variants.
            # Add the slurs and platform-specific terms you want refused here.

            """
            try? template.write(to: blockedWordsURL, atomically: true, encoding: .utf8)
        }
        NSWorkspace.shared.activateFileViewerSelecting([blockedWordsURL])
    }

    var streamRecap: StreamRecap {
        guard let runStartedAt else { return StreamRecap.make(from: [], since: .distantFuture) }
        return StreamRecap.make(from: history, since: runStartedAt, companions: roster.admitted.count)
    }

    func copyRecap() {
        let recap = streamRecap
        guard !recap.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(recap.text, forType: .string)
        streamMessage = "Recap copied."
    }

    func setAudienceAutoApprove(_ isOn: Bool) {
        updateStream { $0.autoApproveTasks = isOn }
        roster.autoApprove = isOn
    }

    /// Apps you are guarding that this stream depends on.
    var streamHazards: [StreamHazard] {
        StreamHazard.hazards(in: config.blockedApps)
    }

    /// Leaves the app in the list so it is guarded again next session — the
    /// point is to get through the stream, not to rebuild the list afterwards.
    func unguard(_ hazard: StreamHazard) {
        guard let index = config.blockedApps.firstIndex(where: { $0.bundleId == hazard.app.bundleId }) else { return }
        config.blockedApps[index].isEnabled = false
        saveConfig()
        syncBlocker()
        streamMessage = "\(hazard.app.name) is no longer guarded. Turn it back on in Blocked apps when you're done."
    }

    func apply(_ preset: StreamPreset) {
        preset.apply(to: &config)
        syncPresetFromConfig()
        saveConfig()
        streamMessage = "\(preset.name) · \(config.focusMinutes)/\(config.breakMinutes) minutes, \(config.stream.plannedBlocks) blocks."
    }

    /// LockIn never plays or rebroadcasts audio; it only hands the link to
    /// whichever app owns it.
    func openPlaylist() {
        guard let url = config.stream.playlistDestination else {
            streamMessage = "That playlist link is not one LockIn can open. Paste a web or Spotify link."
            return
        }
        NSWorkspace.shared.open(url)
    }

    func openStreamWindow() {
        streamWindow = presentWindow(
            existingWindow: streamWindow,
            title: "LockIn Stream",
            size: NSSize(width: 960, height: 600),
            rootView: StreamAudienceView().environmentObject(self)
        )
        streamWindow?.appearance = NSAppearance(named: config.stream.darkAppearance ? .darkAqua : .aqua)
        streamWindow?.titleVisibility = .visible
        streamWindow?.minSize = NSSize(width: 640, height: 420)
    }

    func startFocus() {
        guard !isSessionActive else { return }
        streamMessage = nil
        let cycle = snapshot.phase == .breakEnded ? snapshot.currentCycle + 1 : 1
        if cycle == 1 {
            runStartedAt = Date()
            roster.clear()
        }
        breakEndedOverlay.dismiss()
        autoResumeOverlay.dismiss()
        autoResumeAnchor = nil
        saveConfig()
        timerEngine.startFocus(
            focusMinutes: config.focusMinutes,
            breakMinutes: config.breakMinutes,
            blockedAppsCount: config.blockedApps.count,
            strictMode: config.strictMode,
            task: config.stream.task,
            // Continuing a run keeps counting; anything else starts one.
            cycle: cycle
        )
        reloadHistory()
        syncBlocker()
        syncPinnedHUD()
    }

    func stopSession() {
        breakEndedOverlay.dismiss()
        autoResumeOverlay.dismiss()
        autoResumeAnchor = nil
        timerEngine.stopSession()
        reloadHistory()
        syncBlocker()
        syncPinnedHUD()
    }

    func selectPreset(_ newPreset: FocusPreset) {
        preset = newPreset

        guard let durations = newPreset.durations else {
            return
        }

        config.focusMinutes = durations.focus
        config.breakMinutes = durations.rest
        saveConfig()
    }

    func updateFocusMinutes(_ minutes: Int) {
        config.focusMinutes = AppConfig.normalizedFocusMinutes(minutes)
        preset = matchingPreset() ?? .custom
        saveConfig()
    }

    func updateBreakMinutes(_ minutes: Int) {
        config.breakMinutes = min(60, max(0, minutes))
        preset = matchingPreset() ?? .custom
        saveConfig()
    }

    func updateBlockerMode(_ blockerMode: BlockerMode) {
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

    func updatePinnedHUD(enabled: Bool) {
        config.pinnedHUDEnabled = enabled
        saveConfig()
        syncPinnedHUD()
    }

    /// Per-app behaviour override. `nil` puts the app back on the global
    /// default from Settings.
    func setBlockedApp(_ app: BlockedApp, behavior: BlockerMode?) {
        guard let index = config.blockedApps.firstIndex(where: { $0.bundleId == app.bundleId }) else {
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

        config.blockedApps[index].isEnabled = enabled
        saveConfig()
        syncBlocker()
    }

    func addBlockedAppFromPanel() {
        FocusLockLog.debug("app picker opened")
        let panel = NSOpenPanel()
        panel.title = "Choose an app to block"
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
        config.blockedApps.removeAll { $0.bundleId == app.bundleId }
        settingsMessage = "Removed \(app.name)."
        saveConfig()
        syncBlocker()
    }

    func openMainWindow() {
        popover.performClose(nil)
        mainWindow = presentWindow(
            existingWindow: mainWindow,
            title: AppIdentity.name,
            size: NSSize(width: 900, height: 620),
            rootView: MainWindowView().environmentObject(self)
        )
        // SwiftUI installs its Settings-scene menu after launch. Restore our
        // app commands once the actual main window has been presented.
        setupMainMenu()
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
        blocker.stop()
        NSApp.terminate(nil)
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover()
        }
    }

    private func apply(_ newSnapshot: TimerSnapshot) {
        let previousPhase = snapshot.phase
        snapshot = newSnapshot

        // History only changes when the phase does; re-reading the file every
        // tick would be wasteful.
        if previousPhase != newSnapshot.phase {
            if newSnapshot.task?.shared == true && (newSnapshot.phase == .break || newSnapshot.phase == .completed) {
                page = .stream
            }
            reloadHistory()
        }

        updateStatusItem()
        syncBlocker()
        syncPinnedHUD()
        handleBreakEndedTransition(from: previousPhase, to: newSnapshot.phase)
        syncAutoResume()

        if overlay.isShowing {
            overlay.updateCountdown(snapshot.formattedRemaining)
        }
    }

    /// The HUD is only on screen while a session is running and the preference
    /// is on, so an idle LockIn leaves no residue over your work.
    private func syncPinnedHUD() {
        guard config.pinnedHUDEnabled, isSessionActive else {
            pinnedHUD.dismiss()
            return
        }

        pinnedHUD.show()
        pinnedHUD.update(
            countdown: snapshot.formattedRemaining,
            phaseLabel: hudPhaseLabel,
            guardedLine: hudGuardedLine,
            progress: phaseProgress
        )
    }

    private var hudPhaseLabel: String {
        switch snapshot.phase {
        case .break:
            return "Break"
        default:
            return "Focus · \(config.focusMinutes)/\(config.breakMinutes)"
        }
    }

    private var hudGuardedLine: String {
        let apps = activeBlockedApps
        guard !apps.isEmpty else {
            return "No apps guarded"
        }

        let names = apps.prefix(3).map(\.name).joined(separator: ", ")
        let extra = apps.count - min(3, apps.count)
        return extra > 0 ? "\(names) +\(extra)" : names
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
        popover.contentSize = NSSize(width: 404, height: 110)
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: MenuBarPopoverView()
                .environmentObject(self)
        )

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

        let waiting = roster.held.count
        // A dot rather than a number: the menu bar is not the place to read a
        // queue, only to notice there is one.
        let countdown = statusCountdownTitle.map { waiting > 0 ? "\($0) •" : $0 }
        updateTitleForActiveSession(countdown: countdown)
        button.toolTip = waiting > 0
            ? "\(waiting) waiting for you to approve · \(statusTooltip)"
            : statusTooltip
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
            return "\(AppIdentity.name): \(snapshot.formattedRemaining) focus remaining"
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
                self?.timerEngine.refresh()
            }
        }
    }

    private func syncBlocker() {
        guard AppBlocker.shouldRun(for: snapshot.phase) else {
            if blockerRunning {
                blocker.stop()
                blockerRunning = false
            }
            overlay.dismiss()
            return
        }

        if blockerRunning {
            blocker.update(blockedApps: config.blockedApps, blockerMode: config.blockerMode)
        } else {
            blocker.start(blockedApps: config.blockedApps, blockerMode: config.blockerMode)
            blockerRunning = true
        }
    }

    private func handleBreakEndedTransition(from previousPhase: SessionPhase, to newPhase: SessionPhase) {
        guard newPhase == .breakEnded, previousPhase != .breakEnded else {
            return
        }

        if snapshot.task?.shared == true {
            // The host chooses when the next block begins after checking in.
            page = .stream
            return
        }

        switch config.breakEndBehavior {
        case .startImmediately:
            startFocus()
        case .ask, .autopilot:
            // Autopilot still asks first — it only takes the screen once the
            // grace period has gone by with no answer.
            autoResumeAnchor = snapshot.breakEndedAt
            breakEndedOverlay.show()
        }
    }

    /// Runs on every tick while a break is over and unanswered. Waits out the
    /// grace period, then puts the takeover up and lets it count down.
    private func syncAutoResume(now: Date = Date()) {
        guard
            config.breakEndBehavior == .autopilot,
            snapshot.task?.shared != true,
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
                breakEndedOverlay.dismiss()
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
        breakEndedOverlay.show()
    }

    private static func formatCountdown(_ seconds: TimeInterval) -> String {
        let whole = max(0, Int(seconds.rounded(.up)))
        return String(format: "%02d:%02d", whole / 60, whole % 60)
    }

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
                return "lockin-history.csv"
            case .json:
                return "lockin-history.json"
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
        size: NSSize,
        rootView: Content
    ) -> NSWindow {
        if let existingWindow {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            existingWindow.makeKeyAndOrderFront(nil)
            existingWindow.makeMain()
            NSApp.activate(ignoringOtherApps: true)
            return existingWindow
        }

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.minSize = NSSize(width: min(size.width, 820), height: min(size.height, 580))
        window.isReleasedWhenClosed = false

        // The sand canvas runs edge to edge; a stock titlebar would cut a white
        // band across the top of it.
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = FLColor.canvasWarm
        window.isMovableByWindowBackground = true

        window.contentView = NSHostingView(rootView: rootView)
        window.center()
        window.setFrameAutosaveName(title)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeMain()
        NSApp.activate(ignoringOtherApps: true)
        return window
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
        NSApp.mainMenu = mainMenu
    }

    private func makeAppMenuItem() -> NSMenuItem {
        let appName = Self.appName
        let item = NSMenuItem()
        let menu = NSMenu()
        item.submenu = menu

        menu.addItem(
            withTitle: "About \(appName)",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
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

        let stop = NSMenuItem(title: "Stop Session", action: #selector(menuStopSession(_:)), keyEquivalent: ".")
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
            keyEquivalent: "1"
        )
        mainWindow.target = self
        menu.addItem(mainWindow)
        let stream = NSMenuItem(title: "Stream Window", action: #selector(menuOpenStream(_:)), keyEquivalent: "2")
        stream.target = self
        menu.addItem(stream)
        menu.addItem(.separator())

        menu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        menu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        NSApp.windowsMenu = menu
        return item
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(menuStartFocus(_:)):
            return !isSessionActive
        case #selector(menuStopSession(_:)):
            return isSessionActive
        case #selector(menuExportCSV(_:)), #selector(menuExportJSON(_:)):
            return !history.isEmpty
        default:
            return true
        }
    }

    @objc private func menuOpenStream(_ sender: Any?) { openStreamWindow() }
    @objc private func menuStartFocus(_ sender: Any?) { startFocus() }
    @objc private func menuStopSession(_ sender: Any?) { stopSession() }
    @objc private func menuOpenSettings(_ sender: Any?) { openSettings() }
    @objc private func menuOpenMainWindow(_ sender: Any?) { openMainWindow() }
    @objc private func menuOpenHistory(_ sender: Any?) { openHistory() }
    @objc private func menuOpenAnalytics(_ sender: Any?) { openAnalytics() }
    @objc private func menuExportCSV(_ sender: Any?) { exportCSVFromPanel() }
    @objc private func menuExportJSON(_ sender: Any?) { exportJSONFromPanel() }
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
        breakEndedOverlay.dismiss()
        startFocus()
    }

    func snoozeBreakEndedOverlay() {
        breakEndedOverlay.dismiss()
        timerEngine.startBreakExtension(
            minutes: breakSnoozeMinutes,
            focusMinutes: config.focusMinutes,
            blockedAppsCount: config.blockedApps.count,
            strictMode: config.strictMode
        )
        reloadHistory()
        syncBlocker()
    }

    func endCycleFromBreakEndedOverlay() {
        breakEndedOverlay.dismiss()
        timerEngine.endCycle()
        reloadHistory()
        syncBlocker()
    }

    func presentOverlay(for app: InterceptedApp) {
        lastInterceptedBundleId = app.bundleId

        overlay.show(
            appName: app.name,
            countdown: snapshot.formattedRemaining,
            allowSnooze: true,
            snoozeMinutes: snoozeMinutes
        )
    }

    func returnToLastAllowedApp() {
        guard let bundleId = blocker.lastAllowedApplication?.bundleId else {
            return
        }

        NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            .first?
            .activate(options: [.activateIgnoringOtherApps])
    }

    func allowInterceptedAppTemporarily() {
        overlay.dismiss()

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
            running.activate(options: [.activateIgnoringOtherApps])
        }
    }
}
