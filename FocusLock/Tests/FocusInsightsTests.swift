import FocusLockCore
import XCTest

final class FocusInsightsTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    private let today = Date(timeIntervalSince1970: 1_792_000_000)

    private struct World {
        var history: [SessionHistoryEntry] = []
        var reaches: [Reach] = []
        var focusTime: [FocusTimeRecord] = []
    }

    /// Ninety days of someone whose mornings go well and evenings don't,
    /// who reaches for Slack about twelve minutes in, finishes 25-minute
    /// blocks far more often than 50s, and gets stuck on writing.
    private func plantedWorld(seed: UInt64) -> World {
        var rng = SplitMix(seed: seed)
        var world = World()
        let categories = ["Writing", "Coding", "Study"]
        let apps = [("com.apple.dt.Xcode", "Xcode"), ("notion.id", "Notion"), ("com.figma.Desktop", "Figma")]

        for dayOffset in 0..<90 {
            let day = calendar.date(byAdding: .day, value: -dayOffset, to: calendar.startOfDay(for: today))!
            for _ in 0..<Int.random(in: 2...5, using: &rng) {
                let evening = Bool.random(using: &rng)
                let hour = evening ? Int.random(in: 18...21, using: &rng) : Int.random(in: 7...11, using: &rng)
                let start = day.addingTimeInterval(TimeInterval(hour * 3600 + Int.random(in: 0..<3600, using: &rng)))
                // Two blocks can't start in the same second.
                guard !world.history.contains(where: { $0.startedAt == start }) else { continue }
                let minutes = Bool.random(using: &rng) ? 25 : 50
                let finishOdds = (evening ? 0.55 : 0.92) - (minutes == 50 ? 0.25 : 0)
                let finished = Double.random(in: 0..<1, using: &rng) < finishOdds
                let category = categories.randomElement(using: &rng)!
                let outcome: CheckInOutcome = category == "Writing"
                    ? (Bool.random(using: &rng) ? .stuck : .progress)
                    : (Double.random(in: 0..<1, using: &rng) < 0.7 ? .done : .progress)

                world.history.append(SessionHistoryEntry(
                    startedAt: start,
                    endedAt: start.addingTimeInterval(TimeInterval(minutes * 60)),
                    focusMinutes: minutes,
                    breakMinutes: 5,
                    status: finished ? .completed : .cancelled,
                    blockedAppsCount: 2,
                    strictMode: Double.random(in: 0..<1, using: &rng) < 0.2,
                    task: SessionTask(goal: "Ship it", category: category),
                    checkIn: finished ? SessionCheckIn(outcome: outcome, note: "") : nil
                ))

                let reachCount = evening ? Int.random(in: 1...4, using: &rng) : Int.random(in: 0...1, using: &rng)
                for _ in 0..<reachCount {
                    let slack = Double.random(in: 0..<1, using: &rng) < 0.7
                    let minute = slack ? Int.random(in: 10...14, using: &rng) : Int.random(in: 1...20, using: &rng)
                    world.reaches.append(Reach(
                        at: start.addingTimeInterval(TimeInterval(minute * 60 + 5)),
                        key: slack ? "com.tinyspeck.slackmacgap" : "youtube.com",
                        name: slack ? "Slack" : "youtube.com",
                        kind: slack ? .app : .site,
                        blockStartedAt: start
                    ))
                }

                let main = category == "Coding" ? apps[0] : (category == "Writing" ? apps[1] : apps[2])
                world.focusTime.append(FocusTimeRecord(
                    blockStartedAt: start,
                    apps: [main.0: Double(minutes * 45), "com.apple.Safari": Double(minutes * 10)],
                    appNames: [main.0: main.1, "com.apple.Safari": "Safari"],
                    sites: ["github.com": Double(minutes * 6)]
                ))
            }
        }
        return world
    }

    private var lastNinetyDays: Range<Date> {
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: today))!
        return calendar.date(byAdding: .day, value: -89, to: calendar.startOfDay(for: today))!..<end
    }

    func testFindsThePatternsPlantedInGeneratedHistory() {
        for seed: UInt64 in [1, 2, 3, 0xBEEF] {
            let world = plantedWorld(seed: seed)
            let insights = FocusInsights.make(
                history: world.history, reaches: world.reaches, focusTime: world.focusTime,
                range: lastNinetyDays, calendar: calendar
            )

            XCTAssertEqual(insights.bestDaypart?.daypart, .morning, "seed \(seed)")
            XCTAssertEqual(insights.pulls.first?.name, "Slack", "seed \(seed)")
            XCTAssertEqual(insights.pulls.first?.typicalMinute ?? 0, 12, accuracy: 1, "seed \(seed)")
            XCTAssertEqual(insights.sweetSpot?.band, .standard, "seed \(seed)")
            XCTAssertEqual(insights.goals.stuckMostIn, "Writing", "seed \(seed)")
            XCTAssertEqual(insights.whereFocusWent?.topAppByCategory["Coding"], "Xcode", "seed \(seed)")
            XCTAssertEqual(insights.whereFocusWent?.sites.first?.name, "github.com", "seed \(seed)")

            XCTAssertTrue(insights.headline.first?.contains("in the morning") == true, "\(insights.headline)")
            XCTAssertTrue(insights.headline.contains { $0.hasPrefix("Slack is what you reach for most") }, "\(insights.headline)")
            XCTAssertLessThanOrEqual(insights.headline.count, 3)
        }
    }

    func testTotalsAlwaysAgreeWithEachOther() {
        for seed: UInt64 in 10..<30 {
            let world = plantedWorld(seed: seed)
            var rng = SplitMix(seed: seed)
            // Random sub-ranges, including empty and partial ones.
            let startOffset = Int.random(in: 0...100, using: &rng)
            let length = Int.random(in: 0...60, using: &rng)
            let start = calendar.date(byAdding: .day, value: -startOffset, to: today)!
            let range = start..<calendar.date(byAdding: .day, value: length, to: start)!
            let insights = FocusInsights.make(
                history: world.history, reaches: world.reaches, focusTime: world.focusTime,
                range: range, calendar: calendar
            )

            let inRange = world.history.filter { range.contains($0.startedAt) }
            XCTAssertEqual(insights.blocks, inRange.count)
            XCTAssertEqual(insights.dayparts.reduce(0) { $0 + $1.blocks }, insights.blocks)
            XCTAssertEqual(insights.lengths.reduce(0) { $0 + $1.blocks }, insights.blocks)
            XCTAssertEqual(insights.pulls.reduce(0) { $0 + $1.reaches }, insights.totalReaches)
            XCTAssertEqual(insights.dayparts.reduce(0) { $0 + $1.reaches }, insights.totalReaches)
            XCTAssertLessThanOrEqual(insights.cleanBlocks, insights.completedBlocks)
            XCTAssertLessThanOrEqual(insights.cleanStreak, insights.cleanBlocks)
            XCTAssertLessThanOrEqual(insights.goals.checkedIn, insights.goals.blocksWithGoal)
            if let went = insights.whereFocusWent {
                XCTAssertEqual(went.apps.reduce(0) { $0 + $1.share }, 1, accuracy: 0.0001)
                XCTAssertLessThanOrEqual(went.trackedBlocks, insights.blocks)
            }
            if insights.blocks < FocusInsights.minimumBlocks {
                XCTAssertTrue(insights.headline.isEmpty, "\(insights.headline)")
            }
        }
    }

    func testTooLittleHistoryClaimsNothing() {
        let start = today.addingTimeInterval(-3600)
        let entry = SessionHistoryEntry(
            startedAt: start, endedAt: today, focusMinutes: 25, breakMinutes: 5,
            status: .completed, blockedAppsCount: 0, strictMode: false
        )
        let reach = Reach(at: start + 60, key: "slack", name: "Slack", kind: .app, blockStartedAt: start)
        let insights = FocusInsights.make(
            history: [entry], reaches: [reach], focusTime: [],
            range: start.addingTimeInterval(-60)..<today, calendar: calendar
        )
        XCTAssertNil(insights.bestDaypart)
        XCTAssertNil(insights.sweetSpot)
        XCTAssertNil(insights.whereFocusWent)
        XCTAssertTrue(insights.headline.isEmpty)
        XCTAssertEqual(insights.pulls.first?.reaches, 1)
    }

    func testReachesMatchTheirBlockAcrossTheTripThroughDisk() throws {
        let directory = try temporaryDirectory()
        let store = ReachLogStore(baseDirectory: directory)
        let start = Date(timeIntervalSince1970: 1_792_000_000.734)
        store.append(Reach(at: start + 600, key: "slack", name: "Slack", kind: .app, blockStartedAt: start))
        let history = SessionHistoryStore(baseDirectory: directory)
        try history.append(SessionHistoryEntry(
            startedAt: start, endedAt: start + 1500, focusMinutes: 25, breakMinutes: 5,
            status: .completed, blockedAppsCount: 1, strictMode: false
        ))

        let insights = FocusInsights.make(
            history: history.loadHistory(), reaches: store.load(), focusTime: [],
            range: start.addingTimeInterval(-60)..<start.addingTimeInterval(3600), calendar: calendar
        )
        XCTAssertEqual(insights.totalReaches, 1)
        XCTAssertEqual(insights.pulls.first?.typicalMinute, 10)
        XCTAssertEqual(insights.cleanBlocks, 0)
    }

    func testAccumulatorCapsLongGapsAndMergesWWW() {
        var accumulator = FocusTimeAccumulator()
        accumulator.addApp(bundleId: "x", name: "X", seconds: 1)  // before any block: ignored
        accumulator.begin(blockStartedAt: today)
        accumulator.addApp(bundleId: "x", name: "X", seconds: 1)
        accumulator.addApp(bundleId: "x", name: "X", seconds: 3_600)  // a sleep, not an hour of X
        accumulator.addSite(host: "www.GitHub.com", seconds: 5)
        accumulator.addSite(host: "github.com", seconds: 5)

        let record = accumulator.finish()
        XCTAssertEqual(record?.apps["x"], 1 + FocusTimeAccumulator.maxStep)
        XCTAssertEqual(record?.sites, ["github.com": 10])
        XCTAssertNil(accumulator.finish())
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
