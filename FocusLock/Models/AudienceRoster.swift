import Foundation

/// Decides when the host is actually told someone is waiting.
///
/// Twenty people arriving at once is one interruption, not twenty. But once
/// the queue has been cleared, the next person should get through straight
/// away rather than serving out someone else's cooldown.
public struct AudienceAlertThrottle: Equatable {
    public static let interval: TimeInterval = 15

    private var lastAlert: Date?

    public init() {}

    public mutating func shouldAlert(waiting: Int, at date: Date) -> Bool {
        guard waiting > 0 else {
            lastAlert = nil
            return false
        }
        if let lastAlert, date.timeIntervalSince(lastAlert) < Self.interval {
            return false
        }
        lastAlert = date
        return true
    }
}

/// One screenful of the roster, and how long it stays up.
public struct RosterPage: Equatable {
    public let tasks: [AudienceTask]
    public let index: Int
    public let count: Int

    /// Zero when everyone fits and nothing needs to rotate.
    public let interval: TimeInterval

    public var rotates: Bool { count > 1 }

    public init(tasks: [AudienceTask], index: Int, count: Int, interval: TimeInterval) {
        self.tasks = tasks
        self.index = index
        self.count = count
        self.interval = interval
    }
}

/// What the room has got through over the whole stream, rather than what
/// happens to be on the current page.
///
/// The wall pages, and old rows fall off the end of a long session, so the
/// rows on screen are always a slice. The tally is the part that lets an hour
/// of work look like an hour of work.
public struct AudienceTally: Codable, Equatable {
    public private(set) var completed = 0
    public private(set) var total = 0

    public init(completed: Int = 0, total: Int = 0) {
        self.completed = completed
        self.total = total
    }

    public var isEmpty: Bool { total == 0 }

    /// "12/18" — done over posted, the way every co-working overlay writes it.
    public var label: String { "\(completed)/\(total)" }

    mutating func posted() { total += 1 }
    mutating func finished() { completed += 1 }

    /// A row the host took down never happened, as far as the count goes —
    /// otherwise taking one bad task off screen leaves the number climbing
    /// with nothing to show for it. Rows aged off a long wall are not
    /// withdrawn: those were shown, and the count is the only record left.
    mutating func withdrew(_ tasks: [AudienceTask]) {
        total -= tasks.count
        completed -= tasks.filter(\.isDone).count
    }
}

/// One viewer's task, as it appears on the audience window.
public struct AudienceTask: Codable, Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public var text: String
    public var joinedAt: Date
    public var isDone: Bool

    public init(id: UUID = UUID(), name: String, text: String, joinedAt: Date, isDone: Bool = false) {
        self.id = id
        self.name = name
        self.text = text
        self.joinedAt = joinedAt
        self.isDone = isDone
    }

    /// How long they have been working alongside you. Under a minute reads as
    /// "now": showing nothing at all made someone who had just arrived look
    /// like a row the clock had forgotten, and "0m" reads as a stalled one.
    public func elapsedLabel(at date: Date) -> String {
        let minutes = Int(date.timeIntervalSince(joinedAt) / 60)
        guard minutes >= 1 else { return "now" }
        guard minutes >= 60 else { return "\(minutes)m" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }
}

/// Everyone working alongside the host, and the rules that decide what is
/// allowed to reach the broadcast.
///
/// Every feed — chat, or the host typing one in by hand — goes through
/// `submit`, so there is one place where a stranger's text is sanitized,
/// rate limited, and (by default) held for approval. Nothing else may append
/// to `admitted` directly.
public struct AudienceRoster: Equatable {
    public enum Rejection: Equatable {
        case empty
        case blocked
        case tooSoon
        case containsLink
        case blockedWord

        /// Whether this was someone getting it wrong or someone trying it on.
        /// Only the second kind counts toward a block.
        public var isDeliberate: Bool {
            self == .containsLink || self == .blockedWord
        }
    }

    public enum Submission: Equatable {
        case admitted(AudienceTask)
        case held(AudienceTask)
        case rejected(Rejection)
    }

    public static let maxTaskLength = 60
    public static let maxNameLength = 20
    public static let maxTracked = 200
    public static let minimumInterval: TimeInterval = 10

    /// Showing everyone would push the countdown off a 720p canvas, so the
    /// window shows a slice and counts the rest.
    public static let defaultVisible = 8

