import Foundation

public enum SessionAnalyticsPeriod: String, CaseIterable, Identifiable {
    case sevenDays
    case thirtyDays
    case allTime

    public var id: String { rawValue }
}

public enum SessionAnalyticsGranularity: Equatable {
    case day
    case week
    case month
}

public struct SessionAnalyticsPoint: Equatable, Identifiable {
    public var id: Date { startDate }
    public var startDate: Date
    public var minutes: Int
    public var completedSessions: Int

    public init(startDate: Date, minutes: Int, completedSessions: Int) {
        self.startDate = startDate
        self.minutes = max(0, minutes)
        self.completedSessions = max(0, completedSessions)
    }
}

public struct WeekdayFocusSummary: Equatable, Identifiable {
    public var id: Date { date }
    public var date: Date
    public var minutes: Int

    public init(date: Date, minutes: Int) {
        self.date = date
        self.minutes = max(0, minutes)
    }
}

public struct SessionOutcomeSummary: Equatable {
    public var completed: Int
    public var cancelled: Int
    public var abandoned: Int

    public var total: Int {
        completed + cancelled + abandoned
    }

    public init(completed: Int, cancelled: Int, abandoned: Int) {
        self.completed = max(0, completed)
        self.cancelled = max(0, cancelled)
        self.abandoned = max(0, abandoned)
    }
}

public struct SessionAnalyticsSnapshot: Equatable {
    public var period: SessionAnalyticsPeriod
    public var granularity: SessionAnalyticsGranularity
    public var startDate: Date
    public var endDate: Date
    public var timeline: [SessionAnalyticsPoint]
    public var weekdayFocus: [WeekdayFocusSummary]
    public var outcomes: SessionOutcomeSummary
    public var totalFocusMinutes: Int
    public var completedSessions: Int
    public var activeDays: Int
    public var averageSessionMinutes: Int
    public var averageFocusMinutesPerActiveDay: Int
    public var completionRate: Double
    public var longestSessionMinutes: Int
    public var bestDay: Date?
    public var bestDayMinutes: Int

    public static func empty(
        period: SessionAnalyticsPeriod,
        referenceDate: Date,
        calendar: Calendar
    ) -> SessionAnalyticsSnapshot {
        let day = calendar.startOfDay(for: referenceDate)
        return SessionAnalyticsSnapshot(
            period: period,
            granularity: .day,
            startDate: day,
            endDate: day,
            timeline: [],
            weekdayFocus: [],
            outcomes: SessionOutcomeSummary(completed: 0, cancelled: 0, abandoned: 0),
            totalFocusMinutes: 0,
            completedSessions: 0,
            activeDays: 0,
            averageSessionMinutes: 0,
            averageFocusMinutesPerActiveDay: 0,
            completionRate: 0,
            longestSessionMinutes: 0,
            bestDay: nil,
            bestDayMinutes: 0
        )
    }
}

