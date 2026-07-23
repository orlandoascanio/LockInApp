import AppKit
import Foundation

public protocol RunningApplicationRepresenting: AnyObject {
    var localizedName: String? { get }
    var bundleIdentifier: String? { get }

    @discardableResult
    func hide() -> Bool

    @discardableResult
    func terminate() -> Bool
}

extension NSRunningApplication: RunningApplicationRepresenting {}

/// Observes the OS-level "an application became frontmost" event.
///
/// Replacing the old 1 Hz polling loop with this push-based source removes the
/// fixed latency/CPU cost of polling and lets the blocker react the instant a
/// blocked app is activated.
public protocol AppActivationMonitoring: AnyObject {
    var onActivation: ((RunningApplicationRepresenting) -> Void)? { get set }
    func start()
    func stop()
}

public final class WorkspaceActivationMonitor: AppActivationMonitoring {
    public var onActivation: ((RunningApplicationRepresenting) -> Void)?

    private let workspace: NSWorkspace
    private var token: NSObjectProtocol?

    public init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    public func start() {
        guard token == nil else {
            return
        }

        token = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            else {
                return
            }
            self?.onActivation?(app)
        }
    }

    public func stop() {
        if let token {
            workspace.notificationCenter.removeObserver(token)
        }
        token = nil
    }

    deinit {
        stop()
    }
}

public enum BlockedAppValidationError: LocalizedError, Equatable {
    case missingBundleIdentifier
    case protectedApp
    case duplicateBundleIdentifier

    public var errorDescription: String? {
        switch self {
        case .missingBundleIdentifier:
            return "Could not read this app's bundle identifier."
        case .protectedApp:
            return "This app cannot be blocked because it is required by macOS."
        case .duplicateBundleIdentifier:
            return "This app is already in your blocked list."
        }
    }
}

public struct InterceptedApp: Equatable {
    public var name: String
    public var bundleId: String

    public init(name: String, bundleId: String) {
        self.name = name
        self.bundleId = bundleId
    }
}

public protocol AppBlockerDelegate: AnyObject {
    /// Called (on the main thread) the moment a blocked app is activated and
    /// hidden. The app process keeps running — only its windows are hidden — so
    /// camera, microphone, and screen-share sessions survive.
    func appBlocker(_ blocker: AppBlocker, didIntercept app: InterceptedApp)
}

public final class AppBlocker {
    public typealias FrontmostApplicationProvider = () -> RunningApplicationRepresenting?

    /// Schedules `work` to run after `delay` seconds. Injected so tests can drive
    /// expiry deterministically instead of waiting on a real timer.
    public typealias DelayedScheduler = (_ delay: TimeInterval, _ work: @escaping () -> Void) -> Void

    public static let protectedBundleIdentifiers: Set<String> = [
        "com.apple.finder",
        "com.apple.dock",
        "com.apple.systempreferences",
        "com.apple.systemsettings",
        "com.apple.terminal",
        "com.apple.loginwindow",
        "com.apple.windowserver",
        AppIdentity.bundleIdentifier,
        AppIdentity.legacyBundleIdentifier
    ]

    public static let protectedNames: Set<String> = [
        "Finder",
        "Dock",
        "System Settings",
        "System Preferences",
        "Terminal",
        "loginwindow",
        "WindowServer",
        AppIdentity.name,
        AppIdentity.legacyName
    ]

    public weak var delegate: AppBlockerDelegate?

    /// Fires for every interception regardless of behaviour, so the UI can count
    /// how often each app was reached for today. `delegate` only fires for
    /// guard-screen mode, which would undercount hide-only and quit apps.
    public var onInterception: ((InterceptedApp) -> Void)?

    private let activationMonitor: AppActivationMonitoring
    private let frontmostApplicationProvider: FrontmostApplicationProvider
    private let notificationService: NotificationSending
    private let ownBundleIdentifier: String
    private let scheduleAfter: DelayedScheduler

    private var isActive = false
    private var blockedApps: [BlockedApp] = []
    private var blockerMode: BlockerMode = .guardScreen

    public private(set) var lastAllowedApplication: InterceptedApp?

    /// bundleId -> expiry date for temporary "allow 5 minutes" grants.
    private var temporaryAllowances: [String: Date] = [:]

