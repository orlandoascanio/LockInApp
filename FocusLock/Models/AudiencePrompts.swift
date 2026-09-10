import Foundation

/// The one line on the audience window that changes while a block runs.
///
/// A silent screen holding still for fifty minutes reads as dead, and a
/// stream with no voice on it has only this line to do the inviting. It moves
/// slowly on purpose: a line that changes every few seconds reads as an advert
/// rather than an invitation.
public enum AudiencePrompts {
    public static let interval: TimeInterval = 75

    /// The last stretch of a block belongs to whoever is finishing something.
    /// A fresh invitation there is an interruption, so the line goes quiet.
    public static let quietTail: TimeInterval = 120

    /// The line that actually converts a watcher into a participant.
    public static let primary = "Type \(AudienceCommand.advertised) what you're working on — you'll appear on the wall"

    public static let secondary = [
        "New here? Say what you are working on and settle in",
        "One small thing counts — it does not have to be impressive",
        "\"Stuck\" is a fine answer. Say so in chat",
        "Everyone here is working on something different"
    ]

    /// Only worth showing once there is a wall to be ticked off.
    public static let withCompany = "Finished yours? Type !done and it gets a tick"

    /// Nil while the line should be silent.
    public static func line(remaining: TimeInterval, elapsed: TimeInterval, hasCompany: Bool) -> String? {
        guard remaining > quietTail, elapsed >= 0 else { return nil }

        var others = secondary
        if hasCompany {
            others.append(withCompany)
        }

        // The instruction takes every other slot rather than an equal share:
        // it is the only line that tells someone what to actually do.
        let slot = Int(elapsed / interval)
        guard slot.isMultiple(of: 2) == false else { return primary }
        return others[(slot / 2) % others.count]
    }
}
