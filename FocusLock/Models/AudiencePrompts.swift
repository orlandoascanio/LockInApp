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

    /// The standing invitation for a window that is already showing the
    /// commands: saying them twice on one screen is not twice the invitation.
    public static let welcome = "New here? Say what you are working on and settle in"

    public static let secondary = [
        welcome,
        "One small thing counts — it does not have to be impressive",
        "\"Stuck\" is a fine answer. Say so in chat",
        "Everyone here is working on something different"
    ]

    /// Only worth showing once there is a wall to be ticked off.
    public static let withCompany = "Finished yours? Type !done and it gets a tick"

    /// Nil while the line should be silent.
    ///
    /// `commandsShown` is the legend standing on the same screen. With it up,
    /// this line stops spending half its slots on the instruction and gives
    /// them to the invitations the legend cannot make.
    public static func line(remaining: TimeInterval,
                            elapsed: TimeInterval,
                            hasCompany: Bool,
                            commandsShown: Bool = false) -> String? {
        guard remaining > quietTail, elapsed >= 0 else { return nil }

        var others = secondary
        if hasCompany && !commandsShown {
            others.append(withCompany)
        }

        let slot = Int(elapsed / interval)
        if commandsShown {
            return others[slot % others.count]
        }
        // The instruction takes every other slot rather than an equal share:
        // it is the only line that tells someone what to actually do.
        guard slot.isMultiple(of: 2) == false else { return primary }
        return others[(slot / 2) % others.count]
    }
}