    /// A full pass through every page should finish inside a focus block, so
    /// nobody sits unseen for a whole session. Pages still have to be readable,
    /// hence the floor, and a two-page roster should not flicker, hence the
    /// ceiling.
    public static let fullCycleTarget: TimeInterval = 300
    public static let minimumPageInterval: TimeInterval = 20
    public static let maximumPageInterval: TimeInterval = 60

    public private(set) var admitted: [AudienceTask] = []
    public private(set) var held: [AudienceTask] = []
    public private(set) var blocked: Set<String> = []
    public private(set) var tally = AudienceTally()

    /// Off by default: unreviewed text from strangers on your own broadcast is
    /// your platform strike, not theirs.
    public var autoApprove = false

    /// Words that never reach the wall. Seeded with a default list and meant
    /// to be extended by the host — see `AudienceFilter`.
    public var blockedTerms: Set<String> = AudienceFilter.defaultTerms

    /// Two deliberate attempts and they are done for this stream. Someone
    /// testing what they can get away with will keep going otherwise, and you
    /// should not have to watch the queue to stop them.
    public static let strikesBeforeBlock = 2

    private var lastSubmission: [String: Date] = [:]
    private var strikes: [String: Int] = [:]

    /// Rotation is derived from elapsed time rather than driven by a timer, so
    /// the window shows the same page no matter when it was opened or redrawn.
    public private(set) var anchor: Date

    public init(autoApprove: Bool = false, now: Date = Date()) {
        self.autoApprove = autoApprove
        self.anchor = now
    }

    // MARK: - Reading

    /// Arrival order rather than most-recent-first: a list that reshuffles
    /// every time someone types is hard to read on a stream, and the people who
    /// showed up first keep their place.
    public func visible(limit: Int = defaultVisible) -> [AudienceTask] {
        Array(admitted.prefix(max(0, limit)))
    }

    public func overflow(limit: Int = defaultVisible) -> Int {
        max(0, admitted.count - max(0, limit))
    }

    public var isEmpty: Bool { admitted.isEmpty }

    /// Whether these two would be written to disk identically.
    ///
    /// Not `==`, which also compares the settings that are deliberately never
    /// saved — approval and the word list. Toggling either is not a reason to
    /// rewrite the wall, and a strike nobody can see still is.
    public func matchesSavedState(of other: AudienceRoster) -> Bool {
        admitted == other.admitted
            && held == other.held
            && blocked == other.blocked
            && tally == other.tally
            && anchor == other.anchor
            && strikes == other.strikes
    }

    /// Rows are tasks, not people — someone on their third task is still one
    /// person working alongside you. Anything that says "people" counts these.
    public var peopleCount: Int {
        Set(admitted.map { $0.name.lowercased() }).count
    }

    /// Everyone gets their name on screen. Once more people are here than fit,
    /// the list becomes pages that cycle on their own — the alternative is
    /// showing the same eight names for two hours while everyone else watches
    /// a list they are not on.
    public func page(size: Int, at date: Date) -> RosterPage {
        let size = max(1, size)
        guard !admitted.isEmpty else {
            return RosterPage(tasks: [], index: 0, count: 1, interval: 0)
        }

        let count = Int((Double(admitted.count) / Double(size)).rounded(.up))
        guard count > 1 else {
            return RosterPage(tasks: admitted, index: 0, count: 1, interval: 0)
        }

        let interval = min(Self.maximumPageInterval,
                           max(Self.minimumPageInterval, Self.fullCycleTarget / Double(count)))
        let elapsed = max(0, date.timeIntervalSince(anchor))
        let index = Int(elapsed / interval) % count
        let start = index * size
        return RosterPage(
            tasks: Array(admitted[start..<min(start + size, admitted.count)]),
            index: index,
            count: count,
            interval: interval
        )
    }

    // MARK: - Writing

