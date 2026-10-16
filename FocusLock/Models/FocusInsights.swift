import Foundation

/// What your own history says about how focus goes for you: what pulls you
/// away, when it holds, which blocks you finish, and what came of your goals.
///
/// Everything here comes from what Quietwhile already does — the guard, the
/// goal and check-in on each block, strict mode — plus, if you turned it on,
/// which apps were in front during focus. Nothing is compared with anyone
/// else, and no claim is made from fewer blocks than it takes to mean it.
public struct FocusInsights: Equatable {
    /// The fewest blocks a pattern needs before it is called one.
    public static let minimumBlocks = 3

    public struct Pull: Equatable, Identifiable {
        public var id: String { key }
        public var key: String
        public var name: String
        public var kind: Reach.Kind
        public var reaches: Int
        /// Blocks it was reached for in at least once.
        public var blocks: Int
        /// The middle of how far into a block it tends to come, if known.
        public var typicalMinute: Int?
    }

    public enum Daypart: String, CaseIterable, Identifiable {
        case morning
        case afternoon
        case evening
        case lateNight

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .morning: return "Morning"
            case .afternoon: return "Afternoon"
            case .evening: return "Evening"
            case .lateNight: return "Late night"
            }
        }

        /// "in the morning", "late at night".
        public var phrase: String {
            switch self {
            case .morning: return "in the morning"
            case .afternoon: return "in the afternoon"
            case .evening: return "in the evening"
            case .lateNight: return "late at night"
            }
        }

        public var hours: String {
            switch self {
            case .morning: return "5 am – noon"
            case .afternoon: return "noon – 5 pm"
            case .evening: return "5 – 10 pm"
            case .lateNight: return "10 pm – 5 am"
            }
        }

        public static func of(hour: Int) -> Daypart {
            switch hour {
            case 5..<12: return .morning
            case 12..<17: return .afternoon
            case 17..<22: return .evening
            default: return .lateNight
            }
        }
    }

    public struct DaypartStats: Equatable, Identifiable {
        public var id: Daypart { daypart }
        public var daypart: Daypart
        public var blocks: Int
        public var completed: Int
        public var reaches: Int

        public var completionRate: Double { blocks == 0 ? 0 : Double(completed) / Double(blocks) }
        public var reachesPerBlock: Double { blocks == 0 ? 0 : Double(reaches) / Double(blocks) }
    }

    public enum LengthBand: Int, CaseIterable, Identifiable {
        case short
        case standard
        case long
        case marathon

        public var id: Int { rawValue }

        public var title: String {
            switch self {
            case .short: return "Under 20 min"
            case .standard: return "20 – 35 min"
            case .long: return "36 – 60 min"
            case .marathon: return "Over an hour"
            }
        }

        public static func of(minutes: Int) -> LengthBand {
            switch minutes {
            case ..<20: return .short
            case 20...35: return .standard
            case 36...60: return .long
            default: return .marathon
            }
        }
    }

    public struct LengthStats: Equatable, Identifiable {
        public var id: LengthBand { band }
        public var band: LengthBand
        public var blocks: Int
        public var completed: Int

        public var completionRate: Double { blocks == 0 ? 0 : Double(completed) / Double(blocks) }
    }

    public struct Goals: Equatable {
        public var blocksWithGoal: Int
        public var done: Int
        public var progress: Int
        public var stuck: Int
        /// The category with the most "stuck" check-ins, when one stands out.
        public var stuckMostIn: String?
        /// The category whose goals get done most often, when it has enough.
        public var doneMostIn: String?

        public var checkedIn: Int { done + progress + stuck }
    }

    public struct StrictComparison: Equatable {
        public var strictBlocks: Int
        public var strictCompletionRate: Double
        public var relaxedBlocks: Int
        public var relaxedCompletionRate: Double
    }

    public struct TimeShare: Equatable, Identifiable {
        public var id: String { key }
        public var key: String
        public var name: String
        public var seconds: Double
        public var share: Double
    }

    public struct WhereFocusWent: Equatable {
        public var trackedBlocks: Int
        public var trackedSeconds: Double
        public var apps: [TimeShare]
        public var sites: [TimeShare]
        /// For each category with tracked blocks, the app most in front.
        public var topAppByCategory: [String: String]
    }

    /// A few plain sentences about the strongest patterns.
    public var headline: [String]
    public var blocks: Int
    public var completedBlocks: Int
    public var pulls: [Pull]
    public var totalReaches: Int
    /// Completed blocks without a single reach.
    public var cleanBlocks: Int
    /// The run of clean, completed blocks up to the most recent one.
    public var cleanStreak: Int
    public var dayparts: [DaypartStats]
    public var bestDaypart: DaypartStats?
    public var lengths: [LengthStats]
    public var sweetSpot: LengthStats?
    public var goals: Goals
    public var strict: StrictComparison?
    public var whereFocusWent: WhereFocusWent?

    public var isEmpty: Bool { blocks == 0 }
}