public enum SessionAnalytics {
    public static func snapshot(
        history: [SessionHistoryEntry],
        period: SessionAnalyticsPeriod,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> SessionAnalyticsSnapshot {
        let referenceDay = calendar.startOfDay(for: referenceDate)
        guard let endExclusive = calendar.date(byAdding: .day, value: 1, to: referenceDay) else {
            return .empty(period: period, referenceDate: referenceDate, calendar: calendar)
        }

        let requestedStart: Date
        switch period {
        case .sevenDays:
            requestedStart = calendar.date(byAdding: .day, value: -6, to: referenceDay) ?? referenceDay
        case .thirtyDays:
            requestedStart = calendar.date(byAdding: .day, value: -29, to: referenceDay) ?? referenceDay
        case .allTime:
            requestedStart = history
                .map { calendar.startOfDay(for: $0.startedAt) }
                .min() ?? referenceDay
        }

        let entries = history.filter {
            $0.startedAt >= requestedStart && $0.startedAt < endExclusive
        }
        let completed = entries.filter { $0.status == .completed }

        let granularity = granularity(
            from: requestedStart,
            through: referenceDay,
            period: period,
            calendar: calendar
        )
        let timeline = makeTimeline(
            completed: completed,
            from: requestedStart,
            until: endExclusive,
            granularity: granularity,
            calendar: calendar
        )

        let totalsByDay = Dictionary(grouping: completed) {
            calendar.startOfDay(for: $0.startedAt)
        }
        .mapValues { dayEntries in
            dayEntries.reduce(0) { $0 + $1.focusMinutes }
        }

        let totalFocusMinutes = completed.reduce(0) { $0 + $1.focusMinutes }
        let activeDays = totalsByDay.count
        let best = totalsByDay.max { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key < rhs.key
            }
            return lhs.value < rhs.value
        }

        let outcomes = SessionOutcomeSummary(
            completed: completed.count,
            cancelled: entries.filter { $0.status == .cancelled }.count,
            abandoned: entries.filter { $0.status == .abandoned }.count
        )

        return SessionAnalyticsSnapshot(
            period: period,
            granularity: granularity,
            startDate: requestedStart,
            endDate: referenceDay,
            timeline: timeline,
            weekdayFocus: makeWeekdayFocus(
                completed: completed,
                referenceDate: referenceDate,
                calendar: calendar
            ),
            outcomes: outcomes,
            totalFocusMinutes: totalFocusMinutes,
            completedSessions: completed.count,
            activeDays: activeDays,
            averageSessionMinutes: completed.isEmpty ? 0 : totalFocusMinutes / completed.count,
            averageFocusMinutesPerActiveDay: activeDays == 0 ? 0 : totalFocusMinutes / activeDays,
            completionRate: outcomes.total == 0 ? 0 : Double(outcomes.completed) / Double(outcomes.total),
            longestSessionMinutes: completed.map(\.focusMinutes).max() ?? 0,
            bestDay: best?.key,
            bestDayMinutes: best?.value ?? 0
        )
    }

    private static func granularity(
        from start: Date,
        through end: Date,
        period: SessionAnalyticsPeriod,
        calendar: Calendar
    ) -> SessionAnalyticsGranularity {
        guard period == .allTime else {
            return .day
        }

        let days = (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
        if days <= 31 {
            return .day
        }
        if days <= 180 {
            return .week
        }
        return .month
    }

    private static func makeTimeline(
        completed: [SessionHistoryEntry],
        from start: Date,
        until endExclusive: Date,
        granularity: SessionAnalyticsGranularity,
        calendar: Calendar
    ) -> [SessionAnalyticsPoint] {
        var cursor: Date
        switch granularity {
        case .day:
            cursor = start
        case .week:
            cursor = calendar.dateInterval(of: .weekOfYear, for: start)?.start ?? start
        case .month:
            cursor = calendar.dateInterval(of: .month, for: start)?.start ?? start
        }

        var points: [SessionAnalyticsPoint] = []
        while cursor < endExclusive {
            guard let next = nextBucket(after: cursor, granularity: granularity, calendar: calendar) else {
                break
            }

            let bucket = completed.filter {
                $0.startedAt >= cursor && $0.startedAt < next
            }
            points.append(SessionAnalyticsPoint(
                startDate: cursor,
                minutes: bucket.reduce(0) { $0 + $1.focusMinutes },
                completedSessions: bucket.count
            ))
            cursor = next
        }

        return points
    }

    private static func nextBucket(
        after date: Date,
        granularity: SessionAnalyticsGranularity,
        calendar: Calendar
    ) -> Date? {
        switch granularity {
        case .day:
            return calendar.date(byAdding: .day, value: 1, to: date)
        case .week:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .month:
            return calendar.date(byAdding: .month, value: 1, to: date)
        }
    }

    private static func makeWeekdayFocus(
        completed: [SessionHistoryEntry],
        referenceDate: Date,
        calendar: Calendar
    ) -> [WeekdayFocusSummary] {
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start else {
            return []
        }

        let totals = Dictionary(grouping: completed) {
            calendar.component(.weekday, from: $0.startedAt)
        }
        .mapValues { entries in
            entries.reduce(0) { $0 + $1.focusMinutes }
        }

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else {
                return nil
            }
            let weekday = calendar.component(.weekday, from: date)
            return WeekdayFocusSummary(date: date, minutes: totals[weekday] ?? 0)
        }
    }
}
