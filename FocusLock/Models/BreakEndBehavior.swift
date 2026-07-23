import Foundation

/// What happens once a break has run out and the next focus block is waiting.
public enum BreakEndBehavior: String, Codable, Equatable, CaseIterable, Identifiable {
    /// Show the break-ended card and wait for a decision. The original behaviour.
    case ask
    /// Roll straight into the next focus block with no prompt.
    case startImmediately
    /// Wait a while, and if nothing happens take over the screen with a
    /// countdown before starting the next block anyway.
    case autopilot

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .ask:
            return "Ask Me"
        case .startImmediately:
            return "Start Now"
        case .autopilot:
            return "Autopilot"
        }
    }

    public var helperText: String {
        switch self {
        case .ask:
            return "The break-ended card waits for you. Nothing starts until you say so."
        case .startImmediately:
            return "The next focus block begins the moment the break runs out."
        case .autopilot:
            return "If you wander off, LockIn takes the screen back, counts down, and starts the next block for you."
        }
    }
}
