import FocusLockCore
import XCTest

final class TimerEngineTests: XCTestCase {
    func testFocusTransitionsToBreakThenBreakEndedAndSavesFocusHistory() throws {
        let directory = try temporaryDirectory()
        let stateStore = StateStore(baseDirectory: directory)
        let historyStore = SessionHistoryStore(baseDirectory: directory)
        let notifications = NoopNotificationService()
        let start = Date(timeIntervalSince1970: 1_000)
        let engine = TimerEngine(
            stateStore: stateStore,
            historyStore: historyStore,
            notificationService: notifications,
            clock: { start }
        )

        engine.startFocus(
            focusMinutes: 25,
            breakMinutes: 5,
            blockedAppsCount: 3,
            strictMode: true,
            now: start
        )

        XCTAssertEqual(engine.snapshot.phase, .focus)
        XCTAssertEqual(Int(engine.snapshot.remainingSeconds), 1_500)

        engine.refresh(now: start.addingTimeInterval(1_501))

        XCTAssertEqual(engine.snapshot.phase, .break)
        XCTAssertEqual(historyStore.loadHistory().count, 1)
        XCTAssertEqual(historyStore.loadHistory().first?.durationMinutes, 25)

        engine.refresh(now: start.addingTimeInterval(1_801))

        XCTAssertEqual(engine.snapshot.phase, .breakEnded)
        XCTAssertEqual(stateStore.loadSessionState()?.state, .breakEnded)

        let history = historyStore.loadHistory()
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.status, .completed)
        XCTAssertEqual(history.first?.durationMinutes, 25)
        XCTAssertEqual(history.first?.blockedAppsCount, 3)
        XCTAssertEqual(history.first?.strictMode, true)
        XCTAssertTrue(notifications.events.contains("breakEnded"))
    }

    func testRecoveryUsesSavedStartTimeInsteadOfMemoryCountdown() throws {
        let directory = try temporaryDirectory()
        let stateStore = StateStore(baseDirectory: directory)
        let historyStore = SessionHistoryStore(baseDirectory: directory)
        let notifications = NoopNotificationService()
        let start = Date(timeIntervalSince1970: 2_000)

        try stateStore.saveSessionState(SessionState(
            state: .focus,
            startedAt: start,
            focusMinutes: 25,
            breakMinutes: 5
        ))

        let engine = TimerEngine(
            stateStore: stateStore,
            historyStore: historyStore,
            notificationService: notifications,
            clock: { start.addingTimeInterval(600) }
        )

        XCTAssertEqual(engine.snapshot.phase, .focus)
        XCTAssertEqual(Int(engine.snapshot.remainingSeconds), 900)
    }

    func testRecoveryOfExpiredBreakShowsBreakEndedState() throws {
        let directory = try temporaryDirectory()
        let stateStore = StateStore(baseDirectory: directory)
        let historyStore = SessionHistoryStore(baseDirectory: directory)
        let notifications = NoopNotificationService()
        let start = Date(timeIntervalSince1970: 3_000)

        try stateStore.saveSessionState(SessionState(
            state: .focus,
            startedAt: start,
            focusMinutes: 25,
            breakMinutes: 5,
            blockedAppsCount: 2,
            strictMode: false
        ))

        let engine = TimerEngine(
            stateStore: stateStore,
            historyStore: historyStore,
            notificationService: notifications,
            clock: { start.addingTimeInterval(2_000) }
        )

        XCTAssertEqual(engine.snapshot.phase, .breakEnded)
        XCTAssertEqual(stateStore.loadSessionState()?.state, .breakEnded)
        XCTAssertEqual(historyStore.loadHistory().first?.status, .completed)
    }

    func testCancelCreatesCancelledHistoryEntry() throws {
        let directory = try temporaryDirectory()
        let stateStore = StateStore(baseDirectory: directory)
        let historyStore = SessionHistoryStore(baseDirectory: directory)
        let notifications = NoopNotificationService()
        let start = Date(timeIntervalSince1970: 4_000)
        let engine = TimerEngine(
            stateStore: stateStore,
            historyStore: historyStore,
            notificationService: notifications,
            clock: { start }
        )

        engine.startFocus(
            focusMinutes: 45,
            breakMinutes: 10,
            blockedAppsCount: 1,
            strictMode: false,
            now: start
        )
        engine.stopSession(now: start.addingTimeInterval(600))

        let history = historyStore.loadHistory()
        XCTAssertEqual(engine.snapshot.phase, .cancelled)
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.status, .cancelled)
        XCTAssertEqual(history.first?.durationMinutes, 10)
    }

    func testSnoozeExtendsBreakByTwoMinutes() throws {
        let directory = try temporaryDirectory()
        let stateStore = StateStore(baseDirectory: directory)
        let historyStore = SessionHistoryStore(baseDirectory: directory)
        let notifications = NoopNotificationService()
        let now = Date(timeIntervalSince1970: 5_000)
        let engine = TimerEngine(
            stateStore: stateStore,
            historyStore: historyStore,
            notificationService: notifications,
            clock: { now }
        )

        engine.startBreakExtension(
            minutes: 2,
            focusMinutes: 25,
            blockedAppsCount: 0,
            strictMode: false,
            now: now
        )

        XCTAssertEqual(engine.snapshot.phase, .break)
        XCTAssertEqual(Int(engine.snapshot.remainingSeconds), 120)

        engine.refresh(now: now.addingTimeInterval(121))

        XCTAssertEqual(engine.snapshot.phase, .breakEnded)
        XCTAssertTrue(notifications.events.contains("breakEnded"))
    }

    func testStartFocusFromBreakEndedStartsNewFocusSession() throws {
        let directory = try temporaryDirectory()
        let stateStore = StateStore(baseDirectory: directory)
        let historyStore = SessionHistoryStore(baseDirectory: directory)
        let notifications = NoopNotificationService()
        let now = Date(timeIntervalSince1970: 6_000)
        let engine = TimerEngine(
            stateStore: stateStore,
            historyStore: historyStore,
            notificationService: notifications,
            clock: { now }
        )

        try stateStore.saveSessionState(SessionState(
            state: .breakEnded,
            startedAt: now.addingTimeInterval(-1_800),
            focusMinutes: 25,
            breakMinutes: 5
        ))

        engine.refresh(now: now)
        engine.startFocus(
            focusMinutes: 25,
            breakMinutes: 5,
            blockedAppsCount: 2,
            strictMode: false,
            now: now
        )

        XCTAssertEqual(engine.snapshot.phase, .focus)
        XCTAssertEqual(stateStore.loadSessionState()?.state, .focus)
        XCTAssertTrue(notifications.events.contains("focusStarted:25"))
    }

    func testEndCycleReturnsToIdleFromBreakEnded() throws {
        let directory = try temporaryDirectory()
        let stateStore = StateStore(baseDirectory: directory)
        let historyStore = SessionHistoryStore(baseDirectory: directory)
        let notifications = NoopNotificationService()
        let now = Date(timeIntervalSince1970: 7_000)
        let engine = TimerEngine(
            stateStore: stateStore,
            historyStore: historyStore,
            notificationService: notifications,
            clock: { now }
        )

        try stateStore.saveSessionState(SessionState(
            state: .breakEnded,
            startedAt: now.addingTimeInterval(-1_800),
            focusMinutes: 25,
            breakMinutes: 5
        ))

        engine.refresh(now: now)
        engine.endCycle()

        XCTAssertEqual(engine.snapshot.phase, .idle)
        XCTAssertNil(stateStore.loadSessionState())
    }
}