extension FocusInsights {
    /// - Parameters:
    ///   - history: every block on record; the range is applied here.
    ///   - reaches: every reach on record.
    ///   - focusTime: every focus-time record; empty unless tracking is on.
    ///   - range: the blocks that count, by when they started.
    public static func make(
        history: [SessionHistoryEntry],
        reaches: [Reach],
        focusTime: [FocusTimeRecord],
        range: Range<Date>,
        calendar: Calendar = .current
    ) -> FocusInsights {
        let blocks = history
            .filter { range.contains($0.startedAt) }
            .sorted { $0.startedAt < $1.startedAt }
        let blockKeys = Set(blocks.map { blockKey($0.startedAt) })
        let blockReaches = reaches.filter { reach in
            if let start = reach.blockStartedAt { return blockKeys.contains(blockKey(start)) }
            return range.contains(reach.at)
        }
        let reachesByBlock = Dictionary(grouping: blockReaches.compactMap { reach in
            reach.blockStartedAt.map { (blockKey($0), reach) }
        }, by: \.0).mapValues(\.count)

        let completed = blocks.filter { $0.status == .completed }
        let isClean: (SessionHistoryEntry) -> Bool = { (reachesByBlock[blockKey($0.startedAt)] ?? 0) == 0 }

        var cleanStreak = 0
        for block in completed.reversed() {
            guard isClean(block) else { break }
            cleanStreak += 1
        }

        let pulls = makePulls(blockReaches)
        let dayparts = Daypart.allCases.map { part -> DaypartStats in
            let inPart = blocks.filter { Daypart.of(hour: calendar.component(.hour, from: $0.startedAt)) == part }
            return DaypartStats(
                daypart: part,
                blocks: inPart.count,
                completed: inPart.filter { $0.status == .completed }.count,
                reaches: inPart.reduce(0) { $0 + (reachesByBlock[blockKey($1.startedAt)] ?? 0) }
            )
        }
        let lengths = LengthBand.allCases.map { band -> LengthStats in
            let inBand = blocks.filter { LengthBand.of(minutes: plannedMinutes($0)) == band }
            return LengthStats(band: band, blocks: inBand.count, completed: inBand.filter { $0.status == .completed }.count)
        }

        let insights = FocusInsights(
            headline: [],
            blocks: blocks.count,
            completedBlocks: completed.count,
            pulls: pulls,
            totalReaches: blockReaches.count,
            cleanBlocks: completed.filter(isClean).count,
            cleanStreak: cleanStreak,
            dayparts: dayparts,
            bestDaypart: best(dayparts.filter { $0.blocks >= minimumBlocks }, in: dayparts),
            lengths: lengths,
            sweetSpot: bestLength(lengths),
            goals: makeGoals(blocks),
            strict: makeStrict(blocks),
            whereFocusWent: makeWhereFocusWent(focusTime, blocks: blocks)
        )
        var withHeadline = insights
        withHeadline.headline = makeHeadline(insights)
        return withHeadline
    }

    /// History and reaches are written separately, each to whole seconds, so
    /// they are matched on whole seconds.
    private static func blockKey(_ date: Date) -> Int {
        Int(date.timeIntervalSince1970.rounded(.down))
    }

