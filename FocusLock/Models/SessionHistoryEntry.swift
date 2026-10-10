import Foundation

public enum SessionHistoryStatus: String, Codable, Equatable {
    case completed
    case cancelled
    /// A focus session that ended because Quietwhile was quit (or relaunched) while
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
    /// The short weekday name, such as "Mon".
    public var label: String
    public var minutes: Int
    public var isToday: Bool
    /// After today, so nothing could have happened yet.
    public var isFuture: Bool
    public var sessions: Int
    /// Every category focused on that day, the most time first.
    public var categories: [CategoryTime]

    public struct CategoryTime: Equatable {
        public var name: String
        public var minutes: Int

        public init(name: String, minutes: Int) {
            self.name = name
            self.minutes = minutes
        }
    }

    public init(
        date: Date,
        label: String,
        minutes: Int,
        isToday: Bool,
        isFuture: Bool = false,
        sessions: Int = 0,
        categories: [CategoryTime] = []
    ) {
        self.date = date
        self.label = label
        self.minutes = max(0, minutes)
        self.isToday = isToday
        self.isFuture = isFuture
        self.sessions = max(0, sessions)
        self.categories = categories
    }
}

/// The week as a whole, for the line above the chart.
public struct WeekFocusSummary: Equatable {
    public var totalMinutes: Int
    /// Last week up to the same moment, so Tuesday is never measured against
    /// a whole finished week.
    public var lastWeekSoFarMinutes: Int
    /// Days of this week so far, today included.
    public var elapsedDays: Int

    public init(totalMinutes: Int, lastWeekSoFarMinutes: Int, elapsedDays: Int) {
        self.totalMinutes = max(0, totalMinutes)
        self.lastWeekSoFarMinutes = max(0, lastWeekSoFarMinutes)
        self.elapsedDays = max(1, elapsedDays)
    }

    /// "+40m vs last week", or the daily average when last week has nothing
    /// to compare against.
    public var detail: String {
        guard lastWeekSoFarMinutes > 0 else {
            let average = totalMinutes / elapsedDays
            return average > 0 ? "Avg \(RunRecap.duration(average)) a day" : "Nothing yet this week"
        }
        let difference = totalMinutes - lastWeekSoFarMinutes
        if difference == 0 { return "Same as last week" }
        let sign = difference > 0 ? "+" : "−"
        return "\(sign)\(RunRecap.duration(abs(difference))) vs last week"
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
