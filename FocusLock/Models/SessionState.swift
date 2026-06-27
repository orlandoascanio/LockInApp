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
    public var strictMode: Bool

    public init(
        state: SessionPhase,
        startedAt: Date,
        focusMinutes: Int,
        breakMinutes: Int,
        currentCycle: Int = 1,
        blockedAppsCount: Int = 0,
        strictMode: Bool = false
    ) {
        self.state = state
        self.startedAt = startedAt
        self.focusMinutes = max(1, focusMinutes)
        self.breakMinutes = max(0, breakMinutes)
        self.currentCycle = max(1, currentCycle)
        self.blockedAppsCount = max(0, blockedAppsCount)
        self.strictMode = strictMode
    }

    private enum CodingKeys: String, CodingKey {
        case state
        case startedAt
        case focusMinutes
        case breakMinutes
        case currentCycle
        case blockedAppsCount
        case strictMode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        state = try container.decode(SessionPhase.self, forKey: .state)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        focusMinutes = max(1, try container.decode(Int.self, forKey: .focusMinutes))
        breakMinutes = max(0, try container.decode(Int.self, forKey: .breakMinutes))
        currentCycle = max(1, try container.decodeIfPresent(Int.self, forKey: .currentCycle) ?? 1)
        blockedAppsCount = max(0, try container.decodeIfPresent(Int.self, forKey: .blockedAppsCount) ?? 0)
        strictMode = try container.decodeIfPresent(Bool.self, forKey: .strictMode) ?? false
    }
}

public struct TimerSnapshot: Equatable {
    public var phase: SessionPhase
    public var sessionStartedAt: Date?
    public var phaseEndsAt: Date?
    public var remainingSeconds: TimeInterval
    public var focusMinutes: Int
    public var breakMinutes: Int

    public init(
        phase: SessionPhase = .idle,
        sessionStartedAt: Date? = nil,
        phaseEndsAt: Date? = nil,
        remainingSeconds: TimeInterval = 0,
        focusMinutes: Int = 25,
        breakMinutes: Int = 5
    ) {
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

    public var formattedRemaining: String {
        let wholeSeconds = max(0, Int(remainingSeconds.rounded(.up)))
        let minutes = wholeSeconds / 60
        let seconds = wholeSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
