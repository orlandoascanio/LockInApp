import Foundation

/// A snapshot of the host's task, captured when a focus block starts.
public struct SessionTask: Codable, Equatable, Identifiable {
    public var id: UUID
    public var goal: String
    public var category: String
    public var shared: Bool

    public init(id: UUID = UUID(), goal: String, category: String, shared: Bool) {
        self.id = id
        self.goal = String(goal.trimmingCharacters(in: .whitespacesAndNewlines).prefix(160))
        self.category = String(category.trimmingCharacters(in: .whitespacesAndNewlines).prefix(32))
        self.shared = shared
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

public enum StreamMotion: String, Codable, CaseIterable, Identifiable {
    case off, subtle, ambient

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
    public var description: String {
        switch self {
        case .off: return "A still background and instant updates."
        case .subtle: return "Gentle transitions when the timer, phase, or audience changes."
        case .ambient: return "Gentle transitions with a slowly drifting background glow."
        }
    }
}

public struct StreamSettings: Codable, Equatable {
    public var enabled = false
    public var goal = ""
    public var category = "Study"
    public var categories = ["Study", "Coding", "Writing", "Work", "Personal"]
    public var darkAppearance = true
    public var motion: StreamMotion = .ambient
    public var showGoal = true

    /// On by default: a command nobody can see is a command nobody uses, and
    /// the wall stays empty for want of two words on screen.
    public var showCommands = true

    /// How many blocks you mean to run, so the audience can see "Block 2 of 4"
    /// and decide whether to settle in.
    public var plannedBlocks = 4

    /// The one line under the countdown that says what kind of room this is.
    public var invitation = StreamPreset.bringYourOwnTask.invitation

    /// The Twitch channel whose chat feeds the wall. Read-only and anonymous;
    /// LockIn never posts.
    public var twitchChannel = ""

    /// Whether the wall of viewer tasks appears on the audience window.
    public var showRoster = true

    /// A sound when someone is waiting. Off by default: if OBS is capturing
    /// desktop audio, this goes out on the broadcast.
    public var alertSound = false

    /// A notification banner when someone is waiting. Off by default: a banner
    /// is drawn on the screen, and the screen may be what you are capturing.
    public var alertBanner = false

    /// Whether viewer tasks go straight to the wall. Off by default: text you
    /// have not read should not appear on your own broadcast.
    public var autoApproveTasks = false

    /// Opened at the start of a stream. LockIn never plays or rebroadcasts
    /// audio; this only hands the link to whichever app owns it.
    public var playlistURL = ""

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case enabled, goal, category, categories, darkAppearance, motion, showGoal, showCommands
        case plannedBlocks, invitation, playlistURL, autoApproveTasks, showRoster
        case alertSound, alertBanner, twitchChannel
    }

    /// Written by hand rather than synthesized: a synthesized decoder ignores
    /// these defaults and throws on any key it does not find, which would fail
    /// the whole `AppConfig` decode and reset every setting the moment a new
    /// field lands here. Each field falls back instead, so settings files from
    /// older and newer builds both load.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = StreamSettings()
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? fallback.enabled
        goal = try container.decodeIfPresent(String.self, forKey: .goal) ?? fallback.goal
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? fallback.category
        categories = try container.decodeIfPresent([String].self, forKey: .categories) ?? fallback.categories
        darkAppearance = try container.decodeIfPresent(Bool.self, forKey: .darkAppearance) ?? fallback.darkAppearance
        // An unfamiliar mode from a newer build must not reset the host's settings.
        let motionName = try container.decodeIfPresent(String.self, forKey: .motion)
        motion = motionName.flatMap(StreamMotion.init(rawValue:)) ?? fallback.motion
        showGoal = try container.decodeIfPresent(Bool.self, forKey: .showGoal) ?? fallback.showGoal
        showCommands = try container.decodeIfPresent(Bool.self, forKey: .showCommands) ?? fallback.showCommands
        plannedBlocks = try container.decodeIfPresent(Int.self, forKey: .plannedBlocks) ?? fallback.plannedBlocks
        invitation = try container.decodeIfPresent(String.self, forKey: .invitation) ?? fallback.invitation
        playlistURL = try container.decodeIfPresent(String.self, forKey: .playlistURL) ?? fallback.playlistURL
        autoApproveTasks = try container.decodeIfPresent(Bool.self, forKey: .autoApproveTasks) ?? fallback.autoApproveTasks
        showRoster = try container.decodeIfPresent(Bool.self, forKey: .showRoster) ?? fallback.showRoster
        alertSound = try container.decodeIfPresent(Bool.self, forKey: .alertSound) ?? fallback.alertSound
        alertBanner = try container.decodeIfPresent(Bool.self, forKey: .alertBanner) ?? fallback.alertBanner
        twitchChannel = try container.decodeIfPresent(String.self, forKey: .twitchChannel) ?? fallback.twitchChannel
        plannedBlocks = min(12, max(1, plannedBlocks))

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

    public var task: SessionTask { SessionTask(goal: goal, category: category, shared: enabled) }

    /// Only schemes that belong to a music or video app, so a settings file
    /// cannot talk the app into launching something else.
    public var playlistDestination: URL? {
        let trimmed = playlistURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() else {
            return nil
        }
        return ["https", "http", "spotify", "music"].contains(scheme) ? url : nil
    }

    /// A finished goal should not follow you into the next block. A goal you
    /// already rewrote while the block was running is left alone.
    @discardableResult
    public mutating func clearCompletedGoal(matching task: SessionTask?, outcome: CheckInOutcome) -> Bool {
        guard outcome == .done, let task, !goal.isEmpty, goal == task.goal else { return false }
        goal = ""
        return true
    }
}

/// Public copy for each phase; the audience sees no host controls or private notes.
public struct StreamPresentation: Equatable {
    public var phase: SessionPhase
    public init(phase: SessionPhase) { self.phase = phase }
    public var title: String {
        switch phase {
        case .focus: return "Time to focus"
        case .break: return "Take a break"
        case .breakEnded: return "Ready for another round?"
        case .completed: return "Nice work, everyone"
        case .cancelled: return "That's a wrap"
        case .paused: return "Taking a moment"
        case .idle: return "Bring your own task"
        }
    }
    public var prompt: String {
        switch phase {
        case .focus: return "Your task, your pace. Let's make a little progress together."
        case .break, .breakEnded, .completed: return "Check in: what moved forward? Share a win or a sticking point in chat."
        case .cancelled: return "Thanks for showing up. Every bit of progress counts."
        case .paused: return "Stretch, grab some water, and settle back in."
        case .idle: return "Pick one small goal. Share it in chat, then work alongside us."
        }
    }
}
