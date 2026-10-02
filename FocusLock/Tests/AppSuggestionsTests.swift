import FocusLockCore
import XCTest

final class AppSuggestionsTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func app(
        _ name: String,
        id: String? = nil,
        category: String? = nil,
        daysAgo: Double? = nil,
        uses: Int = 0,
        running: Bool = false,
        docked: Bool = false
    ) -> AppUsage {
        AppUsage(
            name: name,
            bundleId: id ?? "test.\(name.lowercased())",
            url: URL(fileURLWithPath: "/Applications/\(name).app"),
            category: category,
            lastUsed: daysAgo.map { now.addingTimeInterval(-$0 * 86_400) },
            useCount: uses,
            isRunning: running,
            isInDock: docked
        )
    }

    func testLikelyDistractionsAreOrderedByRealUse() {
        let list = AppSuggestions.rank(
            [
                app("Mail", id: "com.apple.mail", daysAgo: 20, uses: 3),
                app("Discord", id: "com.hnc.Discord", daysAgo: 0, uses: 400, running: true),
                app("Steam", id: "com.valvesoftware.steam", daysAgo: 5, uses: 141)
            ],
            now: now
        )

        XCTAssertEqual(list.likely.map(\.name), ["Discord", "Steam", "Mail"])
        XCTAssertTrue(list.frequent.isEmpty)
    }

    func testKnownDistractionWithNoLaunchRecordIsStillOfferedLast() {
        // Messages keeps no Spotlight launch record, yet it is the classic one.
        let list = AppSuggestions.rank(
            [
                app("Messages", id: "com.apple.MobileSMS"),
                app("Telegram", id: "ru.keepcoder.Telegram", daysAgo: 2, uses: 10)
            ],
            now: now
        )

        XCTAssertEqual(list.likely.map(\.name), ["Telegram", "Messages"])
    }

    func testWorkToolsAreNeverSuggestedHoweverMuchTheyAreUsed() {
        let list = AppSuggestions.rank(
            [
                app("Xcode", category: "public.app-category.developer-tools", daysAgo: 0, uses: 9_000, running: true, docked: true),
                app("Numbers", category: "public.app-category.productivity", daysAgo: 0, uses: 500),
                app("Chess", category: "public.app-category.board-games", daysAgo: 3, uses: 12)
            ],
            now: now
        )

        XCTAssertEqual(list.likely.map(\.name), ["Chess"])
        XCTAssertTrue(list.frequent.isEmpty)
    }

    func testPreinstalledGameNobodyOpensIsNotSuggested() {
        let list = AppSuggestions.rank(
            [app("Chess", category: "public.app-category.board-games")],
            now: now
        )

        XCTAssertTrue(list.isEmpty)
    }

    func testUncategorisedAppsNeedEvidenceAndGoInTheSecondList() {
        let list = AppSuggestions.rank(
            [
                app("Spotify", daysAgo: 1, uses: 300),
                app("NeverOpened"),
                app("StaleTool", daysAgo: 400)
            ],
            now: now
        )

        XCTAssertTrue(list.likely.isEmpty)
        XCTAssertEqual(list.frequent.map(\.name), ["Spotify"])
    }

    func testExcludedAndDuplicateAppsAreDropped() {
        let list = AppSuggestions.rank(
            [
                app("Chrome", id: "com.google.Chrome", daysAgo: 0, uses: 6_675, running: true),
                app("Discord", id: "com.hnc.Discord", daysAgo: 0, uses: 4),
                app("Discord", id: "com.hnc.Discord", daysAgo: 9, uses: 1)
            ],
            now: now,
            excluding: ["com.google.Chrome"]
        )

        XCTAssertEqual(list.likely.count, 1)
        XCTAssertEqual(list.likely.first?.useCount, 4)
        XCTAssertTrue(list.frequent.isEmpty)
    }

    func testEvidenceSaysWhyAnAppIsListed() {
        XCTAssertEqual(AppSuggestions.evidence(for: app("A", daysAgo: 3, running: true), now: now), "Open now")
        XCTAssertEqual(AppSuggestions.evidence(for: app("A", daysAgo: 4), now: now), "Used 4 days ago")
        XCTAssertEqual(AppSuggestions.evidence(for: app("A", daysAgo: 90, docked: true), now: now), "In your Dock")
        XCTAssertNil(AppSuggestions.evidence(for: app("A", daysAgo: 90), now: now))
        XCTAssertNil(AppSuggestions.evidence(for: app("A"), now: now))
    }

    /// A few hundred made-up Macs, each with a different mix of apps and
    /// habits: the lists must hold their promises on every one.
    func testInvariantsHoldAcrossGeneratedMacs() {
        var generator = SeededGenerator(seed: 20_261_002)
        let categories: [String?] = [
            nil, nil,
            "public.app-category.social-networking",
            "public.app-category.developer-tools",
            "public.app-category.productivity",
            "public.app-category.action-games",
            "public.app-category.entertainment",
            "public.app-category.utilities",
            "public.app-category.music"
        ]
        let known = Array(AppSuggestions.knownDistractions).sorted()
        let excluded: Set<String> = ["gen.app.0", "gen.app.1", "com.apple.mail"]

        for _ in 0..<400 {
            let count = Int.random(in: 0...70, using: &generator)
            var apps: [AppUsage] = (0..<count).map { index in
                let used = Bool.random(using: &generator)
                return AppUsage(
                    name: "App \(Int.random(in: 0...40, using: &generator))",
                    bundleId: "gen.app.\(index)",
                    url: URL(fileURLWithPath: "/Applications/App\(index).app"),
                    category: categories.randomElement(using: &generator)!,
                    lastUsed: used ? now.addingTimeInterval(-Double.random(in: 0...200, using: &generator) * 86_400) : nil,
                    useCount: used ? Int.random(in: 0...20_000, using: &generator) : 0,
                    isRunning: Int.random(in: 0...9, using: &generator) == 0,
                    isInDock: Int.random(in: 0...6, using: &generator) == 0
                )
            }
            for bundleId in known where Bool.random(using: &generator) {
                apps.append(AppUsage(
                    name: bundleId,
                    bundleId: bundleId,
                    url: URL(fileURLWithPath: "/Applications/\(bundleId).app"),
                    lastUsed: Bool.random(using: &generator)
                        ? now.addingTimeInterval(-Double.random(in: 0...60, using: &generator) * 86_400)
                        : nil,
                    useCount: Int.random(in: 0...500, using: &generator)
                ))
            }
            apps.shuffle(using: &generator)

            let list = AppSuggestions.rank(apps, now: now, excluding: excluded)
            let all = list.likely + list.frequent

            XCTAssertLessThanOrEqual(list.likely.count, 9)
            XCTAssertLessThanOrEqual(list.frequent.count, 6)
            XCTAssertEqual(Set(all.map(\.bundleId)).count, all.count, "an app was offered twice")
            XCTAssertTrue(all.allSatisfy { !excluded.contains($0.bundleId) }, "an excluded app was offered")

            for group in [list.likely, list.frequent] {
                let scores = group.map { AppSuggestions.score($0, now: now) }
                XCTAssertEqual(scores, scores.sorted(by: >), "a list was not most-used first")
            }
            for app in list.frequent {
                XCTAssertGreaterThan(AppSuggestions.score(app, now: now), 0, "an unused app was called frequent")
                XCTAssertNotEqual(app.category, "public.app-category.developer-tools")
                XCTAssertNotEqual(app.category, "public.app-category.productivity")
                XCTAssertNotEqual(app.category, "public.app-category.utilities")
            }
            for app in list.likely where !AppSuggestions.knownDistractions.contains(app.bundleId) {
                XCTAssertNotNil(app.category, "an uncategorised unknown app was called a likely distraction")
                XCTAssertGreaterThan(AppSuggestions.score(app, now: now), 0, "an unused, unknown app was suggested")
            }
        }
    }
}

/// SplitMix64: small, fast, and the same sequence on every run.
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
