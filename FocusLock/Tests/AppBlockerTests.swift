import FocusLockCore
import XCTest

final class AppBlockerTests: XCTestCase {
    func testBlockedAppActivationTriggersOverlayDelegateAndHidesApp() {
        let slack = MockRunningApplication(name: "Slack", bundleId: "com.tinyspeck.slackmacgap")
        let monitor = MockActivationMonitor()
        let notifications = NoopNotificationService()
        let delegate = SpyBlockerDelegate()
        let blocker = AppBlocker(
            notificationService: notifications,
            activationMonitor: monitor,
            frontmostApplicationProvider: { nil }
        )
        blocker.delegate = delegate

        blocker.start(
            blockedApps: [BlockedApp(name: "Slack", bundleId: "com.tinyspeck.slackmacgap")],
            blockerMode: .guardScreen
        )

        monitor.fire(slack)

        XCTAssertEqual(slack.hideCallCount, 1)
        XCTAssertTrue(notifications.events.contains("blockedAppHidden:Slack"))
        XCTAssertEqual(delegate.intercepted.map(\.bundleId), ["com.tinyspeck.slackmacgap"])
    }

    func testGuardModeDoesNotTerminateBlockedApps() {
        let slack = MockRunningApplication(name: "Slack", bundleId: "com.tinyspeck.slackmacgap")
        let blocker = AppBlocker(
            notificationService: NoopNotificationService(),
            activationMonitor: MockActivationMonitor(),
            frontmostApplicationProvider: { nil }
        )

        blocker.start(
            blockedApps: [BlockedApp(name: "Slack", bundleId: "com.tinyspeck.slackmacgap")],
            blockerMode: .guardScreen
        )
        _ = blocker.handleActivation(of: slack)

        XCTAssertEqual(slack.hideCallCount, 1)
        XCTAssertEqual(slack.terminateCallCount, 0)
    }

    func testQuitAppModeRequestsTermination() {
        let slack = MockRunningApplication(name: "Slack", bundleId: "com.tinyspeck.slackmacgap")
        let blocker = AppBlocker(
            notificationService: NoopNotificationService(),
            activationMonitor: MockActivationMonitor(),
            frontmostApplicationProvider: { nil }
        )

        blocker.start(
            blockedApps: [BlockedApp(name: "Slack", bundleId: "com.tinyspeck.slackmacgap")],
            blockerMode: .quitApp
        )
        _ = blocker.handleActivation(of: slack)

        XCTAssertEqual(slack.terminateCallCount, 1)
        XCTAssertEqual(slack.hideCallCount, 0)
    }

    func testNonBlockedAppIsIgnored() {
        let finder = MockRunningApplication(name: "Finder", bundleId: "com.apple.finder")
        let safari = MockRunningApplication(name: "Safari", bundleId: "com.apple.Safari")
        let monitor = MockActivationMonitor()
        let blocker = AppBlocker(
            notificationService: NoopNotificationService(),
            activationMonitor: monitor,
            frontmostApplicationProvider: { nil }
        )

        blocker.start(
            blockedApps: [BlockedApp(name: "Slack", bundleId: "com.tinyspeck.slackmacgap")],
            blockerMode: .guardScreen
        )

        monitor.fire(finder)
        monitor.fire(safari)

        XCTAssertEqual(finder.hideCallCount, 0)
        XCTAssertEqual(safari.hideCallCount, 0)
    }

    func testNonBlockedAppActivationUpdatesLastAllowedApplication() {
        let safari = MockRunningApplication(name: "Safari", bundleId: "com.apple.Safari")
        let blocker = AppBlocker(
            notificationService: NoopNotificationService(),
            activationMonitor: MockActivationMonitor(),
            frontmostApplicationProvider: { nil }
        )

        blocker.start(
            blockedApps: [BlockedApp(name: "Slack", bundleId: "com.tinyspeck.slackmacgap")],
            blockerMode: .guardScreen
        )
        _ = blocker.handleActivation(of: safari)

        XCTAssertEqual(blocker.lastAllowedApplication?.name, "Safari")
        XCTAssertEqual(blocker.lastAllowedApplication?.bundleId, "com.apple.Safari")
    }

