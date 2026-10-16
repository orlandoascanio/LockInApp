import Foundation

/// The chime Quietwhile plays itself when a focus block or a break runs out.
///
/// It plays from the app rather than through a notification, so it still
/// sounds when notifications are off or macOS Focus is silencing them, which
/// is most of the time someone is locked in.
///
/// Every sound macOS ships in /System/Library/Sounds is offered, named as
/// System Settings names them.
public enum TimerEndSound: String, Codable, Equatable, CaseIterable, Identifiable {
    case off
    case basso
    case blow
    case bottle
    case frog
    case funk
    case glass
    case hero
    case morse
    case ping
    case pop
    case purr
    case sosumi
    case submarine
    case tink

    public var id: String { rawValue }

    public var displayName: String {
        self == .off ? "Off" : rawValue.capitalized
    }

    /// The macOS system sound to play, or `nil` for silence.
    public var systemSoundName: String? {
        self == .off ? nil : rawValue.capitalized
    }

    /// Whether going from one phase to the other means a timer ran out, as
    /// opposed to someone starting, skipping, or ending something by hand.
    /// Only the timer's own tick should ask this: a skip moves focus to a
    /// break too, and the person who pressed it doesn't need telling.
    public static func timerRanOut(from previous: SessionPhase, to next: SessionPhase) -> Bool {
        switch (previous, next) {
        case (.focus, .break), (.focus, .completed), (.break, .breakEnded):
            return true
        default:
            return false
        }
    }
}
