import Foundation

/// What this Mac knows about how one installed app is used. Gathered by the
/// app from Spotlight's launch records, the Dock, and what is running; it
/// never leaves the Mac.
public struct AppUsage: Equatable, Identifiable {
    public var name: String
    public var bundleId: String
    public var url: URL
    /// `LSApplicationCategoryType`, when the app declares one.
    public var category: String?
    public var lastUsed: Date?
    public var useCount: Int
    public var isRunning: Bool
    public var isInDock: Bool

    public var id: String { bundleId }

    public init(
        name: String,
        bundleId: String,
        url: URL,
        category: String? = nil,
        lastUsed: Date? = nil,
        useCount: Int = 0,
        isRunning: Bool = false,
        isInDock: Bool = false
    ) {
        self.name = name
        self.bundleId = bundleId
        self.url = url
        self.category = category
        self.lastUsed = lastUsed
        self.useCount = useCount
        self.isRunning = isRunning
        self.isInDock = isInDock
    }
}

/// The welcome guide's two lists, most used first.
public struct AppSuggestionList: Equatable {
    /// Chat, games, video and the like: what people usually mean to guard.
    public var likely: [AppUsage]
    /// Everything else that sees real use here. Offered, not assumed: for
    /// some people the pull is an app nobody would call a distraction.
    public var frequent: [AppUsage]

    public init(likely: [AppUsage] = [], frequent: [AppUsage] = []) {
        self.likely = likely
        self.frequent = frequent
    }

    public var isEmpty: Bool { likely.isEmpty && frequent.isEmpty }
}

public enum AppSuggestions {
    /// How far back a launch still counts as "you use this".
    public static let recencyWindowDays: Double = 30

    /// Apps people most often say they open without meaning to, whatever
    /// category they file themselves under (Slack calls itself business).
    public static let knownDistractions: Set<String> = [
        "com.hnc.Discord",
        "com.tinyspeck.slackmacgap",
        "com.apple.MobileSMS",
        "net.whatsapp.WhatsApp",
        "ru.keepcoder.Telegram",
        "org.whispersystems.signal-desktop",
        "com.microsoft.teams2",
        "com.tencent.xinWeChat",
        "jp.naver.line.mac",
        "com.apple.mail",
        "com.valvesoftware.steam",
        "com.epicgames.EpicGamesLauncher",
        "com.apple.TV",
        "com.apple.news"
    ]

    static let distractingCategories: Set<String> = [
        "public.app-category.social-networking",
        "public.app-category.entertainment",
        "public.app-category.news",
        "public.app-category.sports",
        "public.app-category.video"
    ]

    /// Categories that are the work itself. Guarding these by suggestion
    /// would be guarding the thing the block is for.
    static let workCategories: Set<String> = [
        "public.app-category.developer-tools",
        "public.app-category.utilities",
        "public.app-category.productivity",
        "public.app-category.business",
        "public.app-category.finance",
        "public.app-category.graphics-design",
        "public.app-category.education",
        "public.app-category.reference",
        "public.app-category.medical",
        "public.app-category.photography"
    ]

    /// How strongly the evidence says "this app gets used here". Zero means
    /// installed and nothing more.
    public static func score(_ app: AppUsage, now: Date) -> Double {
        var score = 0.0
        if let lastUsed = app.lastUsed {
            let days = max(0, now.timeIntervalSince(lastUsed) / 86_400)
            score += 2 * max(0, 1 - days / recencyWindowDays)
        }
        if app.useCount > 0 {
            // 1,000 launches and 10,000 launches are the same habit.
            score += 2 * min(1, log10(1 + Double(app.useCount)) / 3)
        }
        if app.isRunning { score += 1.5 }
        if app.isInDock { score += 1 }
        return score
    }

    static func isLikelyDistraction(_ app: AppUsage) -> Bool {
        if knownDistractions.contains(app.bundleId) { return true }
        guard let category = app.category else { return false }
        return distractingCategories.contains(category) || category.contains("games")
    }

    /// - Parameter excluding: bundle ids never to offer: apps LockIn cannot
    ///   guard, and browsers, which are guarded site by site instead.
    public static func rank(
        _ apps: [AppUsage],
        now: Date,
        excluding: Set<String> = [],
        likelyLimit: Int = 9,
        frequentLimit: Int = 6
    ) -> AppSuggestionList {
        var seen = Set<String>()
        let candidates = apps.filter { !excluding.contains($0.bundleId) && seen.insert($0.bundleId).inserted }
        let scored = candidates.map { (app: $0, score: score($0, now: now)) }

        func ordered(_ entries: [(app: AppUsage, score: Double)]) -> [AppUsage] {
            entries
                .sorted {
                    $0.score != $1.score
                        ? $0.score > $1.score
                        : $0.app.name.localizedCaseInsensitiveCompare($1.app.name) == .orderedAscending
                }
                .map(\.app)
        }

        // A known distraction is worth offering even with no sign of use:
        // some apps never get a launch record. It just goes last. Anything
        // else has to show it is used, or every preinstalled game would
        // turn up.
        let likely = ordered(scored.filter { entry in
            isLikelyDistraction(entry.app)
                && (entry.score > 0 || knownDistractions.contains(entry.app.bundleId))
        })

        let frequent = ordered(scored.filter { entry in
            guard entry.score > 0, !isLikelyDistraction(entry.app) else { return false }
            guard let category = entry.app.category else { return true }
            return !workCategories.contains(category)
        })

        return AppSuggestionList(
            likely: Array(likely.prefix(likelyLimit)),
            frequent: Array(frequent.prefix(frequentLimit))
        )
    }

    /// The reason an app is on the list, in a couple of words; `nil` when
    /// there is no sign it is used.
    public static func evidence(for app: AppUsage, now: Date, calendar: Calendar = .current) -> String? {
        if app.isRunning { return "Open now" }
        if let lastUsed = app.lastUsed {
            let days = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: lastUsed),
                to: calendar.startOfDay(for: now)
            ).day ?? 0
            if days <= 0 { return "Used today" }
            if days == 1 { return "Used yesterday" }
            if Double(days) <= recencyWindowDays { return "Used \(days) days ago" }
        }
        if app.isInDock { return "In your Dock" }
        return nil
    }
}
