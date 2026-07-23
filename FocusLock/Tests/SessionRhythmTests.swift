import FocusLockCore
import XCTest

/// Covers the weekly-rhythm chart and the streak shown in the sidebar.
final class SessionRhythmTests: XCTestCase {
    private func calendarUTC() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso)!
    }

    private func append(
        _ store: SessionHistoryStore,
        at iso: String,
        focusMinutes: Int = 25,
        status: SessionHistoryStatus = .completed
    ) throws {
        let start = date(iso)
        try store.append(SessionHistoryEntry(
            startedAt: start,
            endedAt: start.addingTimeInterval(TimeInterval(focusMinutes * 60)),
            focusMinutes: focusMinutes,
            breakMinutes: 5,
            status: status,
            blockedAppsCount: 1,
            strictMode: false
        ))
    }

    // MARK: Weekly rhythm

    func testWeeklyRhythmReturnsSevenDaysWithSummedFocusMinutes() throws {
        let store = SessionHistoryStore(baseDirectory: try temporaryDirectory())
        let calendar = calendarUTC()

        // Week of Sunday 2026-07-19 through Saturday 2026-07-25.
        try append(store, at: "2026-07-20T09:00:00Z", focusMinutes: 25)
        try append(store, at: "2026-07-20T11:00:00Z", focusMinutes: 45)
        try append(store, at: "2026-07-21T09:00:00Z", focusMinutes: 30)

        let days = store.weeklyRhythm(referenceDate: date("2026-07-21T12:00:00Z"), calendar: calendar)

        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days.map(\.minutes), [0, 70, 30, 0, 0, 0, 0])
    }

    func testWeeklyRhythmMarksOnlyTheReferenceDayAsToday() throws {
        let store = SessionHistoryStore(baseDirectory: try temporaryDirectory())

        let days = store.weeklyRhythm(
            referenceDate: date("2026-07-21T12:00:00Z"),
            calendar: calendarUTC()
        )

        XCTAssertEqual(days.filter(\.isToday).count, 1)
        XCTAssertEqual(days.firstIndex(where: \.isToday), 2)
    }

    func testWeeklyRhythmIgnoresCancelledAndAbandonedSessions() throws {
        let store = SessionHistoryStore(baseDirectory: try temporaryDirectory())

        try append(store, at: "2026-07-21T09:00:00Z", focusMinutes: 25, status: .cancelled)
        try append(store, at: "2026-07-21T10:00:00Z", focusMinutes: 45, status: .abandoned)
        try append(store, at: "2026-07-21T11:00:00Z", focusMinutes: 30, status: .completed)

        let days = store.weeklyRhythm(
            referenceDate: date("2026-07-21T12:00:00Z"),
            calendar: calendarUTC()
        )

        XCTAssertEqual(days[2].minutes, 30)
    }

    // MARK: Streak

    func testStreakCountsConsecutiveDaysEndingToday() throws {
        let store = SessionHistoryStore(baseDirectory: try temporaryDirectory())

        try append(store, at: "2026-07-19T09:00:00Z")
        try append(store, at: "2026-07-20T09:00:00Z")
        try append(store, at: "2026-07-21T09:00:00Z")

        let streak = store.focusStreak(
            referenceDate: date("2026-07-21T12:00:00Z"),
            calendar: calendarUTC()
        )

        XCTAssertEqual(streak, 3)
    }

    func testStreakSurvivesADayThatHasNotHappenedYet() throws {
        let store = SessionHistoryStore(baseDirectory: try temporaryDirectory())

        // Nothing completed today yet, but yesterday and the day before were.
        try append(store, at: "2026-07-19T09:00:00Z")
        try append(store, at: "2026-07-20T09:00:00Z")

        let streak = store.focusStreak(
            referenceDate: date("2026-07-21T08:00:00Z"),
            calendar: calendarUTC()
        )

        XCTAssertEqual(streak, 2)
    }

    func testStreakBreaksAfterAFullMissedDay() throws {
        let store = SessionHistoryStore(baseDirectory: try temporaryDirectory())

        try append(store, at: "2026-07-17T09:00:00Z")
        try append(store, at: "2026-07-18T09:00:00Z")
        // 2026-07-19 and 2026-07-20 missed entirely.
        try append(store, at: "2026-07-21T09:00:00Z")

        let streak = store.focusStreak(
            referenceDate: date("2026-07-21T12:00:00Z"),
            calendar: calendarUTC()
        )

        XCTAssertEqual(streak, 1)
    }

    func testStreakIsZeroWithoutCompletedSessions() throws {
        let store = SessionHistoryStore(baseDirectory: try temporaryDirectory())

        try append(store, at: "2026-07-21T09:00:00Z", status: .cancelled)

        let streak = store.focusStreak(
            referenceDate: date("2026-07-21T12:00:00Z"),
            calendar: calendarUTC()
        )

        XCTAssertEqual(streak, 0)
    }
}
