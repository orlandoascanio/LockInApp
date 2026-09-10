import Foundation

/// What a run added up to, for the host to keep or paste somewhere.
///
/// Built from history rather than tracked as it happens, so quitting the app
/// mid-stream does not cost you the summary.
public struct StreamRecap: Equatable {
    public struct CategoryMinutes: Equatable, Identifiable {
        public var id: String { name }
        public let name: String
        public let minutes: Int

        public init(name: String, minutes: Int) {
            self.name = name
            self.minutes = minutes
        }
    }

    public let blocks: Int
    public let focusMinutes: Int
    public let categories: [CategoryMinutes]
    public let goalsCompleted: Int
    public let companions: Int

    public var isEmpty: Bool { blocks == 0 }

    public init(blocks: Int, focusMinutes: Int, categories: [CategoryMinutes], goalsCompleted: Int, companions: Int) {
        self.blocks = blocks
        self.focusMinutes = focusMinutes
        self.categories = categories
        self.goalsCompleted = goalsCompleted
        self.companions = companions
    }

    public static func make(from history: [SessionHistoryEntry], since: Date, companions: Int = 0) -> StreamRecap {
        let run = history.filter { $0.status == .completed && $0.startedAt >= since }
        let grouped = Dictionary(grouping: run) { $0.task?.category ?? "Uncategorized" }
        let categories = grouped
            .map { CategoryMinutes(name: $0.key, minutes: $0.value.reduce(0) { $0 + $1.focusMinutes }) }
            .sorted { $0.minutes == $1.minutes ? $0.name < $1.name : $0.minutes > $1.minutes }

        return StreamRecap(
            blocks: run.count,
            focusMinutes: run.reduce(0) { $0 + $1.focusMinutes },
            categories: categories,
            goalsCompleted: run.filter { $0.checkIn?.outcome == .done }.count,
            companions: companions
        )
    }

    public var headline: String {
        var parts = ["\(blocks) block\(blocks == 1 ? "" : "s")", Self.duration(focusMinutes)]
        if let top = categories.first {
            parts.append(top.name)
        }
        return parts.joined(separator: " · ")
    }

    /// Everything under the headline, for a surface that wants to size the two
    /// differently rather than print one block of text.
    public var detailLines: [String] {
        var lines: [String] = []
        if categories.count > 1 {
            lines.append(categories.map { "\($0.name) \(Self.duration($0.minutes))" }.joined(separator: " · "))
        }
        if goalsCompleted > 0 {
            lines.append("\(goalsCompleted) goal\(goalsCompleted == 1 ? "" : "s") finished")
        }
        if companions > 0 {
            lines.append("\(companions) \(companions == 1 ? "person" : "people") worked alongside")
        }
        return lines
    }

    /// Plain text on purpose — it goes to a clipboard and from there into a
    /// chat box, a post, or a note, none of which want markup.
    public var text: String {
        var lines = [headline]
        lines.append(contentsOf: detailLines)
        return lines.joined(separator: "\n")
    }

    static func duration(_ minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes)m" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }
}