    /// What the block was set for: a cancelled block records the minutes it
    /// was planned with, which is the length that was chosen.
    private static func plannedMinutes(_ entry: SessionHistoryEntry) -> Int {
        entry.focusMinutes
    }

    private static func makePulls(_ reaches: [Reach]) -> [Pull] {
        Dictionary(grouping: reaches, by: \.key).map { key, group in
            let minutes = group.compactMap(\.minuteIntoBlock).sorted()
            let latest = group.max { $0.at < $1.at }!
            return Pull(
                key: key,
                name: latest.name,
                kind: latest.kind,
                reaches: group.count,
                blocks: Set(group.compactMap { $0.blockStartedAt.map(blockKey) }).count,
                typicalMinute: minutes.isEmpty ? nil : minutes[minutes.count / 2]
            )
        }
        .sorted { ($0.reaches, $1.name) > ($1.reaches, $0.name) }
    }

    /// The part of the day where blocks finish most and get interrupted
    /// least — but only if it actually stands apart from the others.
    private static func best(_ candidates: [DaypartStats], in all: [DaypartStats]) -> DaypartStats? {
        guard candidates.count >= 2 else { return nil }
        let score: (DaypartStats) -> Double = { $0.completionRate - 0.1 * min($0.reachesPerBlock, 5) }
        let ranked = candidates.sorted { score($0) > score($1) }
        guard score(ranked[0]) - score(ranked[1]) >= 0.05 else { return nil }
        return ranked[0]
    }

    private static func bestLength(_ lengths: [LengthStats]) -> LengthStats? {
        let candidates = lengths.filter { $0.blocks >= minimumBlocks }
        guard candidates.count >= 2 else { return nil }
        let ranked = candidates.sorted { ($0.completionRate, $0.blocks) > ($1.completionRate, $1.blocks) }
        guard ranked[0].completionRate - ranked[1].completionRate >= 0.05 else { return nil }
        return ranked[0]
    }

    private static func makeGoals(_ blocks: [SessionHistoryEntry]) -> Goals {
        let withGoal = blocks.filter { !($0.task?.goal.isEmpty ?? true) }
        let checked = withGoal.filter { $0.checkIn != nil }
        let count: (CheckInOutcome) -> Int = { outcome in checked.filter { $0.checkIn?.outcome == outcome }.count }

        let byCategory = Dictionary(grouping: checked) { $0.task?.category ?? "" }
            .filter { !$0.key.isEmpty && $0.value.count >= minimumBlocks }
        let stuckShare = byCategory.mapValues { group in
            Double(group.filter { $0.checkIn?.outcome == .stuck }.count) / Double(group.count)
        }
        let doneShare = byCategory.mapValues { group in
            Double(group.filter { $0.checkIn?.outcome == .done }.count) / Double(group.count)
        }
        let stuckMost = stuckShare.filter { $0.value > 0 }.max { ($0.value, $1.key) < ($1.value, $0.key) }
        let doneMost = doneShare.filter { $0.value > 0 }.max { ($0.value, $1.key) < ($1.value, $0.key) }

        return Goals(
            blocksWithGoal: withGoal.count,
            done: count(.done),
            progress: count(.progress),
            stuck: count(.stuck),
            stuckMostIn: byCategory.count >= 2 ? stuckMost?.key : nil,
            doneMostIn: byCategory.count >= 2 ? doneMost?.key : nil
        )
    }

    private static func makeStrict(_ blocks: [SessionHistoryEntry]) -> StrictComparison? {
        let strict = blocks.filter(\.strictMode)
        let relaxed = blocks.filter { !$0.strictMode }
        guard strict.count >= minimumBlocks, relaxed.count >= minimumBlocks else { return nil }
        let rate: ([SessionHistoryEntry]) -> Double = { group in
            Double(group.filter { $0.status == .completed }.count) / Double(group.count)
        }
        return StrictComparison(
            strictBlocks: strict.count,
            strictCompletionRate: rate(strict),
            relaxedBlocks: relaxed.count,
            relaxedCompletionRate: rate(relaxed)
        )
    }