    func testProtectedAppIsNeverHidden() {
        let finder = MockRunningApplication(name: "Finder", bundleId: "com.apple.finder")
        let monitor = MockActivationMonitor()
        let blocker = AppBlocker(
            notificationService: NoopNotificationService(),
            activationMonitor: monitor,
            frontmostApplicationProvider: { nil }
        )

        // Even if a protected bundle id is somehow on the blocked list, it must not be hidden.
        blocker.start(
            blockedApps: [BlockedApp(name: "Finder", bundleId: "com.apple.finder")],
            blockerMode: .guardScreen
        )

        monitor.fire(finder)

        XCTAssertEqual(finder.hideCallCount, 0)
    }

    func testTemporaryAllowancePreventsOverlayForFiveMinutes() {
        let slack = MockRunningApplication(name: "Slack", bundleId: "com.tinyspeck.slackmacgap")
        let monitor = MockActivationMonitor()
        let blocker = AppBlocker(
            notificationService: NoopNotificationService(),
            activationMonitor: monitor,
            frontmostApplicationProvider: { nil }
        )

        blocker.start(
            blockedApps: [BlockedApp(name: "Slack", bundleId: "com.tinyspeck.slackmacgap")],
            blockerMode: .guardScreen
        )

        let now = Date()
        blocker.allowTemporarily(bundleId: "com.tinyspeck.slackmacgap", duration: 300, now: now)

        // Within the allowance window: ignored.
        XCTAssertNil(blocker.handleActivation(of: slack, now: now.addingTimeInterval(60)))
        XCTAssertEqual(slack.hideCallCount, 0)

        XCTAssertNil(blocker.handleActivation(of: slack, now: now.addingTimeInterval(299)))
        XCTAssertEqual(slack.hideCallCount, 0)
    }

    func testTemporaryAllowanceExpires() {
        let slack = MockRunningApplication(name: "Slack", bundleId: "com.tinyspeck.slackmacgap")
        let blocker = AppBlocker(
            notificationService: NoopNotificationService(),
            activationMonitor: MockActivationMonitor(),
            frontmostApplicationProvider: { nil }
        )

        blocker.start(
            blockedApps: [BlockedApp(name: "Slack", bundleId: "com.tinyspeck.slackmacgap")],
            blockerMode: .guardScreen
        )

        let now = Date()
        blocker.allowTemporarily(bundleId: "com.tinyspeck.slackmacgap", duration: 300, now: now)

        XCTAssertNotNil(blocker.handleActivation(of: slack, now: now.addingTimeInterval(301)))
        XCTAssertEqual(slack.hideCallCount, 1)
    }

    func testBlockedDockActivationSchedulesFollowUpHideRetry() {
        let discord = MockRunningApplication(name: "Discord", bundleId: "com.hnc.Discord")
        var scheduled: [ScheduledWork] = []
        let blocker = AppBlocker(
            notificationService: NoopNotificationService(),
            activationMonitor: MockActivationMonitor(),
            frontmostApplicationProvider: { nil },
            scheduleAfter: { delay, work in scheduled.append(ScheduledWork(delay: delay, work: work)) }
        )

        blocker.start(
            blockedApps: [BlockedApp(name: "Discord", bundleId: "com.hnc.Discord")],
            blockerMode: .guardScreen
        )

        _ = blocker.handleActivation(of: discord)
        XCTAssertEqual(discord.hideCallCount, 1)

        let hideRetries = scheduled.filter { $0.delay < 1 }
        XCTAssertFalse(hideRetries.isEmpty)

        hideRetries.forEach { $0.work() }
        XCTAssertGreaterThan(discord.hideCallCount, 1)
    }

    func testFollowUpHideRetryDoesNotHideTemporarilyAllowedApp() {
        let discord = MockRunningApplication(name: "Discord", bundleId: "com.hnc.Discord")
        var scheduled: [ScheduledWork] = []
        let blocker = AppBlocker(
            notificationService: NoopNotificationService(),
            activationMonitor: MockActivationMonitor(),
            frontmostApplicationProvider: { nil },
            scheduleAfter: { delay, work in scheduled.append(ScheduledWork(delay: delay, work: work)) }
        )

        blocker.start(
            blockedApps: [BlockedApp(name: "Discord", bundleId: "com.hnc.Discord")],
            blockerMode: .guardScreen
        )

        _ = blocker.handleActivation(of: discord)
        let hideRetries = scheduled.filter { $0.delay < 1 }
        XCTAssertFalse(hideRetries.isEmpty)

        blocker.allowTemporarily(bundleId: "com.hnc.Discord", duration: 300)
        hideRetries.forEach { $0.work() }

        XCTAssertEqual(discord.hideCallCount, 1)
    }

