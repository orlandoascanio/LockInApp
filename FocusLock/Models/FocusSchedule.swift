import Foundation

/// A recurring window in which LockIn starts focus on its own — "weekdays,
/// 9:00 to 12:00". Blocks keep rolling one after another until the window
/// closes; a block that is running when it closes is allowed to finish.
public struct FocusSchedule: Codable, Equatable, Hashable, Identifiable {
    public var id: UUID
    public var name: String
    public var isEnabled: Bool
    /// `Calendar` weekdays: 1 is Sunday, 7 is Saturday.
    public var weekdays: Set<Int>
    /// Minutes after midnight. An end before the start runs past midnight.
    public var startMinute: Int
    public var endMinute: Int
    /// Blocks this schedule starts run under strict mode.
    public var strict: Bool

    public static let weekdaysOnly: Set<Int> = [2, 3, 4, 5, 6]

    public init(
        id: UUID = UUID(),
        name: String = "Work",
        isEnabled: Bool = true,
        weekdays: Set<Int> = FocusSchedule.weekdaysOnly,
        startMinute: Int = 9 * 60,
        endMinute: Int = 12 * 60,
        strict: Bool = false
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.weekdays = weekdays.filter { (1...7).contains($0) }
        self.startMinute = Self.clampMinute(startMinute)
        self.endMinute = Self.clampMinute(endMinute)
        self.strict = strict
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, isEnabled, weekdays, startMinute, endMinute, strict
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Schedule"
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        weekdays = (try container.decodeIfPresent(Set<Int>.self, forKey: .weekdays) ?? Self.weekdaysOnly)
            .filter { (1...7).contains($0) }
        startMinute = Self.clampMinute(try container.decodeIfPresent(Int.self, forKey: .startMinute) ?? 540)
        endMinute = Self.clampMinute(try container.decodeIfPresent(Int.self, forKey: .endMinute) ?? 720)
        strict = try container.decodeIfPresent(Bool.self, forKey: .strict) ?? false
    }

    public var durationMinutes: Int {
        let span = endMinute - startMinute
        return span > 0 ? span : span + 24 * 60
    }

    private static func clampMinute(_ minute: Int) -> Int {
        min(24 * 60 - 1, max(0, minute))
    }
}

/// One concrete run of a schedule — this Tuesday, 9:00 to 12:00.
public struct ScheduleOccurrence: Equatable {
    public var schedule: FocusSchedule
    public var start: Date
    public var end: Date

    /// Stable for the occurrence, so "I stopped this one" can be remembered
    /// without stopping next Tuesday's too.
    public var key: String {
        "\(schedule.id.uuidString)@\(Int(start.timeIntervalSince1970))"
    }

    public func contains(_ date: Date) -> Bool {
        date >= start && date < end
    }
}

public enum ScheduleEvaluator {
    /// The window open at `now`, if any. When two overlap, the one that began
    /// first wins, so a run is not handed back and forth.
    public static func activeOccurrence(
        in schedules: [FocusSchedule],
        at now: Date,
        calendar: Calendar = .current
    ) -> ScheduleOccurrence? {
        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return nil }

        return schedules
            .filter { $0.isEnabled && startMinuteDiffersFromEnd($0) }
            .flatMap { schedule in
                [yesterday, today].compactMap { occurrence(of: schedule, on: $0, calendar: calendar) }
            }
            .filter { $0.contains(now) }
            .min { $0.start < $1.start }
    }

    /// The next window to open strictly after `now`, looking a week ahead.
    public static func nextOccurrence(
        in schedules: [FocusSchedule],
        after now: Date,
        calendar: Calendar = .current
    ) -> ScheduleOccurrence? {
        let today = calendar.startOfDay(for: now)
        return schedules
            .filter { $0.isEnabled && startMinuteDiffersFromEnd($0) }
            .flatMap { schedule in
                (0...7).compactMap { offset -> ScheduleOccurrence? in
                    guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
                    return occurrence(of: schedule, on: day, calendar: calendar)
                }
            }
            .filter { $0.start > now }
            .min { $0.start < $1.start }
    }

    /// The occurrence that starts on `day`, if the schedule runs that weekday.
    static func occurrence(of schedule: FocusSchedule, on day: Date, calendar: Calendar) -> ScheduleOccurrence? {
        guard schedule.weekdays.contains(calendar.component(.weekday, from: day)) else { return nil }
        // Built from components rather than by adding seconds, so a
        // daylight-saving change does not shift the window by an hour.
        guard
            let start = calendar.date(
                bySettingHour: schedule.startMinute / 60,
                minute: schedule.startMinute % 60,
                second: 0,
                of: day
            ),
            let endDay = schedule.endMinute > schedule.startMinute
                ? day
                : calendar.date(byAdding: .day, value: 1, to: day),
            let end = calendar.date(
                bySettingHour: schedule.endMinute / 60,
                minute: schedule.endMinute % 60,
                second: 0,
                of: endDay
            )
        else {
            return nil
        }
        return ScheduleOccurrence(schedule: schedule, start: start, end: end)
    }

    private static func startMinuteDiffersFromEnd(_ schedule: FocusSchedule) -> Bool {
        schedule.startMinute != schedule.endMinute && !schedule.weekdays.isEmpty
    }
}
