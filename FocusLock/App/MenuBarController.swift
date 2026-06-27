import AppKit
import FocusLockCore
import SwiftUI
import UniformTypeIdentifiers

enum FocusPreset: String, CaseIterable, Identifiable {
    case twentyFiveFive
    case fortyFiveTen
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .twentyFiveFive:
            return "25 / 5"
        case .fortyFiveTen:
            return "45 / 10"
        case .custom:
            return "Custom"
        }
    }

    var durations: (focus: Int, rest: Int)? {
        switch self {
        case .twentyFiveFive:
            return (25, 5)
        case .fortyFiveTen:
            return (45, 10)
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
    @Published var preset: FocusPreset = .twentyFiveFive
    @Published var settingsMessage: String?
    @Published var exportMessage: String?

    private let stateStore: StateStore
    private let historyStore: SessionHistoryStore
    private let exportService: ExportService
    private let notificationService: NotificationService
    private let blocker: AppBlocker
    private let timerEngine: TimerEngine
    private let overlay = FocusOverlayController()
    private let breakEndedOverlay = BreakEndedWindowController()

    private let snoozeMinutes = 5
    private let breakSnoozeMinutes = 2
    private var lastInterceptedBundleId: String?

    private var tickTimer: Timer?
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var mainWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var historyWindow: NSWindow?
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
        configureOverlayHandlers()
        configureBreakEndedHandlers()
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

    func setup() {
        FocusLockLog.debug("MenuBarController setup called")
        guard !hasSetup else {
            FocusLockLog.debug("\(AppIdentity.name) menu bar status item already exists")
            return
        }

        hasSetup = true
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

    func startFocus() {
        breakEndedOverlay.dismiss()
        saveConfig()
        timerEngine.startFocus(
            focusMinutes: config.focusMinutes,
            breakMinutes: config.breakMinutes,
            blockedAppsCount: config.blockedApps.count,
            strictMode: config.strictMode
        )
        history = historyStore.loadHistory()
        syncBlocker()
    }

    func stopSession() {
        breakEndedOverlay.dismiss()
        timerEngine.stopSession()
        history = historyStore.loadHistory()
        syncBlocker()
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
        config.focusMinutes = min(180, max(1, minutes))
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
        mainWindow = presentWindow(
            existingWindow: mainWindow,
            title: AppIdentity.name,
            size: NSSize(width: 396, height: 620),
            rootView: MenuBarPopoverView().environmentObject(self)
        )
    }

    func openSettings() {
        FocusLockLog.debug("settings window opened")
        settingsWindow = presentWindow(
            existingWindow: settingsWindow,
            title: "\(AppIdentity.name) Settings",
            size: NSSize(width: 460, height: 520),
            rootView: SettingsView().environmentObject(self)
        )
    }

    func openHistory() {
        FocusLockLog.debug("history window opened")
        history = historyStore.loadHistory()
        historyWindow = presentWindow(
            existingWindow: historyWindow,
            title: "\(AppIdentity.name) Session History",
            size: NSSize(width: 760, height: 560),
            rootView: SessionHistoryView().environmentObject(self)
        )
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
        history = historyStore.loadHistory()
        updateStatusItem()
        syncBlocker()
        handleBreakEndedTransition(from: previousPhase, to: newSnapshot.phase)

        if overlay.isShowing {
            overlay.updateCountdown(snapshot.formattedRemaining)
        }
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
        popover.contentSize = NSSize(width: 360, height: 600)
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

        updateTitleForFocus(remainingMinutes: statusRemainingMinutes)
        button.toolTip = statusTooltip
    }

    private var statusRemainingMinutes: Int? {
        guard snapshot.phase == .focus else {
            return nil
        }
        return max(1, Int(ceil(snapshot.remainingSeconds / 60)))
    }

    func updateTitleForFocus(remainingMinutes: Int?) {
        guard let button = statusItem?.button else {
            FocusLockLog.debug("Status item button missing")
            return
        }

        if let remainingMinutes {
            button.image = nil
            button.title = "\(remainingMinutes)m"
        } else if snapshot.phase == .break {
            button.image = nil
            button.title = "Break"
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

        if config.autoStartFocusAfterBreak {
            startFocus()
        } else {
            breakEndedOverlay.show()
        }
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
        history = historyStore.loadHistory()

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
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.minSize = NSSize(width: min(size.width, 420), height: min(size.height, 420))
        window.isReleasedWhenClosed = false
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

    @objc private func menuStartFocus(_ sender: Any?) { startFocus() }
    @objc private func menuStopSession(_ sender: Any?) { stopSession() }
    @objc private func menuOpenSettings(_ sender: Any?) { openSettings() }
    @objc private func menuOpenMainWindow(_ sender: Any?) { openMainWindow() }
    @objc private func menuOpenHistory(_ sender: Any?) { openHistory() }
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
        history = historyStore.loadHistory()
        syncBlocker()
    }

    func endCycleFromBreakEndedOverlay() {
        breakEndedOverlay.dismiss()
        timerEngine.endCycle()
        history = historyStore.loadHistory()
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