    /// bundleId -> monotonically increasing token identifying the latest grant,
    /// so a stale expiry timer cannot cancel a freshly renewed allowance.
    private var allowanceTokens: [String: Int] = [:]

    private static let postInterceptionHideRetryDelays: [TimeInterval] = [0.15, 0.45]

    public var isRunning: Bool {
        isActive
    }

    public init(
        notificationService: NotificationSending,
        activationMonitor: AppActivationMonitoring = WorkspaceActivationMonitor(),
        frontmostApplicationProvider: @escaping FrontmostApplicationProvider = {
            NSWorkspace.shared.frontmostApplication
        },
        ownBundleIdentifier: String = Bundle.main.bundleIdentifier ?? AppIdentity.bundleIdentifier,
        scheduleAfter: @escaping DelayedScheduler = { delay, work in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    ) {
        self.notificationService = notificationService
        self.activationMonitor = activationMonitor
        self.frontmostApplicationProvider = frontmostApplicationProvider
        self.ownBundleIdentifier = ownBundleIdentifier
        self.scheduleAfter = scheduleAfter
    }

    deinit {
        stop()
    }

    public func start(blockedApps: [BlockedApp], blockerMode: BlockerMode) {
        self.blockedApps = blockedApps
        self.blockerMode = blockerMode

        guard !isActive else {
            return
        }

        isActive = true
        temporaryAllowances.removeAll()
        allowanceTokens.removeAll()

        FocusLockLog.debug("blocker started (event-driven) with \(blockedApps.count) blocked app(s), mode=\(blockerMode.rawValue)")

        activationMonitor.onActivation = { [weak self] app in
            self?.handleActivation(of: app)
        }
        activationMonitor.start()

        // A blocked app may already be frontmost when focus begins; no activation
        // event will fire for it, so handle it once up front.
        if let frontmost = frontmostApplicationProvider() {
            handleActivation(of: frontmost)
        }
    }

    public func update(blockedApps: [BlockedApp], blockerMode: BlockerMode) {
        self.blockedApps = blockedApps
        self.blockerMode = blockerMode
    }

    public func stop() {
        if isActive {
            FocusLockLog.debug("blocker stopped")
        }
        activationMonitor.onActivation = nil
        activationMonitor.stop()
        isActive = false
        temporaryAllowances.removeAll()
        allowanceTokens.removeAll()
    }

    /// Temporarily stop intercepting a single app (the overlay's "Allow N minutes").
    ///
    /// Schedules a re-guard at the end of the allowance so an app the user keeps
    /// frontmost is intercepted again when the window expires, even though no new
    /// activation event fires while the app stays in the foreground.
    public func allowTemporarily(bundleId: String, duration: TimeInterval, now: Date = Date()) {
        temporaryAllowances[bundleId] = now.addingTimeInterval(duration)

        let token = (allowanceTokens[bundleId] ?? 0) + 1
        allowanceTokens[bundleId] = token

        FocusLockLog.debug("temporary allowance granted for \(bundleId) (\(Int(duration))s)")

        scheduleAfter(duration) { [weak self] in
            self?.enforceExpiredAllowance(for: bundleId, token: token)
        }
    }

    /// Invoked when an allowance window elapses. Re-guards the app if it is still
    /// the frontmost app and this is the most recent allowance for it.
    private func enforceExpiredAllowance(for bundleId: String, token: Int) {
        guard isActive else {
            return
        }

        // A newer "Allow" grant superseded this one; let its own timer handle it.
        guard allowanceTokens[bundleId] == token else {
            return
        }

        temporaryAllowances[bundleId] = nil
        allowanceTokens[bundleId] = nil

        guard
            let frontmost = frontmostApplicationProvider(),
            frontmost.bundleIdentifier == bundleId
        else {
            return
        }

        FocusLockLog.debug("temporary allowance expired; re-guarding \(bundleId)")
        handleActivation(of: frontmost)
    }

    /// Core interception logic. Exposed for testing and driven in production by
    /// the activation monitor.
    @discardableResult
    public func handleActivation(of app: RunningApplicationRepresenting, now: Date = Date()) -> InterceptedApp? {
        guard isActive else {
            return nil
        }

        guard let bundleId = app.bundleIdentifier else {
            return nil
        }

        // A disabled entry stays in the list but is not guarded, so it counts as
        // an allowed app rather than one that is silently skipped.
        guard let blockedApp = blockedApps.first(where: { $0.bundleId == bundleId && $0.isEnabled }) else {
            lastAllowedApplication = InterceptedApp(
                name: app.localizedName ?? bundleId,
                bundleId: bundleId
            )
            return nil
        }

        let name = app.localizedName ?? blockedApp.name
        let mode = blockedApp.effectiveBehavior(default: blockerMode)

        guard !Self.isProtected(bundleId: bundleId, name: name, ownBundleIdentifier: ownBundleIdentifier) else {
            return nil
        }

        if hasActiveTemporaryAllowance(for: bundleId, now: now) {
            return nil
        }

        switch mode {
        case .guardScreen, .hideOnly:
            _ = app.hide()
            schedulePostInterceptionHideRetries(for: app, bundleId: bundleId, name: name)
            FocusLockLog.debug("blocked app hidden: \(name) (\(bundleId)), mode=\(mode.rawValue)")
        case .quitApp:
            if !app.terminate() {
                _ = app.hide()
            }
            FocusLockLog.debug("blocked app quit requested: \(name) (\(bundleId))")
        }

        notificationService.blockedAppHidden(name: name)

        let intercepted = InterceptedApp(name: name, bundleId: bundleId)
        onInterception?(intercepted)

        if mode == .guardScreen {
            delegate?.appBlocker(self, didIntercept: intercepted)
        }
        return intercepted
    }

    private func hasActiveTemporaryAllowance(for bundleId: String, now: Date) -> Bool {
        guard let expiry = temporaryAllowances[bundleId] else {
            return false
        }

        if expiry > now {
            return true
        }

        temporaryAllowances[bundleId] = nil
        allowanceTokens[bundleId] = nil
        return false
    }

    private func schedulePostInterceptionHideRetries(
        for app: RunningApplicationRepresenting,
        bundleId: String,
        name: String
    ) {
        for delay in Self.postInterceptionHideRetryDelays {
            scheduleAfter(delay) { [weak self, weak app] in
                guard let app else {
                    return
                }
                self?.retryHideBlockedApp(app, bundleId: bundleId, name: name)
            }
        }
    }

    private func retryHideBlockedApp(
        _ app: RunningApplicationRepresenting,
        bundleId: String,
        name: String
    ) {
        guard isActive else {
            return
        }

        guard app.bundleIdentifier == bundleId else {
            return
        }

        guard let blockedApp = blockedApps.first(where: { $0.bundleId == bundleId && $0.isEnabled }) else {
            return
        }

        switch blockedApp.effectiveBehavior(default: blockerMode) {
        case .guardScreen, .hideOnly:
            break
        case .quitApp:
            return
        }

        guard !hasActiveTemporaryAllowance(for: bundleId, now: Date()) else {
            return
        }

        _ = app.hide()
        FocusLockLog.debug("blocked app re-hidden after activation retry: \(name) (\(bundleId))")
    }

    public static func shouldRun(for phase: SessionPhase) -> Bool {
        phase == .focus
    }

    public static func validate(
        _ app: BlockedApp,
        existingApps: [BlockedApp],
        ownBundleIdentifier: String = Bundle.main.bundleIdentifier ?? AppIdentity.bundleIdentifier
    ) -> Result<Void, BlockedAppValidationError> {
        guard !app.bundleId.isEmpty else {
            return .failure(.missingBundleIdentifier)
        }

        guard !isProtected(bundleId: app.bundleId, name: app.name, ownBundleIdentifier: ownBundleIdentifier) else {
            return .failure(.protectedApp)
        }

        guard !existingApps.contains(where: { $0.bundleId == app.bundleId }) else {
            return .failure(.duplicateBundleIdentifier)
        }

        return .success(())
    }

    public static func isProtected(
        bundleId: String,
        name: String?,
        ownBundleIdentifier: String = Bundle.main.bundleIdentifier ?? AppIdentity.bundleIdentifier
    ) -> Bool {
        let normalizedBundleId = bundleId.lowercased()
        let normalizedOwnBundleIdentifier = ownBundleIdentifier.lowercased()

        if normalizedBundleId == normalizedOwnBundleIdentifier {
            return true
        }

        if protectedBundleIdentifiers.contains(normalizedBundleId) {
            return true
        }

        guard let name else {
            return false
        }

        return protectedNames.contains(name.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
