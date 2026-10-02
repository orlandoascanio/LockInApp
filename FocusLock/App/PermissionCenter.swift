import AppKit
import FocusLockCore
import UserNotifications

enum PermissionState: Equatable {
    /// macOS has not put the question to the user yet.
    case notAsked
    case granted
    case denied
}

/// The two things macOS asks the user about on LockIn's behalf: notifications,
/// and reading the current tab of each browser. Nothing here prompts by
/// itself. A system dialog only ever follows a button in a screen that has
/// said what the permission is for.
@MainActor
final class PermissionCenter: ObservableObject {
    @Published private(set) var notifications: PermissionState = .notAsked
    @Published private(set) var browsers: [SupportedBrowser: PermissionState] = [:]

    /// The browser whose system dialog is on screen right now.
    @Published private(set) var pendingBrowser: SupportedBrowser?

    var onBrowserGranted: ((SupportedBrowser) -> Void)?

    let installedBrowsers: [SupportedBrowser] = SupportedBrowser.allCases.filter {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.bundleIdentifier) != nil
    }

    // Asking a browser blocks until the user answers, so it never runs on main.
    private static let queue = DispatchQueue(label: "com.lockin.permissions")
    private var refreshing: Set<SupportedBrowser> = []
    private var activeObserver: NSObjectProtocol?

    init() {
        // Coming back from System Settings is the usual way an answer changes.
        activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        refresh()
    }

    deinit {
        if let activeObserver {
            NotificationCenter.default.removeObserver(activeObserver)
        }
    }

    func state(for browser: SupportedBrowser) -> PermissionState {
        browsers[browser] ?? .notAsked
    }

    func refresh() {
        refreshNotifications()
        for browser in installedBrowsers {
            refresh(browser)
        }
    }

    // MARK: - Notifications

    func refreshNotifications() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let state: PermissionState
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                state = .granted
            case .denied:
                state = .denied
            default:
                state = .notAsked
            }
            Task { @MainActor [weak self] in
                self?.notifications = state
            }
        }
    }

    /// Shows the system dialog. Call only from a button that has explained it.
    func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
            Task { @MainActor [weak self] in
                self?.refreshNotifications()
            }
        }
    }

    func openNotificationSettings() {
        open("x-apple.systempreferences:com.apple.Notifications-Settings.extension")
    }

    // MARK: - Browsers

    /// Looks up the answer without ever asking. A browser that is not running
    /// cannot say, and keeps whatever was last known.
    func refresh(_ browser: SupportedBrowser) {
        guard !refreshing.contains(browser), pendingBrowser != browser else { return }
        refreshing.insert(browser)
        let bundleId = browser.bundleIdentifier
        Self.queue.async {
            let status = Self.automationStatus(for: bundleId, asking: false)
            Task { @MainActor [weak self] in
                self?.refreshing.remove(browser)
                self?.record(status, for: browser)
            }
        }
    }

    /// Shows the system dialog for this browser, opening it in the background
    /// first if it is closed. Call only from a button that has explained it.
    func requestBrowser(_ browser: SupportedBrowser) {
        guard pendingBrowser == nil else { return }
        let bundleId = browser.bundleIdentifier
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else { return }
        pendingBrowser = browser

        let ask: @Sendable () -> Void = {
            Self.queue.async {
                let status = Self.automationStatus(for: bundleId, asking: true)
                Task { @MainActor [weak self] in
                    self?.pendingBrowser = nil
                    self?.record(status, for: browser)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }

        if !NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty {
            ask()
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
            // A browser takes a moment after launch before it can be addressed.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: ask)
        }
    }

    func openAutomationSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
    }

    private func record(_ status: OSStatus, for browser: SupportedBrowser) {
        let previous = browsers[browser]
        switch status {
        case noErr:
            browsers[browser] = .granted
        case OSStatus(errAEEventNotPermitted):
            browsers[browser] = .denied
        case -1744: // errAEEventWouldRequireUserConsent
            browsers[browser] = .notAsked
        default:
            // Not running, or it could not be reached: no new information.
            return
        }
        if browsers[browser] == .granted, previous != .granted {
            onBrowserGranted?(browser)
        }
    }

    nonisolated private static func automationStatus(for bundleId: String, asking: Bool) -> OSStatus {
        let target = NSAppleEventDescriptor(bundleIdentifier: bundleId)
        return AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, asking)
    }

    private func open(_ settingsURL: String) {
        if let url = URL(string: settingsURL) {
            NSWorkspace.shared.open(url)
        }
    }
}