    func testExpiredAllowanceReGuardsAppThatStaysFrontmost() {
        let slack = MockRunningApplication(name: "Slack", bundleId: "com.tinyspeck.slackmacgap")
        var scheduled: [ScheduledWork] = []
        let blocker = AppBlocker(
            notificationService: NoopNotificationService(),
            activationMonitor: MockActivationMonitor(),
            frontmostApplicationProvider: { slack },
            scheduleAfter: { delay, work in scheduled.append(ScheduledWork(delay: delay, work: work)) }
        )

        blocker.start(
            blockedApps: [BlockedApp(name: "Slack", bundleId: "com.tinyspeck.slackmacgap")],
            blockerMode: .guardScreen
        )

        // Slack is frontmost when focus begins, so it is hidden once up front.
        XCTAssertEqual(slack.hideCallCount, 1)

        // User clicks "Allow 5 minutes" and stays inside Slack (no new activation).
        blocker.allowTemporarily(bundleId: "com.tinyspeck.slackmacgap", duration: 300)
        let allowanceExpiries = scheduled.filter { $0.delay == 300 }
        XCTAssertEqual(allowanceExpiries.count, 1)

        // The five-minute window elapses with Slack still frontmost.
        allowanceExpiries.forEach { $0.work() }

        // The app must be guarded again without requiring a fresh activation event.
        XCTAssertEqual(slack.hideCallCount, 2)
    }

    func testExpiredAllowanceDoesNotReGuardWhenUserLeftTheApp() {
        let slack = MockRunningApplication(name: "Slack", bundleId: "com.tinyspeck.slackmacgap")
        let safari = MockRunningApplication(name: "Safari", bundleId: "com.apple.Safari")
        var frontmost: RunningApplicationRepresenting = slack
        var scheduled: [ScheduledWork] = []
        let blocker = AppBlocker(
            notificationService: NoopNotificationService(),
            activationMonitor: MockActivationMonitor(),
            frontmostApplicationProvider: { frontmost },
            scheduleAfter: { delay, work in scheduled.append(ScheduledWork(delay: delay, work: work)) }
        )

        blocker.start(
            blockedApps: [BlockedApp(name: "Slack", bundleId: "com.tinyspeck.slackmacgap")],
            blockerMode: .guardScreen
        )
        XCTAssertEqual(slack.hideCallCount, 1)

        blocker.allowTemporarily(bundleId: "com.tinyspeck.slackmacgap", duration: 300)

        // The user moved on to a non-blocked app before the window elapsed.
        frontmost = safari
        scheduled.filter { $0.delay == 300 }.forEach { $0.work() }

        XCTAssertEqual(slack.hideCallCount, 1)
    }

    func testRenewedAllowanceIsNotCancelledByStaleExpiryTimer() {
        let slack = MockRunningApplication(name: "Slack", bundleId: "com.tinyspeck.slackmacgap")
        var scheduled: [ScheduledWork] = []
        let blocker = AppBlocker(
            notificationService: NoopNotificationService(),
            activationMonitor: MockActivationMonitor(),
            frontmostApplicationProvider: { slack },
            scheduleAfter: { delay, work in scheduled.append(ScheduledWork(delay: delay, work: work)) }
        )

        blocker.start(
            blockedApps: [BlockedApp(name: "Slack", bundleId: "com.tinyspeck.slackmacgap")],
            blockerMode: .guardScreen
        )
        XCTAssertEqual(slack.hideCallCount, 1)

        blocker.allowTemporarily(bundleId: "com.tinyspeck.slackmacgap", duration: 300)
        // User renews the allowance before the first window elapses.
        blocker.allowTemporarily(bundleId: "com.tinyspeck.slackmacgap", duration: 300)
        let allowanceExpiries = scheduled.filter { $0.delay == 300 }
        XCTAssertEqual(allowanceExpiries.count, 2)

        // The first (now stale) timer fires: it must not re-guard the app.
        allowanceExpiries[0].work()
        XCTAssertEqual(slack.hideCallCount, 1)

        // The renewed timer fires: now the app is guarded again.
        allowanceExpiries[1].work()
        XCTAssertEqual(slack.hideCallCount, 2)
    }

    func testFrontmostBlockedAppIsHandledOnStart() {
        let slack = MockRunningApplication(name: "Slack", bundleId: "com.tinyspeck.slackmacgap")
        let monitor = MockActivationMonitor()
        let blocker = AppBlocker(
            notificationService: NoopNotificationService(),
            activationMonitor: monitor,
            frontmostApplicationProvider: { slack }
        )

        blocker.start(
            blockedApps: [BlockedApp(name: "Slack", bundleId: "com.tinyspeck.slackmacgap")],
            blockerMode: .guardScreen
        )

        XCTAssertEqual(slack.hideCallCount, 1)
    }

