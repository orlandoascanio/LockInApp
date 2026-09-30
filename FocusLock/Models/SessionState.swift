import Foundation

public enum SessionPhase: String, Codable, Equatable, CaseIterable {
    case idle
    case focus
    case `break`
    case breakEnded
    case paused
    case completed
    case cancelled

    public var displayName: String {
        switch self {
        case .idle:
            return "Idle"
        case .focus:
            return "Focus"
        case .break:
            return "Break"
        case .breakEnded:
            return "Break Ended"
        case .paused:
            return "Paused"
        case .completed:
            return "Completed"
        case .cancelled:
            return "Cancelled"
        }
    }
}

public struct SessionState: Codable, Equatable {
    public var state: SessionPhase
    public var startedAt: Date
    public var focusMinutes: Int
    public var breakMinutes: Int
    public var currentCycle: Int
    public var blockedAppsCount: Int
    public var task: SessionTask?
    public var strictMode: Bool

    public init(
        state: SessionPhase,
        startedAt: Date,
        focusMinutes: Int,
        breakMinutes: Int,
        currentCycle: Int = 1,
        blockedAppsCount: Int = 0,
        strictMode: Bool = false,
        task: SessionTask? = nil
    ) {
        self.state = state
        self.startedAt = startedAt
        self.focusMinutes = max(1, focusMinutes)
        self.breakMinutes = max(0, breakMinutes)
        self.currentCycle = max(1, currentCycle)
        self.blockedAppsCount = max(0, blockedAppsCount)
        self.strictMode = strictMode
        self.task = task
    }

    private enum CodingKeys: String, CodingKey {
        case state
        case startedAt
        case focusMinutes
        case breakMinutes
        case currentCycle
        case blockedAppsCount
        case strictMode
        case task
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        state = try container.decode(SessionPhase.self, forKey: .state)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        focusMinutes = max(1, try container.decode(Int.self, forKey: .focusMinutes))
        breakMinutes = max(0, try container.decode(Int.self, forKey: .breakMinutes))
        currentCycle = max(1, try container.decodeIfPresent(Int.self, forKey: .currentCycle) ?? 1)
        blockedAppsCount = max(0, try container.decodeIfPresent(Int.self, forKey: .blockedAppsCount) ?? 0)
        task = try container.decodeIfPresent(SessionTask.self, forKey: .task)
        strictMode = try container.decodeIfPresent(Bool.self, forKey: .strictMode) ?? false
    }
}

public struct TimerSnapshot: Equatable {
    public var task: SessionTask?

    /// Which block of the current run this is. Counts up while you keep
    /// choosing "start next block" and resets when the run ends.
    public var currentCycle: Int
    public var phase: SessionPhase
    public var sessionStartedAt: Date?
    public var phaseEndsAt: Date?
    public var remainingSeconds: TimeInterval
    public var focusMinutes: Int
    public var breakMinutes: Int

    /// Whether this block started under strict mode.
    public var isStrict: Bool

    public init(
        phase: SessionPhase = .idle,
        sessionStartedAt: Date? = nil,
        phaseEndsAt: Date? = nil,
        remainingSeconds: TimeInterval = 0,
        focusMinutes: Int = 50,
        breakMinutes: Int = 10,
        task: SessionTask? = nil,
        currentCycle: Int = 1,
        isStrict: Bool = false
    ) {
        self.task = task
        self.isStrict = isStrict
        self.currentCycle = max(1, currentCycle)
        self.phase = phase
        self.sessionStartedAt = sessionStartedAt
        self.phaseEndsAt = phaseEndsAt
        self.remainingSeconds = max(0, remainingSeconds)
        self.focusMinutes = focusMinutes
        self.breakMinutes = breakMinutes
    }

    public var isBlockingPhase: Bool {
        phase == .focus
    }

    /// When the break ran out, for the phase that is waiting on the user. The
    /// timer never persists this separately — a cycle is `startedAt` plus its
    /// two durations — so autopilot can measure the wait even across a snooze,
    /// which rewrites `sessionStartedAt`.
    public var breakEndedAt: Date? {
        guard phase == .breakEnded, let sessionStartedAt else {
            return nil
        }

        return sessionStartedAt.addingTimeInterval(TimeInterval((focusMinutes + breakMinutes) * 60))
    }

    public var formattedRemaining: String {
        let wholeSeconds = max(0, Int(remainingSeconds.rounded(.up)))
        let minutes = wholeSeconds / 60
        let seconds = wholeSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
