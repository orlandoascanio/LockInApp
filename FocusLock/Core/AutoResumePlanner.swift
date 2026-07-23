import Foundation

/// Where autopilot is in its wait after a break ended.
public enum AutoResumeStage: Equatable {
    /// Still inside the grace window — the break-ended card is enough.
    case waiting(secondsUntilCountdown: TimeInterval)
    /// Grace is spent: the takeover screen is up and counting down.
    case countdown(secondsRemaining: TimeInterval)
    /// The countdown ran out. Start the next focus block.
    case start
}

/// Pure arithmetic behind autopilot: given when the wait started, decide whether
/// to keep waiting, warn, or start. Kept free of AppKit so the whole schedule is
/// testable without a running app.
public struct AutoResumePlanner: Codable, Equatable {
    /// How long the user gets after a break ends before the takeover appears.
    public var graceMinutes: Int
    /// How long the takeover counts down before focus starts on its own.
    public var countdownSeconds: Int

    /// Choices offered in Settings. The grace period is the one people tune;
    /// the countdown is mostly about how much warning feels fair.
    public static let graceOptions = [5, 10, 15, 20, 30]
    public static let countdownOptions = [30, 60, 120, 300]

    public static let `default` = AutoResumePlanner()

    public init(graceMinutes: Int = 10, countdownSeconds: Int = 60) {
        self.graceMinutes = min(120, max(1, graceMinutes))
        self.countdownSeconds = min(600, max(10, countdownSeconds))
    }

    public var graceSeconds: TimeInterval {
        TimeInterval(graceMinutes * 60)
    }

    /// `since` is the moment the wait began: when the break ended, or when the
    /// user last pushed the takeover away.
    public func stage(since: Date, now: Date) -> AutoResumeStage {
        let elapsed = max(0, now.timeIntervalSince(since))

        guard elapsed >= graceSeconds else {
            return .waiting(secondsUntilCountdown: graceSeconds - elapsed)
        }

        let countdownElapsed = elapsed - graceSeconds
        let total = TimeInterval(countdownSeconds)

        guard countdownElapsed < total else {
            return .start
        }

        return .countdown(secondsRemaining: total - countdownElapsed)
    }

    /// Fraction of the countdown already spent, for the takeover's ring.
    public func countdownProgress(remainingSeconds: TimeInterval) -> Double {
        let total = Double(countdownSeconds)

        guard total > 0 else {
            return 1
        }

        return min(1, max(0, (total - remainingSeconds) / total))
    }
}

public extension AutoResumeStage {
    var isCountdown: Bool {
        if case .countdown = self {
            return true
        }
        return false
    }
}