    private static func makeWhereFocusWent(_ records: [FocusTimeRecord], blocks: [SessionHistoryEntry]) -> WhereFocusWent? {
        let blocksByKey = Dictionary(blocks.map { (blockKey($0.startedAt), $0) }, uniquingKeysWith: { first, _ in first })
        let inRange = records.filter { blocksByKey[blockKey($0.blockStartedAt)] != nil }
        guard !inRange.isEmpty else { return nil }

        var appSeconds: [String: Double] = [:]
        var appNames: [String: String] = [:]
        var siteSeconds: [String: Double] = [:]
        var categoryApps: [String: [String: Double]] = [:]
        for record in inRange {
            for (app, seconds) in record.apps {
                appSeconds[app, default: 0] += seconds
                if let name = record.appNames[app] { appNames[app] = name }
                if let category = blocksByKey[blockKey(record.blockStartedAt)]?.task?.category, !category.isEmpty {
                    categoryApps[category, default: [:]][app, default: 0] += seconds
                }
            }
            for (site, seconds) in record.sites {
                siteSeconds[site, default: 0] += seconds
            }
        }

        let total = appSeconds.values.reduce(0, +)
        func shares(_ seconds: [String: Double], names: [String: String], of whole: Double) -> [TimeShare] {
            seconds.map { key, value in
                TimeShare(key: key, name: names[key] ?? key, seconds: value, share: whole > 0 ? value / whole : 0)
            }
            .sorted { ($0.seconds, $1.name) > ($1.seconds, $0.name) }
        }

        return WhereFocusWent(
            trackedBlocks: inRange.count,
            trackedSeconds: total,
            apps: shares(appSeconds, names: appNames, of: total),
            // Sites as a share of all focus time, so they read against the apps.
            sites: shares(siteSeconds, names: [:], of: total),
            topAppByCategory: categoryApps.compactMapValues { apps in
                apps.max { ($0.value, $1.key) < ($1.value, $0.key) }.map { appNames[$0.key] ?? $0.key }
            }
        )
    }

    // MARK: Headline

    private static func makeHeadline(_ insights: FocusInsights) -> [String] {
        var lines: [String] = []

        if let best = insights.bestDaypart {
            lines.append("Your focus holds best \(best.daypart.phrase): \(percent(best.completionRate)) of blocks finished, \(reachPhrase(best.reachesPerBlock)).")
        }

        if let pull = insights.pulls.first, pull.reaches >= minimumBlocks {
            var line = "\(pull.name) is what you reach for most"
            if let minute = pull.typicalMinute {
                line += minute == 0 ? ", usually right as a block starts" : ", usually about \(minute) min in"
            }
            lines.append(line + ".")
        } else if insights.completedBlocks >= minimumBlocks, insights.totalReaches == 0 {
            lines.append("Not one reach for a guarded app or site in \(insights.completedBlocks) finished blocks.")
        }

        if let sweet = insights.sweetSpot {
            lines.append("\(sweet.band.title) blocks are the ones you finish: \(percent(sweet.completionRate)) of them.")
        }

        if let strict = insights.strict, strict.strictCompletionRate - strict.relaxedCompletionRate >= 0.1 {
            lines.append("Strict mode works for you: \(percent(strict.strictCompletionRate)) of strict blocks finish, against \(percent(strict.relaxedCompletionRate)) without it.")
        }

        if let stuck = insights.goals.stuckMostIn {
            lines.append("\(stuck) is where your goals get stuck most.")
        } else if insights.goals.done >= minimumBlocks {
            lines.append("You've checked off \(insights.goals.done) goals.")
        }

        if insights.cleanStreak >= minimumBlocks {
            lines.append("Your last \(insights.cleanStreak) blocks were clean — nothing reached for.")
        }

        return Array(lines.prefix(3))
    }

    public static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private static func reachPhrase(_ perBlock: Double) -> String {
        if perBlock < 0.05 { return "with almost nothing reached for" }
        let rounded = (perBlock * 10).rounded() / 10
        return "\(rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)) reaches a block"
    }
}
