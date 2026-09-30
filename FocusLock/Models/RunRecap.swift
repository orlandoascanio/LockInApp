import Foundation

/// What a run of back-to-back blocks added up to. Rebuilt from history rather
/// than tallied as it goes, so it is right even after a relaunch.
public struct RunRecap: Equatable {
    public var startedAt: Date
    public var blocks: Int
    public var focusMinutes: Int
    public var categories: [(name: String, minutes: Int)]
    public var goals: [(goal: String, done: Bool)]

    public var goalsDone: Int { goals.filter(\.done).count }
    public var isEmpty: Bool { blocks == 0 }

    public static func make(from history: [SessionHistoryEntry], since start: Date) -> RunRecap {
        let completed = history
            .filter { $0.status == .completed && $0.startedAt >= start }
            .sorted { $0.startedAt < $1.startedAt }

        let byCategory = Dictionary(grouping: completed) { entry -> String in
            let name = entry.task?.category ?? ""
            return name.isEmpty ? "Uncategorized" : name
        }
        let categories = byCategory
            .map { (name: $0.key, minutes: $0.value.reduce(0) { $0 + $1.focusMinutes }) }
            .sorted { $0.minutes == $1.minutes ? $0.name < $1.name : $0.minutes > $1.minutes }

        // One line per distinct goal, done if any block that ran with it was
        // checked in as done.
        var goals: [(goal: String, done: Bool)] = []
        for entry in completed {
            guard let goal = entry.task?.goal, !goal.isEmpty else { continue }
            let done = entry.checkIn?.outcome == .done
            if let index = goals.firstIndex(where: { $0.goal == goal }) {
                goals[index].done = goals[index].done || done
            } else {
                goals.append((goal, done))
            }
        }

        return RunRecap(
            startedAt: start,
            blocks: completed.count,
            focusMinutes: completed.reduce(0) { $0 + $1.focusMinutes },
            categories: categories,
            goals: goals
        )
    }

    public var headline: String {
        "\(blocks) block\(blocks == 1 ? "" : "s") · \(Self.duration(focusMinutes)) focused"
    }

    /// Plain text, for the clipboard and for a Discord message.
    public var text: String {
        var lines = ["LockIn recap · \(headline)"]
        if !categories.isEmpty {
            lines.append(categories.map { "\($0.name) \(Self.duration($0.minutes))" }.joined(separator: " · "))
        }
        for goal in goals {
            lines.append("\(goal.done ? "✓" : "–") \(goal.goal)")
        }
        return lines.joined(separator: "\n")
    }

    public static func duration(_ minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes)m" }
        let remainder = minutes % 60
        return remainder == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(remainder)m"
    }

    public static func == (lhs: RunRecap, rhs: RunRecap) -> Bool {
        lhs.startedAt == rhs.startedAt && lhs.blocks == rhs.blocks && lhs.focusMinutes == rhs.focusMinutes
            && lhs.categories.map(\.name) == rhs.categories.map(\.name)
            && lhs.categories.map(\.minutes) == rhs.categories.map(\.minutes)
            && lhs.goals.map(\.goal) == rhs.goals.map(\.goal)
            && lhs.goals.map(\.done) == rhs.goals.map(\.done)
    }
}
