import Foundation

/// Everything the widget draws, written by the app into the shared app-group
/// container. The widget never reads the app's own files: it is sandboxed and
/// can only see the group container.
public struct WidgetSnapshot: Codable, Equatable {
    public var phase: SessionPhase
    public var phaseEndsAt: Date?
    public var focusMinutes: Int
    public var breakMinutes: Int
    public var goal: String
    public var isStrict: Bool
    public var focusMinutesToday: Int
    public var sessionsToday: Int
    public var streak: Int
    public var weekMinutes: [Int]
    public var nextScheduleName: String?
    public var nextScheduleStart: Date?
    public var updatedAt: Date

    public init(
        phase: SessionPhase = .idle,
        phaseEndsAt: Date? = nil,
        focusMinutes: Int = 50,
        breakMinutes: Int = 10,
        goal: String = "",
        isStrict: Bool = false,
        focusMinutesToday: Int = 0,
        sessionsToday: Int = 0,
        streak: Int = 0,
        weekMinutes: [Int] = [],
        nextScheduleName: String? = nil,
        nextScheduleStart: Date? = nil,
        updatedAt: Date = Date()
    ) {
        self.phase = phase
        self.phaseEndsAt = phaseEndsAt
        self.focusMinutes = focusMinutes
        self.breakMinutes = breakMinutes
        self.goal = goal
        self.isStrict = isStrict
        self.focusMinutesToday = focusMinutesToday
        self.sessionsToday = sessionsToday
        self.streak = streak
        self.weekMinutes = weekMinutes
        self.nextScheduleName = nextScheduleName
        self.nextScheduleStart = nextScheduleStart
        self.updatedAt = updatedAt
    }

    public var isRunning: Bool {
        phase == .focus || phase == .break
    }

    /// A running phase whose end has passed means the app stopped writing —
    /// quit or crashed — so the widget should not keep claiming a session.
    public func isStale(at now: Date) -> Bool {
        guard isRunning, let phaseEndsAt else { return false }
        return now > phaseEndsAt.addingTimeInterval(60)
    }
}

/// Reads and writes the widget snapshot in the app-group container.
public enum SharedContainer {
    /// Team-prefixed so it needs no provisioning profile on macOS.
    public static let appGroupIdentifier = "5BVWR47BQX.com.lockin.shared"

    /// Posted by the widget's buttons; the app listens and acts.
    public static let commandNotificationPrefix = "com.lockin.app.command."

    public static var directory: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    public static var snapshotURL: URL? {
        directory?.appendingPathComponent("widget-snapshot.json")
    }

    public static func load() -> WidgetSnapshot? {
        guard let url = snapshotURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? FocusLockJSONCoding.decoder.decode(WidgetSnapshot.self, from: data)
    }

    @discardableResult
    public static func save(_ snapshot: WidgetSnapshot) -> Bool {
        guard let directory, let url = snapshotURL else { return false }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try FocusLockJSONCoding.encoder.encode(snapshot)
            try data.write(to: url, options: [.atomic])
            return true
        } catch {
            return false
        }
    }
}
