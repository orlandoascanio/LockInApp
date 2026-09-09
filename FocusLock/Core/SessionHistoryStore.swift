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
        let completed = loadHistory().filter { $0.status == .completed }

        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start else {
            return []
        }

        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else {
                return nil
            }

            let minutes = completed
                .filter { calendar.isDate($0.startedAt, inSameDayAs: day) }
                .reduce(0) { $0 + $1.focusMinutes }

            let weekdayIndex = calendar.component(.weekday, from: day) - 1
            let symbols = calendar.veryShortWeekdaySymbols
            let label = symbols.indices.contains(weekdayIndex) ? symbols[weekdayIndex] : ""

            return DailyFocus(
                date: day,
                label: label,
                minutes: minutes,
                isToday: calendar.isDate(day, inSameDayAs: referenceDate)
            )
        }
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
