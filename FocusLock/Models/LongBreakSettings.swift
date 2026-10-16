import Foundation

/// A longer break after every few blocks of a run, so a long afternoon ends
/// each set with real recovery instead of another five minutes.
public struct LongBreakSettings: Codable, Equatable {
    public static let minutesRange = 1...60
    public static let everyRange = 2...8
    public static let minutesOptions = [10, 15, 20, 30]
    public static let everyOptions = [2, 3, 4, 5, 6]

    public var enabled: Bool
    public var minutes: Int
    /// The block whose break is long: every fourth, by default.
    public var every: Int

    public init(enabled: Bool = true, minutes: Int = 15, every: Int = 4) {
        self.enabled = enabled
        self.minutes = Self.clamp(minutes, to: Self.minutesRange)
        self.every = Self.clamp(every, to: Self.everyRange)
    }

    /// Whether block `cycle` of a run ends in the long break.
    public func isLongBreak(afterCycle cycle: Int) -> Bool {
        enabled && cycle >= every && cycle % every == 0
    }

    /// The break that follows block `cycle`. A long break never comes out
    /// shorter than the usual one, and a run without breaks stays without.
    public func breakMinutes(afterCycle cycle: Int, shortBreak: Int) -> Int {
        guard shortBreak > 0, isLongBreak(afterCycle: cycle) else { return shortBreak }
        return max(shortBreak, minutes)
    }

    /// Where block `cycle` sits in its set: 1 through `every`.
    public func positionInSet(cycle: Int) -> Int {
        (max(1, cycle) - 1) % every + 1
    }

    private enum CodingKeys: String, CodingKey {
        case enabled, minutes, every
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = LongBreakSettings()
        self.init(
            enabled: (try? container.decodeIfPresent(Bool.self, forKey: .enabled)) ?? defaults.enabled,
            minutes: (try? container.decodeIfPresent(Int.self, forKey: .minutes)) ?? defaults.minutes,
            every: (try? container.decodeIfPresent(Int.self, forKey: .every)) ?? defaults.every
        )
    }

    private static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(range.upperBound, max(range.lowerBound, value))
    }
}
