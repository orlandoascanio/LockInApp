import FocusLockCore
import XCTest

final class BlockActivityStoreTests: XCTestCase {
    private func calendarUTC() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testRecordingInterceptionsAccumulatesPerBundleIdentifier() throws {
        let store = BlockActivityStore(baseDirectory: try temporaryDirectory(), calendar: calendarUTC())
        let now = ISO8601DateFormatter().date(from: "2026-07-21T10:00:00Z")!

        store.recordInterception(bundleId: "com.hnc.Discord", now: now)
        store.recordInterception(bundleId: "com.hnc.Discord", now: now)
        store.recordInterception(bundleId: "com.spotify.client", now: now)

        let counts = store.countsToday(referenceDate: now)
        XCTAssertEqual(counts["com.hnc.Discord"], 2)
        XCTAssertEqual(counts["com.spotify.client"], 1)
    }

    func testCountsResetOnTheNextDay() throws {
        let store = BlockActivityStore(baseDirectory: try temporaryDirectory(), calendar: calendarUTC())
        let today = ISO8601DateFormatter().date(from: "2026-07-21T23:00:00Z")!
        let tomorrow = ISO8601DateFormatter().date(from: "2026-07-22T00:30:00Z")!

        store.recordInterception(bundleId: "com.hnc.Discord", now: today)

        XCTAssertEqual(store.countsToday(referenceDate: today)["com.hnc.Discord"], 1)
        XCTAssertTrue(store.countsToday(referenceDate: tomorrow).isEmpty)
    }

    func testRecordingAfterRolloverStartsFromOne() throws {
        let store = BlockActivityStore(baseDirectory: try temporaryDirectory(), calendar: calendarUTC())
        let today = ISO8601DateFormatter().date(from: "2026-07-21T23:00:00Z")!
        let tomorrow = ISO8601DateFormatter().date(from: "2026-07-22T09:00:00Z")!

        store.recordInterception(bundleId: "com.hnc.Discord", now: today)
        store.recordInterception(bundleId: "com.hnc.Discord", now: today)
        let counts = store.recordInterception(bundleId: "com.hnc.Discord", now: tomorrow)

        XCTAssertEqual(counts["com.hnc.Discord"], 1)
    }

    func testCountsAreEmptyBeforeAnythingIsRecorded() throws {
        let store = BlockActivityStore(baseDirectory: try temporaryDirectory(), calendar: calendarUTC())

        XCTAssertTrue(store.countsToday().isEmpty)
    }
}
