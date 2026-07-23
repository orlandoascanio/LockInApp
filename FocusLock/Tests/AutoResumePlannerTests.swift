import FocusLockCore
import XCTest

final class AutoResumePlannerTests: XCTestCase {
    private let breakEndedAt = Date(timeIntervalSince1970: 10_000)

    func testWaitsOutTheGracePeriodBeforeCountingDown() {
        let planner = AutoResumePlanner(graceMinutes: 10, countdownSeconds: 60)

        XCTAssertEqual(
            planner.stage(since: breakEndedAt, now: breakEndedAt),
            .waiting(secondsUntilCountdown: 600)
        )
        XCTAssertEqual(
            planner.stage(since: breakEndedAt, now: breakEndedAt.addingTimeInterval(599)),
            .waiting(secondsUntilCountdown: 1)
        )
    }

    func testCountsDownOnceGraceIsSpent() {
        let planner = AutoResumePlanner(graceMinutes: 10, countdownSeconds: 60)

        XCTAssertEqual(
            planner.stage(since: breakEndedAt, now: breakEndedAt.addingTimeInterval(600)),
            .countdown(secondsRemaining: 60)
        )
        XCTAssertEqual(
            planner.stage(since: breakEndedAt, now: breakEndedAt.addingTimeInterval(645)),
            .countdown(secondsRemaining: 15)
        )
    }

    func testStartsWhenTheCountdownRunsOut() {
        let planner = AutoResumePlanner(graceMinutes: 10, countdownSeconds: 60)

        XCTAssertEqual(planner.stage(since: breakEndedAt, now: breakEndedAt.addingTimeInterval(660)), .start)
        XCTAssertEqual(planner.stage(since: breakEndedAt, now: breakEndedAt.addingTimeInterval(4_000)), .start)
    }

    /// "Not yet" moves the anchor, which has to buy a full grace period again.
    func testPostponingRestartsTheWait() {
        let planner = AutoResumePlanner(graceMinutes: 10, countdownSeconds: 60)
        let postponedAt = breakEndedAt.addingTimeInterval(610)

        XCTAssertEqual(
            planner.stage(since: postponedAt, now: postponedAt.addingTimeInterval(1)),
            .waiting(secondsUntilCountdown: 599)
        )
        XCTAssertTrue(planner.stage(since: postponedAt, now: postponedAt.addingTimeInterval(601)).isCountdown)
    }

    func testClockRunningBackwardsIsTreatedAsNoTimePassed() {
        let planner = AutoResumePlanner(graceMinutes: 10, countdownSeconds: 60)

        XCTAssertEqual(
            planner.stage(since: breakEndedAt, now: breakEndedAt.addingTimeInterval(-500)),
            .waiting(secondsUntilCountdown: 600)
        )
    }

    func testDurationsAreClampedToSaneRanges() {
        XCTAssertEqual(AutoResumePlanner(graceMinutes: 0, countdownSeconds: 0).graceMinutes, 1)
        XCTAssertEqual(AutoResumePlanner(graceMinutes: 0, countdownSeconds: 0).countdownSeconds, 10)
        XCTAssertEqual(AutoResumePlanner(graceMinutes: 9_000, countdownSeconds: 9_000).graceMinutes, 120)
        XCTAssertEqual(AutoResumePlanner(graceMinutes: 9_000, countdownSeconds: 9_000).countdownSeconds, 600)
    }

    func testCountdownProgressFillsAsTimeRunsOut() {
        let planner = AutoResumePlanner(graceMinutes: 10, countdownSeconds: 60)

        XCTAssertEqual(planner.countdownProgress(remainingSeconds: 60), 0, accuracy: 0.001)
        XCTAssertEqual(planner.countdownProgress(remainingSeconds: 30), 0.5, accuracy: 0.001)
        XCTAssertEqual(planner.countdownProgress(remainingSeconds: 0), 1, accuracy: 0.001)
    }

    // MARK: Snapshot plumbing

    func testBreakEndedSnapshotExposesWhenTheBreakRanOut() {
        let startedAt = Date(timeIntervalSince1970: 5_000)
        let snapshot = TimerSnapshot(
            phase: .breakEnded,
            sessionStartedAt: startedAt,
            focusMinutes: 50,
            breakMinutes: 10
        )

        XCTAssertEqual(snapshot.breakEndedAt, startedAt.addingTimeInterval(3_600))
    }

    func testOtherPhasesHaveNoBreakEndedTimestamp() {
        let snapshot = TimerSnapshot(
            phase: .focus,
            sessionStartedAt: Date(timeIntervalSince1970: 5_000),
            focusMinutes: 50,
            breakMinutes: 10
        )

        XCTAssertNil(snapshot.breakEndedAt)
    }

    // MARK: Config migration

    func testLegacyAutoStartFlagBecomesStartImmediately() throws {
        let legacy = Data(#"{"focusMinutes":45,"breakMinutes":10,"autoStartFocusAfterBreak":true}"#.utf8)
        let config = try JSONDecoder().decode(AppConfig.self, from: legacy)

        XCTAssertEqual(config.breakEndBehavior, .startImmediately)
        XCTAssertEqual(config.autoResume, .default)
    }

    func testLegacyConfigWithoutAutoStartKeepsAsking() throws {
        let legacy = Data(#"{"focusMinutes":25,"breakMinutes":5}"#.utf8)
        let config = try JSONDecoder().decode(AppConfig.self, from: legacy)

        XCTAssertEqual(config.breakEndBehavior, .ask)
    }

    func testAutopilotSettingsSurviveARoundTrip() throws {
        var config = AppConfig()
        config.breakEndBehavior = .autopilot
        config.autoResume = AutoResumePlanner(graceMinutes: 20, countdownSeconds: 300)

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)

        XCTAssertEqual(decoded.breakEndBehavior, .autopilot)
        XCTAssertEqual(decoded.autoResume.graceMinutes, 20)
        XCTAssertEqual(decoded.autoResume.countdownSeconds, 300)
    }
}
