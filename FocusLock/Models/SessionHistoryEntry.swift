import Foundation

public enum SessionHistoryStatus: String, Codable, Equatable {
    case completed
    case cancelled
    /// A focus session that ended because LockIn was quit (or relaunched) while
    /// it was still running. The guard is friction, not a cage — but the ledger
    /// records that you walked away.
    case abandoned

    public var displayName: String {
        switch self {
        case .completed:
            return "Completed"
        case .cancelled:
            return "Cancelled"
        case .abandoned:
            return "Abandoned"
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
    public var task: SessionTask?
    public var checkIn: SessionCheckIn?
    public var strictMode: Bool

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        focusMinutes: Int,
        breakMinutes: Int,
        status: SessionHistoryStatus,
        blockedAppsCount: Int,
        strictMode: Bool,
        task: SessionTask? = nil,
        checkIn: SessionCheckIn? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.focusMinutes = max(1, focusMinutes)
        self.breakMinutes = max(0, breakMinutes)
        self.status = status
        self.blockedAppsCount = max(0, blockedAppsCount)
        self.strictMode = strictMode
        self.task = task
        self.checkIn = checkIn
    }

    public var durationMinutes: Int {
        max(0, Int(endedAt.timeIntervalSince(startedAt) / 60))
    }
}

/// One column of the weekly rhythm chart.
public struct DailyFocus: Equatable, Identifiable {
    public var id: Date { date }
    public var date: Date
    public var label: String
    public var minutes: Int
    public var isToday: Bool

    public init(date: Date, label: String, minutes: Int, isToday: Bool) {
        self.date = date
        self.label = label
        self.minutes = max(0, minutes)
        self.isToday = isToday
    }
}

public struct SessionStats: Equatable {
    public var sessionsCompletedToday: Int
    public var focusMinutesToday: Int
    public var sessionsCompletedThisWeek: Int
    public var focusMinutesThisWeek: Int
    public var totalCompletedSessions: Int
    public var totalSessions: Int

    /// Derived from whichever entries are passed in, so the same summary can
    /// describe all of history or a single category.
    public static func make(
        from history: [SessionHistoryEntry],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> SessionStats {
        let completed = history.filter { $0.status == .completed }
        let today = completed.filter { calendar.isDate($0.startedAt, inSameDayAs: referenceDate) }
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: referenceDate)
        let thisWeek = completed.filter { entry in
            guard let weekInterval else {
                return false
            }
            return weekInterval.contains(entry.startedAt)
        }

        return SessionStats(
            sessionsCompletedToday: today.count,
            focusMinutesToday: today.reduce(0) { $0 + $1.focusMinutes },
            sessionsCompletedThisWeek: thisWeek.count,
            focusMinutesThisWeek: thisWeek.reduce(0) { $0 + $1.focusMinutes },
            totalCompletedSessions: completed.count,
            totalSessions: history.count
        )
    }

    public static let empty = SessionStats(
        sessionsCompletedToday: 0,
        focusMinutesToday: 0,
        sessionsCompletedThisWeek: 0,
        focusMinutesThisWeek: 0,
        totalCompletedSessions: 0,
        totalSessions: 0
    )
}
