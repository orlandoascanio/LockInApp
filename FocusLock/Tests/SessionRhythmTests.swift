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
        status: SessionHistoryStatus = .completed,
        category: String? = nil
    ) throws {
        let start = date(iso)
        try store.append(SessionHistoryEntry(
            startedAt: start,
            endedAt: start.addingTimeInterval(TimeInterval(focusMinutes * 60)),
            focusMinutes: focusMinutes,
            breakMinutes: 5,
            status: status,
            blockedAppsCount: 1,
            strictMode: false,
            task: category.map { SessionTask(goal: "", category: $0) }
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

    // MARK: Week chart details

    func testEachDayCarriesItsSessionsCategoriesAndWhetherItHasHappened() throws {
        let store = SessionHistoryStore(baseDirectory: try temporaryDirectory())
        var calendar = calendarUTC()
        calendar.locale = Locale(identifier: "en_US")

        try append(store, at: "2026-07-21T08:00:00Z", focusMinutes: 25, category: "Study")
        try append(store, at: "2026-07-21T09:00:00Z", focusMinutes: 50, category: "Reading")
        try append(store, at: "2026-07-21T10:00:00Z", focusMinutes: 10, category: "Study")

        let days = store.weeklyRhythm(referenceDate: date("2026-07-21T12:00:00Z"), calendar: calendar)

        XCTAssertEqual(days.map(\.label), ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"])
        XCTAssertEqual(days[2].sessions, 3)
        XCTAssertEqual(days[2].categories, [
            DailyFocus.CategoryTime(name: "Reading", minutes: 50),
            DailyFocus.CategoryTime(name: "Study", minutes: 35)
        ])
        XCTAssertEqual(days.map(\.isFuture), [false, false, false, true, true, true, true])
    }

    func testWeekStartsOnTheCalendarsFirstWeekday() throws {
        let store = SessionHistoryStore(baseDirectory: try temporaryDirectory())
        var calendar = calendarUTC()
        calendar.locale = Locale(identifier: "en_GB")
        calendar.firstWeekday = 2

        let days = store.weeklyRhythm(referenceDate: date("2026-07-21T12:00:00Z"), calendar: calendar)

        XCTAssertEqual(days.first?.label, "Mon")
        XCTAssertEqual(days.last?.label, "Sun")
    }

    func testWeekSummaryComparesWithLastWeekUpToTheSameMoment() throws {
        let store = SessionHistoryStore(baseDirectory: try temporaryDirectory())

        // Last week: Monday counts, Thursday is after "this time last week".
        try append(store, at: "2026-07-13T09:00:00Z", focusMinutes: 30)
        try append(store, at: "2026-07-16T09:00:00Z", focusMinutes: 90)
        // This week, Sunday the 19th to Tuesday the 21st.
        try append(store, at: "2026-07-20T09:00:00Z", focusMinutes: 45)
        try append(store, at: "2026-07-21T09:00:00Z", focusMinutes: 25)

        let summary = store.weekSummary(referenceDate: date("2026-07-21T12:00:00Z"), calendar: calendarUTC())

        XCTAssertEqual(summary.totalMinutes, 70)
        XCTAssertEqual(summary.lastWeekSoFarMinutes, 30)
        XCTAssertEqual(summary.elapsedDays, 3)
        XCTAssertEqual(summary.detail, "+40m vs last week")
    }

    func testWeekSummaryWording() {
        XCTAssertEqual(WeekFocusSummary(totalMinutes: 75, lastWeekSoFarMinutes: 0, elapsedDays: 6).detail, "Avg 12m a day")
        XCTAssertEqual(WeekFocusSummary(totalMinutes: 0, lastWeekSoFarMinutes: 0, elapsedDays: 2).detail, "Nothing yet this week")
        XCTAssertEqual(WeekFocusSummary(totalMinutes: 60, lastWeekSoFarMinutes: 150, elapsedDays: 3).detail, "−1h 30m vs last week")
        XCTAssertEqual(WeekFocusSummary(totalMinutes: 60, lastWeekSoFarMinutes: 60, elapsedDays: 3).detail, "Same as last week")
    }

    func testDailyGoalDefaultsToTwoHours() throws {
        let config = try JSONDecoder().decode(AppConfig.self, from: Data(#"{"focusMinutes":25}"#.utf8))
        XCTAssertEqual(config.dailyFocusGoalMinutes, 120)
    }
}
