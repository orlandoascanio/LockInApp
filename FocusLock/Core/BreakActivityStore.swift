import Foundation

/// What each break suggested, and which suggestions were actually done.
///
/// The pick is stored so the notification, the Focus page and the HUD agree
/// on it, so it survives a relaunch mid-break, and so the next break can avoid
/// repeating it. Completions are kept for a few weeks to say things like
/// "You stretched 4 times this week" and "3 glasses today".
public final class BreakActivityStore {
    /// One break's suggestion.
    public struct Pick: Codable, Equatable {
        /// Identifies the break: the session start and the block it follows.
        public var breakKey: String
        public var kind: BreakSuggestionKind
        /// Suggestions passed over this break with "Another one".
        public var passedOver: [BreakSuggestionKind]
        /// "Did it" was pressed, or a guide ran to the end.
        public var done: Bool

        public init(breakKey: String, kind: BreakSuggestionKind, passedOver: [BreakSuggestionKind] = [], done: Bool = false) {
            self.breakKey = breakKey
            self.kind = kind
            self.passedOver = passedOver
            self.done = done
        }
    }

    public struct Completion: Codable, Equatable {
        public var kind: BreakSuggestionKind
        public var date: Date

        public init(kind: BreakSuggestionKind, date: Date) {
            self.kind = kind
            self.date = date
        }
    }

    /// How long completions are kept.
    static let retention: TimeInterval = 35 * 24 * 60 * 60

    public let activityURL: URL

    private let fileManager: FileManager
    private var snapshot: Snapshot

    private struct Snapshot: Codable {
        var pick: Pick?
        var completions: [Completion] = []

        init(pick: Pick? = nil, completions: [Completion] = []) {
            self.pick = pick
            self.completions = completions
        }

        // A kind from a newer build drops that one entry, not the whole file.
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            pick = try? container.decodeIfPresent(Pick.self, forKey: .pick)
            let raw = (try? container.decodeIfPresent([Lossy<Completion>].self, forKey: .completions)) ?? []
            completions = raw.compactMap(\.value)
        }
    }

    private struct Lossy<Value: Decodable>: Decodable {
        var value: Value?
        init(from decoder: Decoder) throws {
            value = try? Value(from: decoder)
        }
    }

    public init(baseDirectory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let directory = baseDirectory ?? AppDirectories.defaultSupportDirectory(fileManager: fileManager)
        activityURL = directory.appendingPathComponent("break-activity.json")
        snapshot = Self.load(from: activityURL) ?? Snapshot()
    }

    /// The identifier a break is stored under.
    public static func breakKey(sessionStartedAt: Date, cycle: Int) -> String {
        "\(Int(sessionStartedAt.timeIntervalSince1970))#\(cycle)"
    }

    public var pick: Pick? {
        snapshot.pick
    }

    public func savePick(_ pick: Pick) {
        snapshot.pick = pick
        save()
    }

    /// Counts the current pick as done, once per break.
    @discardableResult
    public func markDone(at date: Date = Date()) -> Bool {
        guard var pick = snapshot.pick, !pick.done else { return false }
        pick.done = true
        snapshot.pick = pick
        snapshot.completions.append(Completion(kind: pick.kind, date: date))
        snapshot.completions.removeAll { date.timeIntervalSince($0.date) > Self.retention }
        save()
        return true
    }

    public func count(of kind: BreakSuggestionKind, from start: Date, to end: Date = .distantFuture) -> Int {
        snapshot.completions.filter { $0.kind == kind && $0.date >= start && $0.date < end }.count
    }

    public func countToday(of kind: BreakSuggestionKind, now: Date = Date(), calendar: Calendar = .current) -> Int {
        count(of: kind, from: calendar.startOfDay(for: now))
    }

    public func countThisWeek(of kind: BreakSuggestionKind, now: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        return count(of: kind, from: week.start, to: week.end)
    }

    private static func load(from url: URL) -> Snapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? FocusLockJSONCoding.decoder.decode(Snapshot.self, from: data)
    }

    private func save() {
        do {
            try fileManager.createDirectory(at: activityURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try FocusLockJSONCoding.encoder.encode(snapshot)
            try data.write(to: activityURL, options: .atomic)
        } catch {
            FocusLockLog.debug("could not save break activity: \(error.localizedDescription)")
        }
    }
}
