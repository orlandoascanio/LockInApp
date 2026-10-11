import Foundation

public enum SessionHistoryError: LocalizedError {
    case blockNotFound

    public var errorDescription: String? {
        switch self {
        case .blockNotFound:
            return "that focus block is no longer in your history"
        }
    }
}

public final class SessionHistoryStore {
    public let historyURL: URL

    private let baseDirectory: URL
    private let fileManager: FileManager

    public init(
        baseDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager

        if let baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            self.baseDirectory = AppDirectories.defaultSupportDirectory(fileManager: fileManager)
        }

        historyURL = self.baseDirectory.appendingPathComponent("session-history.jsonl")
    }

    public func prepareDirectory() throws {
        try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    }

    public func loadHistory() -> [SessionHistoryEntry] {
        do {
            try prepareDirectory()

            guard fileManager.fileExists(atPath: historyURL.path) else {
                return []
            }

            let contents = try String(contentsOf: historyURL, encoding: .utf8)
            return contents
                .split(separator: "\n", omittingEmptySubsequences: true)
                .compactMap { line in
                    guard let data = String(line).data(using: .utf8) else {
                        return nil
                    }
                    return try? FocusLockJSONCoding.decoder.decode(SessionHistoryEntry.self, from: data)
                }
                .sorted { $0.startedAt > $1.startedAt }
        } catch {
            return []
        }
    }

    public func append(_ entry: SessionHistoryEntry) throws {
        try prepareDirectory()
        let lineData = try FocusLockJSONCoding.lineEncoder.encode(entry)
        var data = Data()

        if fileManager.fileExists(atPath: historyURL.path) {
            data = try Data(contentsOf: historyURL)
            if !data.isEmpty, data.last != UInt8(ascii: "\n") {
                data.append(UInt8(ascii: "\n"))
            }
        }

        data.append(lineData)
        data.append(UInt8(ascii: "\n"))
        try data.write(to: historyURL, options: [.atomic])
    }

    /// Replace only the matching record, preserving any unrecognized lines.
    public func saveCheckIn(taskID: UUID, checkIn: SessionCheckIn) throws {
        let contents = try String(contentsOf: historyURL, encoding: .utf8)
        var found = false
        let lines = try contents.components(separatedBy: "\n").map { line -> String in
            guard let data = line.data(using: .utf8),
                  var entry = try? FocusLockJSONCoding.decoder.decode(SessionHistoryEntry.self, from: data),
                  entry.task?.id == taskID, entry.status == .completed else { return line }
            entry.checkIn = checkIn
            found = true
            return String(decoding: try FocusLockJSONCoding.lineEncoder.encode(entry), as: UTF8.self)
        }
        guard found else { throw SessionHistoryError.blockNotFound }
        try lines.joined(separator: "\n").write(to: historyURL, atomically: true, encoding: .utf8)
    }

    /// Focus minutes for each day of the week containing `referenceDate`,
    /// ordered from the calendar's first weekday. Days with no completed
    /// sessions come back at zero rather than being omitted, so the chart keeps
    /// seven evenly spaced columns.
    public func weeklyRhythm(referenceDate: Date = Date(), calendar: Calendar = .current) -> [DailyFocus] {
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start else {
            return []
        }
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
        return dailyFocus(on: days, referenceDate: referenceDate, calendar: calendar)
    }

    /// The last `count` days ending today, so a chart never opens on a blank
    /// week just because the calendar turned over on Sunday.
    public func recentRhythm(days count: Int = 7, referenceDate: Date = Date(), calendar: Calendar = .current) -> [DailyFocus] {
        let today = calendar.startOfDay(for: referenceDate)
        let days = (0..<max(1, count)).reversed().compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }
        return dailyFocus(on: days, referenceDate: referenceDate, calendar: calendar)
    }

    /// The last seven days ending today against the seven before them.
    public func recentSummary(referenceDate: Date = Date(), calendar: Calendar = .current) -> RecentFocusSummary {
        let completed = loadHistory().filter { $0.status == .completed }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: referenceDate)) ?? referenceDate
        guard
            let start = calendar.date(byAdding: .day, value: -7, to: tomorrow),
            let previousStart = calendar.date(byAdding: .day, value: -14, to: tomorrow)
        else {
            return RecentFocusSummary(totalMinutes: 0, previousMinutes: 0)
        }

        func minutes(from start: Date, to end: Date) -> Int {
            completed
                .filter { $0.startedAt >= start && $0.startedAt < end }
                .reduce(0) { $0 + $1.focusMinutes }
        }

        return RecentFocusSummary(
            totalMinutes: minutes(from: start, to: tomorrow),
            previousMinutes: minutes(from: previousStart, to: start)
        )
    }

    /// The most recent day, today included, with a completed block: what a
    /// returning person can pick up from.
    public func lastActiveDay(referenceDate: Date = Date(), calendar: Calendar = .current) -> DailyFocus? {
        let latest = loadHistory()
            .filter { $0.status == .completed && $0.startedAt <= referenceDate }
            .map(\.startedAt)
            .max()
        guard let latest else { return nil }
        return dailyFocus(on: [calendar.startOfDay(for: latest)], referenceDate: referenceDate, calendar: calendar).first
    }

    private func dailyFocus(on days: [Date], referenceDate: Date, calendar: Calendar) -> [DailyFocus] {
        let completed = loadHistory().filter { $0.status == .completed }

        return days.map { day in
            let entries = completed.filter { calendar.isDate($0.startedAt, inSameDayAs: day) }
            let minutes = entries.reduce(0) { $0 + $1.focusMinutes }

            var minutesByCategory: [String: Int] = [:]
            for entry in entries {
                guard let category = entry.task?.category, !category.isEmpty else { continue }
                minutesByCategory[category, default: 0] += entry.focusMinutes
            }
            let categories = minutesByCategory
                .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
                .map { DailyFocus.CategoryTime(name: $0.key, minutes: $0.value) }

            // "Mon" rather than "M": two T's and two S's are a guess.
            let weekdayIndex = calendar.component(.weekday, from: day) - 1
            let symbols = calendar.shortWeekdaySymbols
            let label = symbols.indices.contains(weekdayIndex) ? symbols[weekdayIndex] : ""

            return DailyFocus(
                date: day,
                label: label,
                minutes: minutes,
                isToday: calendar.isDate(day, inSameDayAs: referenceDate),
                isFuture: day > calendar.startOfDay(for: referenceDate),
                sessions: entries.count,
                categories: categories
            )
        }
    }

    /// This week's total, and last week's up to the same moment.
    public func weekSummary(referenceDate: Date = Date(), calendar: Calendar = .current) -> WeekFocusSummary {
        let completed = loadHistory().filter { $0.status == .completed }
        guard
            let thisWeek = calendar.dateInterval(of: .weekOfYear, for: referenceDate),
            let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeek.start),
            let lastWeekSameMoment = calendar.date(byAdding: .weekOfYear, value: -1, to: referenceDate)
        else {
            return WeekFocusSummary(totalMinutes: 0, lastWeekSoFarMinutes: 0, elapsedDays: 1)
        }

        func minutes(from start: Date, to end: Date) -> Int {
            completed
                .filter { $0.startedAt >= start && $0.startedAt < end }
                .reduce(0) { $0 + $1.focusMinutes }
        }

        let elapsed = (calendar.dateComponents(
            [.day],
            from: thisWeek.start,
            to: calendar.startOfDay(for: referenceDate)
        ).day ?? 0) + 1

        return WeekFocusSummary(
            totalMinutes: minutes(from: thisWeek.start, to: thisWeek.end),
            lastWeekSoFarMinutes: minutes(from: lastWeekStart, to: lastWeekSameMoment),
            elapsedDays: elapsed
        )
    }

    /// Consecutive days ending today with at least one completed session. Today
    /// having none does not break a streak that is still alive from yesterday —
    /// it is only broken once a full day passes with nothing completed.
    public func focusStreak(referenceDate: Date = Date(), calendar: Calendar = .current) -> Int {
        let days = Set(
            loadHistory()
                .filter { $0.status == .completed }
                .map { calendar.startOfDay(for: $0.startedAt) }
        )

        guard !days.isEmpty else {
            return 0
        }

        var cursor = calendar.startOfDay(for: referenceDate)

        // A day with nothing yet does not end the streak until it is over.
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                return 0
            }
            cursor = yesterday
        }

        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previous
        }

        return streak
    }

    public func stats(referenceDate: Date = Date(), calendar: Calendar = .current) -> SessionStats {
        SessionStats.make(from: loadHistory(), referenceDate: referenceDate, calendar: calendar)
    }
}