    @discardableResult
    public mutating func submit(name rawName: String, text rawText: String, now: Date = Date()) -> Submission {
        let name = Self.sanitize(rawName, limit: Self.maxNameLength)
        let text = Self.sanitize(rawText, limit: Self.maxTaskLength)

        guard !name.isEmpty, !text.isEmpty else { return .rejected(.empty) }
        let key = name.lowercased()
        guard !blocked.contains(key) else { return .rejected(.blocked) }
        guard !Self.containsLink(text) else { return strike(name, .containsLink) }
        guard AudienceFilter.isAllowed(text, terms: blockedTerms) else { return strike(name, .blockedWord) }
        // The name goes on screen too, so it is held to the same standard.
        guard AudienceFilter.isAllowed(name, terms: blockedTerms) else { return strike(name, .blockedWord) }

        if let last = lastSubmission[key], now.timeIntervalSince(last) < Self.minimumInterval {
            return .rejected(.tooSoon)
        }
        lastSubmission[key] = now

        // One task in flight per person. Typing another while the first is
        // still open is a correction, so it replaces in place and keeps their
        // slot and their id rather than jumping to the end of the wall.
        if let index = held.lastIndex(where: { $0.name.lowercased() == key }) {
            held[index].text = text
            return .held(held[index])
        }
        if let index = admitted.lastIndex(where: { $0.name.lowercased() == key }), !admitted[index].isDone {
            admitted[index].text = text
            return .admitted(admitted[index])
        }

        // Typing one after finishing is a second task, and the finished row
        // stays struck through where it is. Watching a list of crossed-off
        // work grow is most of why anyone joins one of these.
        let task = AudienceTask(name: name, text: text, joinedAt: arrival(of: key) ?? now)
        if autoApprove {
            admit(task)
            return .admitted(task)
        }
        held.append(task)
        return .held(task)
    }

    @discardableResult
    public mutating func approve(_ id: UUID) -> Bool {
        guard let index = held.firstIndex(where: { $0.id == id }) else { return false }
        admit(held.remove(at: index))
        return true
    }

    public mutating func approveAll() {
        let queued = held
        held.removeAll()
        queued.forEach { admit($0) }
    }

    @discardableResult
    public mutating func remove(_ id: UUID) -> Bool {
        let before = admitted.count + held.count
        tally.withdrew(admitted.filter { $0.id == id })
        admitted.removeAll { $0.id == id }
        held.removeAll { $0.id == id }
        return admitted.count + held.count < before
    }

    /// Blocking takes their text off screen as well as stopping the next one —
    /// the point is to end it in one click while you are live.
    public mutating func block(name: String) {
        let key = Self.sanitize(name, limit: Self.maxNameLength).lowercased()
        guard !key.isEmpty else { return }
        blocked.insert(key)
        tally.withdrew(admitted.filter { $0.name.lowercased() == key })
        admitted.removeAll { $0.name.lowercased() == key }
        held.removeAll { $0.name.lowercased() == key }
    }

    public mutating func unblock(name: String) {
        blocked.remove(Self.sanitize(name, limit: Self.maxNameLength).lowercased())
    }

    @discardableResult
    public mutating func markDone(name: String) -> Bool {
        let key = Self.sanitize(name, limit: Self.maxNameLength).lowercased()
        // Their newest open row: an older one they already crossed off should
        // not be finished twice, and neither should the count move twice.
        guard let index = admitted.lastIndex(where: { $0.name.lowercased() == key && !$0.isDone }) else {
            return false
        }
        admitted[index].isDone = true
        tally.finished()
        return true
    }

    /// The roster belongs to one stream. Blocks outlive it; tasks do not.
    public mutating func clear(now: Date = Date()) {
        admitted.removeAll()
        held.removeAll()
        tally = AudienceTally()
        lastSubmission.removeAll()
        strikes.removeAll()
        anchor = now
    }

    /// Applies what a viewer typed. Returns nil when the message was not a
    /// command, so a feed can ignore ordinary chat without inspecting it.
    @discardableResult
    public mutating func apply(_ command: AudienceCommand, from name: String, now: Date = Date()) -> Submission? {
        switch command {
        case .task(let text):
            return submit(name: name, text: text, now: now)
        case .done:
            markDone(name: name)
            return nil
        }
    }

    /// Counts a deliberate attempt, and blocks once there have been enough.
    private mutating func strike(_ name: String, _ reason: Rejection) -> Submission {
        let key = name.lowercased()
        strikes[key, default: 0] += 1
        if strikes[key, default: 0] >= Self.strikesBeforeBlock {
            block(name: name)
            return .rejected(.blocked)
        }
        return .rejected(reason)
    }

