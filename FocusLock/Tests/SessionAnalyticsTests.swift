import FocusLockCore
import XCTest

final class SessionAnalyticsTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso)!
    }

    private func entry(
        _ iso: String,
        minutes: Int,
        status: SessionHistoryStatus = .completed
    ) -> SessionHistoryEntry {
        let start = date(iso)
        return SessionHistoryEntry(
            startedAt: start,
            endedAt: start.addingTimeInterval(TimeInterval(minutes * 60)),
            focusMinutes: minutes,
            breakMinutes: 5,
            status: status,
            blockedAppsCount: 1,
            strictMode: false
        )
    }

    func testSevenDaySnapshotBuildsAContinuousTimelineAndMetrics() {
        let history = [
            entry("2026-07-17T09:00:00Z", minutes: 25),
            entry("2026-07-17T11:00:00Z", minutes: 45),
            entry("2026-07-20T09:00:00Z", minutes: 50),
            entry("2026-07-21T10:00:00Z", minutes: 30, status: .cancelled),
            entry("2026-07-21T11:00:00Z", minutes: 20, status: .abandoned)
        ]

        let snapshot = SessionAnalytics.snapshot(
            history: history,
            period: .sevenDays,
            referenceDate: date("2026-07-21T12:00:00Z"),
            calendar: calendar
        )

        XCTAssertEqual(snapshot.timeline.count, 7)
        XCTAssertEqual(snapshot.timeline.map(\.minutes), [0, 0, 70, 0, 0, 50, 0])
        XCTAssertEqual(snapshot.totalFocusMinutes, 120)
        XCTAssertEqual(snapshot.completedSessions, 3)
        XCTAssertEqual(snapshot.activeDays, 2)
        XCTAssertEqual(snapshot.averageSessionMinutes, 40)
        XCTAssertEqual(snapshot.averageFocusMinutesPerActiveDay, 60)
        XCTAssertEqual(snapshot.completionRate, 0.6, accuracy: 0.001)
        XCTAssertEqual(snapshot.longestSessionMinutes, 50)
        XCTAssertEqual(snapshot.bestDay, date("2026-07-17T00:00:00Z"))
        XCTAssertEqual(snapshot.bestDayMinutes, 70)
    }

    func testThirtyDaySnapshotExcludesOlderAndFutureSessions() {
        let history = [
            entry("2026-06-20T09:00:00Z", minutes: 90),
            entry("2026-06-22T09:00:00Z", minutes: 25),
            entry("2026-07-21T09:00:00Z", minutes: 45),
            entry("2026-07-22T09:00:00Z", minutes: 60)
        ]

        let snapshot = SessionAnalytics.snapshot(
            history: history,
            period: .thirtyDays,
            referenceDate: date("2026-07-21T12:00:00Z"),
            calendar: calendar
        )

        XCTAssertEqual(snapshot.timeline.count, 30)
        XCTAssertEqual(snapshot.totalFocusMinutes, 70)
        XCTAssertEqual(snapshot.completedSessions, 2)
    }

    func testAllTimeUsesWeeklyBucketsForAMediumHistory() {
        let history = [
            entry("2026-06-01T09:00:00Z", minutes: 25),
            entry("2026-06-15T09:00:00Z", minutes: 45),
            entry("2026-07-21T09:00:00Z", minutes: 50)
        ]

        let snapshot = SessionAnalytics.snapshot(
            history: history,
            period: .allTime,
            referenceDate: date("2026-07-21T12:00:00Z"),
            calendar: calendar
        )

        XCTAssertEqual(snapshot.granularity, .week)
        XCTAssertEqual(snapshot.timeline.reduce(0) { $0 + $1.minutes }, 120)
        XCTAssertEqual(snapshot.startDate, date("2026-06-01T00:00:00Z"))
    }

    func testWeekdayFocusUsesTheCalendarsWeekOrder() {
        let history = [
            entry("2026-07-19T09:00:00Z", minutes: 25),
            entry("2026-07-20T09:00:00Z", minutes: 45),
            entry("2026-07-20T11:00:00Z", minutes: 30)
        ]

        let snapshot = SessionAnalytics.snapshot(
            history: history,
            period: .sevenDays,
            referenceDate: date("2026-07-21T12:00:00Z"),
            calendar: calendar
        )

        XCTAssertEqual(snapshot.weekdayFocus.map(\.minutes), [25, 75, 0, 0, 0, 0, 0])
    }
}
