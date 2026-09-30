import Foundation

/// What a focus block was for, captured when the block starts.
public struct SessionTask: Codable, Equatable, Identifiable {
    public var id: UUID
    public var goal: String
    public var category: String

    public init(id: UUID = UUID(), goal: String, category: String) {
        self.id = id
        self.goal = String(goal.trimmingCharacters(in: .whitespacesAndNewlines).prefix(160))
        self.category = String(category.trimmingCharacters(in: .whitespacesAndNewlines).prefix(32))
    }
}

public enum CheckInOutcome: String, Codable, CaseIterable, Identifiable {
    case done, progress, stuck
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .done: return "Goal done"
        case .progress: return "Made progress"
        case .stuck: return "Got stuck"
        }
    }
}

public struct SessionCheckIn: Codable, Equatable {
    public var outcome: CheckInOutcome
    public var note: String
    public init(outcome: CheckInOutcome, note: String) {
        self.outcome = outcome
        self.note = String(note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
    }
}

/// The goal and category the next block will run with.
public struct FocusTaskSettings: Codable, Equatable {
    public var goal = ""
    public var category = "Study"
    public var categories = ["Study", "Coding", "Writing", "Work", "Personal"]

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case goal, category, categories
    }

    /// Each field falls back on its own, so a file from an older or newer
    /// build never resets the rest of the settings.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = FocusTaskSettings()
        goal = try container.decodeIfPresent(String.self, forKey: .goal) ?? fallback.goal
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? fallback.category
        categories = try container.decodeIfPresent([String].self, forKey: .categories) ?? fallback.categories

        // The picker has nothing to select from if a hand-edited file empties
        // these, and a category outside the list would show as blank.
        if categories.isEmpty {
            categories = fallback.categories
        }
        if !categories.contains(category) {
            category = categories[0]
        }
    }

    @discardableResult
    public mutating func addCategory(_ name: String) -> Bool {
        let clean = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(32))
        guard !clean.isEmpty else { return false }
        if let existing = categories.first(where: { $0.lowercased() == clean.lowercased() }) {
            category = existing
        } else {
            categories.append(clean)
            category = clean
        }
        return true
    }

    public var task: SessionTask { SessionTask(goal: goal, category: category) }

    /// A finished goal should not follow you into the next block. A goal you
    /// already rewrote while the block was running is left alone.
    @discardableResult
    public mutating func clearCompletedGoal(matching task: SessionTask?, outcome: CheckInOutcome) -> Bool {
        guard outcome == .done, let task, !goal.isEmpty, goal == task.goal else { return false }
        goal = ""
        return true
    }
}