    private mutating func admit(_ task: AudienceTask) {
        admitted.append(task)
        tally.posted()
        makeRoom()
    }

    /// A long stream fills the wall, and something has to go. Finished rows go
    /// first, oldest first: a crossed-off task has had its moment and its
    /// number is safe in the count, while dropping someone's open task takes a
    /// person who is still working off a wall they can see. Only once the
    /// finished ones are gone does anything else move.
    ///
    /// Ageing rows off is the wall running out of room, not those tasks being
    /// withdrawn, so none of this touches the count.
    private mutating func makeRoom() {
        guard admitted.count > Self.maxTracked else { return }

        var excess = admitted.count - Self.maxTracked
        var kept: [AudienceTask] = []
        kept.reserveCapacity(admitted.count)
        for task in admitted {
            if excess > 0, task.isDone {
                excess -= 1
            } else {
                kept.append(task)
            }
        }
        // Everyone still working, and still too many: the oldest give way.
        if excess > 0 {
            kept.removeFirst(min(excess, kept.count))
        }
        admitted = kept
    }

    /// When someone posts their second task, they have been here since their
    /// first — so the new row inherits that arrival rather than reading "now"
    /// for a person who has been working alongside you for an hour.
    private func arrival(of key: String) -> Date? {
        (admitted + held)
            .filter { $0.name.lowercased() == key }
            .map(\.joinedAt)
            .min()
    }

    // MARK: - Sanitizing

    /// Newlines, control characters, and runaway length are all ways to break
    /// the layout of a live window, so they are removed before anything else
    /// looks at the text.
    static func sanitize(_ value: String, limit: Int) -> String {
        let cleaned = value.unicodeScalars
            .map { CharacterSet.controlCharacters.contains($0) || CharacterSet.newlines.contains($0) ? " " : Character($0) }
        let collapsed = String(cleaned)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return String(collapsed.prefix(limit)).trimmingCharacters(in: .whitespaces)
    }

    /// Advertising is the failure mode a public command invites, so anything
    /// that reads as a link is refused rather than trimmed.
    static let linkTLDs = ["com", "net", "org", "io", "gg", "ly", "tv", "co", "me", "xyz", "link", "app", "dev"]

    static func containsLink(_ text: String) -> Bool {
        let lowered = text.lowercased()
        if lowered.contains("://") || lowered.contains("www.") {
            return true
        }
        return lowered.split(separator: " ").contains { token in
            // Anything after a slash is a path; the host is what makes it a link.
            let host = token.split(separator: "/").first.map(String.init) ?? String(token)
            guard let dot = host.lastIndex(of: ".") else { return false }
            let suffix = host[host.index(after: dot)...].filter { $0.isLetter }
            return !suffix.isEmpty && linkTLDs.contains(String(suffix))
        }
    }
}

/// The wall is written down between launches, so quitting mid-stream does not
/// cost you an hour of crossed-off work. What is saved is what a stranger's
/// words earned: the rows, the queue, the count, and who has been blocked or
/// is one attempt away from it.
///
/// What is deliberately not saved is anything the app already knows on its own
/// — whether approval is automatic, and the blocked-word list. Both are read
/// back from config and from `blocked-words.txt` at launch, and a stale copy
/// here would quietly outrank a list the host had edited in the meantime.
extension AudienceRoster: Codable {
    private enum CodingKeys: String, CodingKey {
        case admitted, held, blocked, tally, anchor, strikes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(now: try container.decodeIfPresent(Date.self, forKey: .anchor) ?? Date())
        admitted = try container.decodeIfPresent([AudienceTask].self, forKey: .admitted) ?? []
        held = try container.decodeIfPresent([AudienceTask].self, forKey: .held) ?? []
        blocked = try container.decodeIfPresent(Set<String>.self, forKey: .blocked) ?? []
        tally = try container.decodeIfPresent(AudienceTally.self, forKey: .tally) ?? AudienceTally()
        strikes = try container.decodeIfPresent([String: Int].self, forKey: .strikes) ?? [:]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(admitted, forKey: .admitted)
        try container.encode(held, forKey: .held)
        try container.encode(blocked, forKey: .blocked)
        try container.encode(tally, forKey: .tally)
        try container.encode(anchor, forKey: .anchor)
        try container.encode(strikes, forKey: .strikes)
    }
}
