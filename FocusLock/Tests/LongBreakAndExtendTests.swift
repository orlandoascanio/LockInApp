import FocusLockCore
import XCTest

final class LongBreakAndExtendTests: XCTestCase {
    // MARK: Long break cadence

    func testEveryFourthBlockEndsInTheLongBreak() {
        let settings = LongBreakSettings()
        let breaks = (1...9).map { settings.breakMinutes(afterCycle: $0, shortBreak: 5) }
        XCTAssertEqual(breaks, [5, 5, 5, 15, 5, 5, 5, 15, 5])
        XCTAssertEqual((1...9).map(settings.positionInSet(cycle:)), [1, 2, 3, 4, 1, 2, 3, 4, 1])
    }

    func testLongBreakNeverShortensOrAddsABreak() {
        let settings = LongBreakSettings(minutes: 10, every: 2)
        // Someone whose usual break is already longer keeps it.
        XCTAssertEqual(settings.breakMinutes(afterCycle: 2, shortBreak: 20), 20)
        // A run with breaks turned off stays without them.
        XCTAssertEqual(settings.breakMinutes(afterCycle: 2, shortBreak: 0), 0)
    }

    func testTurnedOffMeansEveryBreakIsTheUsualOne() {
        let settings = LongBreakSettings(enabled: false)
        XCTAssertFalse((1...12).contains { settings.isLongBreak(afterCycle: $0) })
    }

    func testOutOfRangeValuesAreClamped() {
        let settings = LongBreakSettings(minutes: 500, every: 1)
        XCTAssertEqual(settings.minutes, 60)
        XCTAssertEqual(settings.every, 2)
    }

    func testConfigWrittenBeforeLongBreaksGetsTheDefaults() throws {
        let json = #"{"focusMinutes": 50, "breakMinutes": 10}"#
        let config = try JSONDecoder().decode(AppConfig.self, from: Data(json.utf8))
        XCTAssertEqual(config.longBreak, LongBreakSettings())
        XCTAssertTrue(config.notchAlertsEnabled)
        XCTAssertEqual(config.breakMinutes, 10)
    }

    func testLongBreakAndNotchSettingsRoundTrip() throws {
        var config = AppConfig()
        config.longBreak = LongBreakSettings(enabled: false, minutes: 30, every: 3)
        config.notchAlertsEnabled = false
        let decoded = try JSONDecoder().decode(AppConfig.self, from: JSONEncoder().encode(config))
        XCTAssertEqual(decoded.longBreak, config.longBreak)
        XCTAssertFalse(decoded.notchAlertsEnabled)
    }

    // MARK: Extending

    func testExtendingFocusPushesTheEndAndTheBreakBack() throws {
        let (engine, history, start) = try makeEngine()
        engine.startFocus(focusMinutes: 25, breakMinutes: 5, blockedAppsCount: 0, strictMode: false, now: start)

        engine.refresh(now: start.addingTimeInterval(24 * 60))
        XCTAssertTrue(engine.extend(byMinutes: 5, now: start.addingTimeInterval(24 * 60)))
        XCTAssertEqual(Int(engine.snapshot.remainingSeconds), 6 * 60)

        // Past the old end, still focusing.
        engine.refresh(now: start.addingTimeInterval(26 * 60))
        XCTAssertEqual(engine.snapshot.phase, .focus)

        engine.refresh(now: start.addingTimeInterval(30 * 60 + 1))
        XCTAssertEqual(engine.snapshot.phase, .break)
        XCTAssertEqual(history.loadHistory().first?.durationMinutes, 30)
        XCTAssertEqual(engine.snapshot.phaseEndsAt, start.addingTimeInterval(35 * 60))
    }

    func testExtendingABreakAddsToIt() throws {
        let (engine, _, start) = try makeEngine()
        engine.startFocus(focusMinutes: 25, breakMinutes: 5, blockedAppsCount: 0, strictMode: false, now: start)
        engine.refresh(now: start.addingTimeInterval(26 * 60))
        XCTAssertEqual(engine.snapshot.phase, .break)

        engine.extend(byMinutes: 5, now: start.addingTimeInterval(26 * 60))
        XCTAssertEqual(engine.snapshot.phaseEndsAt, start.addingTimeInterval(35 * 60))

        engine.refresh(now: start.addingTimeInterval(31 * 60))
        XCTAssertEqual(engine.snapshot.phase, .break)
    }

