import Foundation

/// Counts how many times each guarded app was reached for, per day.
///
/// The blocked-apps list shows a "blocked today" column, which needs a record
/// of interceptions rather than of sessions. Only the current day is kept —
/// this is a glanceable nudge, not an analytics archive, so opening a stale
/// counter from last week would be noise.
public final class BlockActivityStore {
    public let activityURL: URL

    private let baseDirectory: URL
    private let fileManager: FileManager
    private let calendar: Calendar

    private struct Snapshot: Codable {
        var day: Date
        var counts: [String: Int]
    }

    public init(
        baseDirectory: URL? = nil,
        fileManager: FileManager = .default,
        calendar: Calendar = .current
    ) {
        self.fileManager = fileManager
        self.calendar = calendar

        if let baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            self.baseDirectory = AppDirectories.defaultSupportDirectory(fileManager: fileManager)
        }

        activityURL = self.baseDirectory.appendingPathComponent("block-activity.json")
    }

    /// Interceptions recorded for `referenceDate`'s day, keyed by bundle id.
    /// Returns empty once the stored day rolls over.
    public func countsToday(referenceDate: Date = Date()) -> [String: Int] {
        guard let snapshot = load(),
              calendar.isDate(snapshot.day, inSameDayAs: referenceDate)
        else {
            return [:]
        }

        return snapshot.counts
    }

    @discardableResult
    public func recordInterception(bundleId: String, now: Date = Date()) -> [String: Int] {
        var counts = countsToday(referenceDate: now)
        counts[bundleId, default: 0] += 1
        save(Snapshot(day: calendar.startOfDay(for: now), counts: counts))
        return counts
    }

    public func reset() {
        try? fileManager.removeItem(at: activityURL)
    }

    private func load() -> Snapshot? {
        guard let data = try? Data(contentsOf: activityURL) else {
            return nil
        }
        return try? FocusLockJSONCoding.decoder.decode(Snapshot.self, from: data)
    }

    private func save(_ snapshot: Snapshot) {
        do {
            try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
            let data = try FocusLockJSONCoding.encoder.encode(snapshot)
            try data.write(to: activityURL, options: [.atomic])
        } catch {
            FocusLockLog.debug("could not save block activity: \(error.localizedDescription)")
        }
    }
}
