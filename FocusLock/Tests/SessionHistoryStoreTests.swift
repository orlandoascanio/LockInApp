import FocusLockCore
import XCTest

final class SessionHistoryStoreTests: XCTestCase {
    func testAppendAndLoadHistoryEntries() throws {
        let directory = try temporaryDirectory()
        let store = SessionHistoryStore(baseDirectory: directory)
        let entry = SessionHistoryEntry(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 1_600),
            focusMinutes: 25,
            breakMinutes: 5,
            status: .completed,
            blockedAppsCount: 3,
            strictMode: false
        )

        try store.append(entry)

        XCTAssertEqual(store.loadHistory(), [entry])
    }

    func testStatsCountTodayAndWeek() throws {
        let directory = try temporaryDirectory()
        let store = SessionHistoryStore(baseDirectory: directory)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let reference = ISO8601DateFormatter().date(from: "2026-06-12T12:00:00Z")!
        let today = ISO8601DateFormatter().date(from: "2026-06-12T09:00:00Z")!
        let thisWeek = ISO8601DateFormatter().date(from: "2026-06-10T09:00:00Z")!
        let cancelled = ISO8601DateFormatter().date(from: "2026-06-12T10:00:00Z")!

        try store.append(SessionHistoryEntry(
            startedAt: today,
            endedAt: today.addingTimeInterval(1_500),
            focusMinutes: 25,
            breakMinutes: 5,
            status: .completed,
            blockedAppsCount: 1,
            strictMode: false
        ))
        try store.append(SessionHistoryEntry(
            startedAt: thisWeek,
            endedAt: thisWeek.addingTimeInterval(2_700),
            focusMinutes: 45,
            breakMinutes: 10,
            status: .completed,
            blockedAppsCount: 2,
            strictMode: true
        ))
        try store.append(SessionHistoryEntry(
            startedAt: cancelled,
            endedAt: cancelled.addingTimeInterval(600),
            focusMinutes: 25,
            breakMinutes: 5,
            status: .cancelled,
            blockedAppsCount: 1,
            strictMode: false
        ))

        let stats = store.stats(referenceDate: reference, calendar: calendar)

        XCTAssertEqual(stats.sessionsCompletedToday, 1)
        XCTAssertEqual(stats.focusMinutesToday, 25)
        XCTAssertEqual(stats.sessionsCompletedThisWeek, 2)
        XCTAssertEqual(stats.focusMinutesThisWeek, 70)
        XCTAssertEqual(stats.totalCompletedSessions, 2)
        XCTAssertEqual(stats.totalSessions, 3)
    }
}