    func testProtectedAppsCannotBeAdded() {
        let result = AppBlocker.validate(
            BlockedApp(name: "Terminal", bundleId: "com.apple.Terminal"),
            existingApps: []
        )

        switch result {
        case .success:
            XCTFail("Terminal should be protected")
        case .failure(let error):
            XCTAssertEqual(error, .protectedApp)
        }
    }

    func testLockInItselfCannotBeAdded() {
        let result = AppBlocker.validate(
            BlockedApp(name: "LockIn", bundleId: "com.lockin.app"),
            existingApps: [],
            ownBundleIdentifier: "com.lockin.app"
        )

        switch result {
        case .success:
            XCTFail("LockIn should not be blockable")
        case .failure(let error):
            XCTAssertEqual(error, .protectedApp)
        }
    }

    func testProtectedBundleIdentifiersAreCaseInsensitive() {
        XCTAssertTrue(AppBlocker.isProtected(bundleId: "com.apple.SystemSettings", name: "System Settings"))
        XCTAssertTrue(AppBlocker.isProtected(bundleId: "com.apple.WindowServer", name: "WindowServer"))
    }

    func testDuplicateBlockedAppsCannotBeAdded() {
        let existing = [BlockedApp(name: "Slack", bundleId: "com.tinyspeck.slackmacgap")]
        let result = AppBlocker.validate(
            BlockedApp(name: "Slack Copy", bundleId: "com.tinyspeck.slackmacgap"),
            existingApps: existing
        )

        switch result {
        case .success:
            XCTFail("Duplicate bundle IDs should fail validation")
        case .failure(let error):
            XCTAssertEqual(error, .duplicateBundleIdentifier)
        }
    }

    func testBlockerRunsOnlyDuringFocusPhase() {
        XCTAssertTrue(AppBlocker.shouldRun(for: .focus))
        XCTAssertFalse(AppBlocker.shouldRun(for: .idle))
        XCTAssertFalse(AppBlocker.shouldRun(for: .break))
        XCTAssertFalse(AppBlocker.shouldRun(for: .paused))
        XCTAssertFalse(AppBlocker.shouldRun(for: .completed))
        XCTAssertFalse(AppBlocker.shouldRun(for: .cancelled))
    }

    func testStopDisablesMonitoring() {
        let monitor = MockActivationMonitor()
        let blocker = AppBlocker(
            notificationService: NoopNotificationService(),
            activationMonitor: monitor,
            frontmostApplicationProvider: { nil }
        )

        blocker.start(
            blockedApps: [BlockedApp(name: "Slack", bundleId: "com.tinyspeck.slackmacgap")],
            blockerMode: .guardScreen
        )
        XCTAssertTrue(blocker.isRunning)
        XCTAssertTrue(monitor.isStarted)

        blocker.stop()

        XCTAssertFalse(blocker.isRunning)
        XCTAssertFalse(monitor.isStarted)

        // Activations after stop are ignored.
        let slack = MockRunningApplication(name: "Slack", bundleId: "com.tinyspeck.slackmacgap")
        monitor.fire(slack)
        XCTAssertEqual(slack.hideCallCount, 0)
    }
}

private struct ScheduledWork {
    let delay: TimeInterval
    let work: () -> Void
}

private final class MockRunningApplication: RunningApplicationRepresenting {
    var localizedName: String?
    var bundleIdentifier: String?
    var hideCallCount = 0
    var terminateCallCount = 0

    init(name: String, bundleId: String) {
        self.localizedName = name
        self.bundleIdentifier = bundleId
    }

    func hide() -> Bool {
        hideCallCount += 1
        return true
    }

    func terminate() -> Bool {
        terminateCallCount += 1
        return true
    }
}

private final class MockActivationMonitor: AppActivationMonitoring {
    var onActivation: ((RunningApplicationRepresenting) -> Void)?
    private(set) var isStarted = false

    func start() {
        isStarted = true
    }

    func stop() {
        isStarted = false
    }

    func fire(_ app: RunningApplicationRepresenting) {
        onActivation?(app)
    }
}

private final class SpyBlockerDelegate: AppBlockerDelegate {
    private(set) var intercepted: [InterceptedApp] = []

    func appBlocker(_ blocker: AppBlocker, didIntercept app: InterceptedApp) {
        intercepted.append(app)
    }
}
