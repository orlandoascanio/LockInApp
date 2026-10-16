import FocusLockCore
import XCTest

final class AnalyticsRangeTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    private let today = Date(timeIntervalSince1970: 1_792_000_000)  // mid-October 2026

    /// Fourteen months of uneven use: quiet weeks, heavy days, every outcome.
    private func generatedHistory(seed: UInt64 = 0xA11) -> [SessionHistoryEntry] {
        var rng = SplitMix(seed: seed)
        var entries: [SessionHistoryEntry] = []
        for dayOffset in 0..<425 {
            guard Int.random(in: 0..<10, using: &rng) < 7 else { continue }
            let day = calendar.date(byAdding: .day, value: -dayOffset, to: calendar.startOfDay(for: today))!
            for _ in 0..<Int.random(in: 1...6, using: &rng) {
                let start = day.addingTimeInterval(TimeInterval(Int.random(in: 7 * 3600...22 * 3600, using: &rng)))
                let minutes = [25, 25, 50, 50, 90, 15].randomElement(using: &rng)!
                let roll = Int.random(in: 0..<10, using: &rng)
                let status: SessionHistoryStatus = roll < 7 ? .completed : (roll < 9 ? .cancelled : .abandoned)
                entries.append(SessionHistoryEntry(
                    startedAt: start,
                    endedAt: start.addingTimeInterval(TimeInterval(minutes * 60)),
                    focusMinutes: minutes,
                    breakMinutes: 5,
                    status: status,
                    blockedAppsCount: 0,
                    strictMode: false
                ))
            }
        }
        return entries.shuffled(using: &rng)
    }

    func testEveryRangeAddsUpToTheSessionsInsideIt() {
        let history = generatedHistory()
        let expectedDays: [SessionAnalyticsPeriod: Int] = [.sevenDays: 7, .thirtyDays: 30, .ninetyDays: 90, .year: 365]

        for period in SessionAnalyticsPeriod.allCases where period != .custom {
            let snapshot = SessionAnalytics.snapshot(history: history, period: period, referenceDate: today, calendar: calendar)
            let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: today))!
            let inside = history.filter { $0.startedAt >= snapshot.startDate && $0.startedAt < end }
            let completed = inside.filter { $0.status == .completed }

            XCTAssertEqual(snapshot.totalFocusMinutes, completed.reduce(0) { $0 + $1.focusMinutes }, "\(period)")
            XCTAssertEqual(snapshot.timeline.reduce(0) { $0 + $1.minutes }, snapshot.totalFocusMinutes, "\(period)")
            XCTAssertEqual(snapshot.outcomes.total, inside.count, "\(period)")
            XCTAssertLessThanOrEqual(snapshot.timeline.count, 32, "\(period) has too many bars to draw")

            if let days = expectedDays[period] {
                let span = calendar.dateComponents([.day], from: snapshot.startDate, to: snapshot.endDate).day! + 1
                XCTAssertEqual(span, days, "\(period)")
            }
        }
    }

    func testLongerRangesGroupIntoWeeksAndMonths() {
        let history = generatedHistory()
        func granularity(_ period: SessionAnalyticsPeriod) -> SessionAnalyticsGranularity {
            SessionAnalytics.snapshot(history: history, period: period, referenceDate: today, calendar: calendar).granularity
        }
        XCTAssertEqual(granularity(.sevenDays), .day)
        XCTAssertEqual(granularity(.thirtyDays), .day)
        XCTAssertEqual(granularity(.ninetyDays), .week)
        XCTAssertEqual(granularity(.year), .month)
    }

    func testCustomRangeCoversExactlyTheChosenDays() {
        let history = generatedHistory()
        let start = calendar.date(byAdding: .day, value: -200, to: today)!
        let end = calendar.date(byAdding: .day, value: -170, to: today)!
        let snapshot = SessionAnalytics.snapshot(
            history: history, period: .custom, referenceDate: end, customStart: start, calendar: calendar
        )

        let lower = calendar.startOfDay(for: start)
        let upper = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end))!
        let inside = history.filter { $0.startedAt >= lower && $0.startedAt < upper }
        XCTAssertEqual(snapshot.outcomes.total, inside.count)
        XCTAssertEqual(snapshot.startDate, lower)
        XCTAssertEqual(snapshot.granularity, .day)
        XCTAssertEqual(snapshot.timeline.count, 31)
    }

    func testCustomStartAfterTheEndCollapsesToOneDay() {
        let snapshot = SessionAnalytics.snapshot(
            history: generatedHistory(), period: .custom, referenceDate: today,
            customStart: today.addingTimeInterval(86_400 * 3), calendar: calendar
        )
        XCTAssertEqual(snapshot.startDate, snapshot.endDate)
        XCTAssertEqual(snapshot.timeline.count, 1)
    }
}

private struct SplitMix: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
