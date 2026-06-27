import Foundation

public enum SessionHistoryStatus: String, Codable, Equatable {
    case completed
    case cancelled

    public var displayName: String {
        switch self {
        case .completed:
            return "Completed"
        case .cancelled:
            return "Cancelled"
        }
    }
}

public struct SessionHistoryEntry: Codable, Equatable, Identifiable {
    public var id: UUID
    public var startedAt: Date
    public var endedAt: Date
    public var focusMinutes: Int
    public var breakMinutes: Int
    public var status: SessionHistoryStatus
    public var blockedAppsCount: Int
    public var strictMode: Bool

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        focusMinutes: Int,
        breakMinutes: Int,
        status: SessionHistoryStatus,
        blockedAppsCount: Int,
        strictMode: Bool
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.focusMinutes = max(1, focusMinutes)
        self.breakMinutes = max(0, breakMinutes)
        self.status = status
        self.blockedAppsCount = max(0, blockedAppsCount)
        self.strictMode = strictMode
    }

    public var durationMinutes: Int {
        max(0, Int(endedAt.timeIntervalSince(startedAt) / 60))
    }
}

public struct SessionStats: Equatable {
    public var sessionsCompletedToday: Int
    public var focusMinutesToday: Int
    public var sessionsCompletedThisWeek: Int
    public var focusMinutesThisWeek: Int
    public var totalCompletedSessions: Int
    public var totalSessions: Int

    public static let empty = SessionStats(
        sessionsCompletedToday: 0,
        focusMinutesToday: 0,
        sessionsCompletedThisWeek: 0,
        focusMinutesThisWeek: 0,
        totalCompletedSessions: 0,
        totalSessions: 0
    )
}
