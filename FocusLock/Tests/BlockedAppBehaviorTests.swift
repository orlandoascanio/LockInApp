import FocusLockCore
import XCTest

/// Covers per-app behaviour overrides and the per-app enable toggle that the
/// redesigned blocked-apps table exposes.
final class BlockedAppBehaviorTests: XCTestCase {
    private func makeBlocker(
        delegate: SpyDelegate? = nil,
        onInterception: ((InterceptedApp) -> Void)? = nil
    ) -> AppBlocker {
        let blocker = AppBlocker(
            notificationService: NoopNotifications(),
            activationMonitor: StubMonitor(),
            frontmostApplicationProvider: { nil }
        )
        blocker.delegate = delegate
        blocker.onInterception = onInterception
        return blocker
    }

    func testPerAppOverrideWinsOverTheGlobalBehavior() {
        let slack = StubApp(name: "Slack", bundleId: "com.tinyspeck.slackmacgap")
        let blocker = makeBlocker()

        blocker.start(
            blockedApps: [
                BlockedApp(name: "Slack", bundleId: "com.tinyspeck.slackmacgap", behavior: .quitApp)
            ],
            blockerMode: .guardScreen
        )
        _ = blocker.handleActivation(of: slack)

        XCTAssertEqual(slack.terminateCallCount, 1, "the app's own Quit App override should apply")
        XCTAssertEqual(slack.hideCallCount, 0)
    }

    func testAppWithoutOverrideFollowsTheGlobalBehavior() {
        let slack = StubApp(name: "Slack", bundleId: "com.tinyspeck.slackmacgap")
        let blocker = makeBlocker()

        blocker.start(
            blockedApps: [BlockedApp(name: "Slack", bundleId: "com.tinyspeck.slackmacgap")],
            blockerMode: .quitApp
        )
        _ = blocker.handleActivation(of: slack)

        XCTAssertEqual(slack.terminateCallCount, 1)
    }

    func testHideOnlyOverrideSuppressesTheGuardScreen() {
        let slack = StubApp(name: "Slack", bundleId: "com.tinyspeck.slackmacgap")
        let delegate = SpyDelegate()
        let blocker = makeBlocker(delegate: delegate)

        blocker.start(
            blockedApps: [
                BlockedApp(name: "Slack", bundleId: "com.tinyspeck.slackmacgap", behavior: .hideOnly)
            ],
            blockerMode: .guardScreen
        )
        _ = blocker.handleActivation(of: slack)

        XCTAssertEqual(slack.hideCallCount, 1)
        XCTAssertTrue(delegate.intercepted.isEmpty, "hide-only must not raise the guard screen")
    }

    func testDisabledAppIsNotGuarded() {
        let slack = StubApp(name: "Slack", bundleId: "com.tinyspeck.slackmacgap")
        let blocker = makeBlocker()

        blocker.start(
            blockedApps: [
                BlockedApp(name: "Slack", bundleId: "com.tinyspeck.slackmacgap", isEnabled: false)
            ],
            blockerMode: .guardScreen
        )
        let intercepted = blocker.handleActivation(of: slack)

        XCTAssertNil(intercepted)
        XCTAssertEqual(slack.hideCallCount, 0)
        XCTAssertEqual(slack.terminateCallCount, 0)
    }

    func testDisabledAppCountsAsTheLastAllowedApplication() {
        let slack = StubApp(name: "Slack", bundleId: "com.tinyspeck.slackmacgap")
        let blocker = makeBlocker()

        blocker.start(
            blockedApps: [
                BlockedApp(name: "Slack", bundleId: "com.tinyspeck.slackmacgap", isEnabled: false)
            ],
            blockerMode: .guardScreen
        )
        _ = blocker.handleActivation(of: slack)

        XCTAssertEqual(blocker.lastAllowedApplication?.bundleId, "com.tinyspeck.slackmacgap")
    }

    func testInterceptionCallbackFiresForEveryBehaviorNotJustGuardScreen() {
        var intercepted: [String] = []
        let blocker = makeBlocker(onInterception: { intercepted.append($0.bundleId) })

        blocker.start(
            blockedApps: [
                BlockedApp(name: "Slack", bundleId: "com.tinyspeck.slackmacgap", behavior: .hideOnly),
                BlockedApp(name: "Mail", bundleId: "com.example.mail", behavior: .quitApp)
            ],
            blockerMode: .guardScreen
        )

        _ = blocker.handleActivation(of: StubApp(name: "Slack", bundleId: "com.tinyspeck.slackmacgap"))
        _ = blocker.handleActivation(of: StubApp(name: "Mail", bundleId: "com.example.mail"))

        XCTAssertEqual(intercepted, ["com.tinyspeck.slackmacgap", "com.example.mail"])
    }

    // MARK: Persistence

    func testBlockedAppDecodesWithoutBehaviorOrEnabledFields() throws {
        // Entries written before per-app overrides existed.
        let json = Data(#"{"name":"Slack","bundleId":"com.tinyspeck.slackmacgap"}"#.utf8)

        let app = try JSONDecoder().decode(BlockedApp.self, from: json)

        XCTAssertNil(app.behavior)
        XCTAssertTrue(app.isEnabled)
        XCTAssertEqual(app.effectiveBehavior(default: .quitApp), .quitApp)
    }

    func testBlockedAppRoundTripsOverrideAndEnabledFlag() throws {
        let app = BlockedApp(
            name: "Slack",
            bundleId: "com.tinyspeck.slackmacgap",
            behavior: .hideOnly,
            isEnabled: false
        )

        let data = try JSONEncoder().encode(app)
        let decoded = try JSONDecoder().decode(BlockedApp.self, from: data)

        XCTAssertEqual(decoded, app)
        XCTAssertEqual(decoded.effectiveBehavior(default: .guardScreen), .hideOnly)
    }

    func testConfigDefaultsPinnedHUDOnForExistingInstalls() throws {
        let json = Data(#"{"focusMinutes":25,"breakMinutes":5}"#.utf8)

        let config = try JSONDecoder().decode(AppConfig.self, from: json)

        XCTAssertTrue(config.pinnedHUDEnabled)
    }
}

// MARK: - Doubles

private final class StubApp: RunningApplicationRepresenting {
    var localizedName: String?
    var bundleIdentifier: String?
    var hideCallCount = 0
    var terminateCallCount = 0

    init(name: String, bundleId: String) {
        localizedName = name
        bundleIdentifier = bundleId
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

private final class StubMonitor: AppActivationMonitoring {
    var onActivation: ((RunningApplicationRepresenting) -> Void)?
    func start() {}
    func stop() {}
}

private final class NoopNotifications: NotificationSending {
    func requestAuthorization() {}
    func audienceTasksWaiting(count: Int) {}
    func focusStarted(minutes: Int) {}
    func focusCompleted() {}
    func breakStarted(minutes: Int) {}
    func breakEnded() {}
    func sessionCancelled() {}
    func blockedAppHidden(name: String) {}
}

private final class SpyDelegate: AppBlockerDelegate {
    private(set) var intercepted: [InterceptedApp] = []

    func appBlocker(_ blocker: AppBlocker, didIntercept app: InterceptedApp) {
        intercepted.append(app)
    }
}