    func testExtendingAFinishedBreakStartsFiveMoreMinutes() throws {
        let (engine, history, start) = try makeEngine()
        engine.startFocus(focusMinutes: 25, breakMinutes: 5, blockedAppsCount: 0, strictMode: false, cycle: 3, now: start)
        engine.refresh(now: start.addingTimeInterval(40 * 60))
        XCTAssertEqual(engine.snapshot.phase, .breakEnded)

        let later = start.addingTimeInterval(45 * 60)
        engine.extend(byMinutes: 5, now: later)
        XCTAssertEqual(engine.snapshot.phase, .break)
        XCTAssertEqual(engine.snapshot.phaseEndsAt, later.addingTimeInterval(5 * 60))
        XCTAssertEqual(engine.snapshot.currentCycle, 3)
        // The focus block was logged once and the extra break adds nothing.
        XCTAssertEqual(history.loadHistory().count, 1)

        engine.refresh(now: later.addingTimeInterval(5 * 60 + 1))
        XCTAssertEqual(engine.snapshot.phase, .breakEnded)
    }

    func testNothingRunningMeansNothingToExtend() throws {
        let (engine, _, start) = try makeEngine()
        XCTAssertFalse(engine.extend(byMinutes: 5, now: start))
        XCTAssertEqual(engine.snapshot.phase, .idle)
    }

    /// Long runs with extensions dropped in at random points: every block is
    /// logged with its planned length plus whatever was added to it, every
    /// break comes out at the cadence's length plus its extensions, and the
    /// timer never runs backwards.
    func testGeneratedRunsKeepCadenceAndExtensionsConsistent() throws {
        var rng = SeededGenerator(seed: 0x51E7)
        for _ in 0..<40 {
            let (engine, history, start) = try makeEngine()
            let focus = Int.random(in: 1...50, using: &rng)
            let shortBreak = Int.random(in: 1...10, using: &rng)
            let cadence = LongBreakSettings(
                enabled: Bool.random(using: &rng),
                minutes: Int.random(in: 10...30, using: &rng),
                every: Int.random(in: 2...5, using: &rng)
            )
            var now = start
            var expectedFocus: [Int] = []

            for cycle in 1...Int.random(in: 4...12, using: &rng) {
                let plannedBreak = cadence.breakMinutes(afterCycle: cycle, shortBreak: shortBreak)
                engine.startFocus(focusMinutes: focus, breakMinutes: plannedBreak, blockedAppsCount: 0,
                                  strictMode: false, cycle: cycle, now: now)

                var focusAdded = 0
                for _ in 0..<Int.random(in: 0...2, using: &rng) {
                    now += TimeInterval(Int.random(in: 0...(focus * 60 - 1), using: &rng)) / 3
                    engine.refresh(now: now)
                    guard engine.snapshot.phase == .focus else { break }
                    let before = engine.snapshot.phaseEndsAt
                    engine.extend(byMinutes: 5, now: now)
                    focusAdded += 5
                    XCTAssertEqual(engine.snapshot.phaseEndsAt, before.map { $0 + 300 })
                }

                now = engine.snapshot.phaseEndsAt! + 1
                engine.refresh(now: now)
                XCTAssertEqual(engine.snapshot.phase, .break)
                XCTAssertEqual(engine.snapshot.breakMinutes, plannedBreak)
                expectedFocus.append(focus + focusAdded)

                var breakAdded = 0
                if Bool.random(using: &rng) {
                    engine.extend(byMinutes: 5, now: now)
                    breakAdded += 5
                }
                let breakEnds = engine.snapshot.phaseEndsAt!
                XCTAssertEqual(breakEnds.timeIntervalSince(now), TimeInterval((plannedBreak + breakAdded) * 60) - 1, accuracy: 0.001)

                now = breakEnds + 1
                engine.refresh(now: now)
                XCTAssertEqual(engine.snapshot.phase, .breakEnded)
                XCTAssertEqual(engine.snapshot.currentCycle, cycle)
            }

            XCTAssertEqual(history.loadHistory().map(\.focusMinutes).sorted(), expectedFocus.sorted())
            XCTAssertTrue(history.loadHistory().allSatisfy { $0.status == .completed })
        }
    }

    private func makeEngine() throws -> (TimerEngine, SessionHistoryStore, Date) {
        let directory = try temporaryDirectory()
        let history = SessionHistoryStore(baseDirectory: directory)
        let start = Date(timeIntervalSince1970: 10_000)
        let engine = TimerEngine(
            stateStore: StateStore(baseDirectory: directory),
            historyStore: history,
            notificationService: NoopNotificationService(),
            clock: { start }
        )
        return (engine, history, start)
    }
}

/// SplitMix64, so a failing generated run can be replayed exactly.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
