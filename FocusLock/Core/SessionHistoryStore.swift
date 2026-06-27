import Foundation

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

    public func stats(referenceDate: Date = Date(), calendar: Calendar = .current) -> SessionStats {
        let history = loadHistory()
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
}
