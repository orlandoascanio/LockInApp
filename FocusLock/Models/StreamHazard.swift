import Foundation

/// An app you are guarding that your own broadcast depends on.
///
/// Only broadcast software qualifies. Browsers, Discord, and music players
/// were flagged here at first, and that was wrong: guarding those during a
/// focus block is what LockIn is for. A warning that fires on the app's own
/// purpose is one you learn to scroll past, and then it is not there when OBS
/// really is about to be shut mid-stream.
public struct StreamHazard: Identifiable, Equatable {
    public enum Role: String, Equatable {
        case broadcast

        public var consequence: String {
            switch self {
            case .broadcast: return "guarding this takes your broadcast down mid-stream"
            }
        }
    }

    public var id: String { app.bundleId }
    public let app: BlockedApp
    public let role: Role

    public init(app: BlockedApp, role: Role) {
        self.app = app
        self.role = role
    }

    /// Matched on bundle identifier fragments rather than names, since a user
    /// can rename an entry but not its identifier.
    static let rules: [(token: String, role: Role)] = [
        ("obsproject", .broadcast),
        ("streamlabs", .broadcast),
        ("twitch.studio", .broadcast),
        ("restream", .broadcast),
        ("ecamm.live", .broadcast)
    ]

    /// Only apps actually being guarded right now — an entry toggled off is
    /// already harmless, and warning about it would train you to ignore this.
    public static func hazards(in apps: [BlockedApp]) -> [StreamHazard] {
        apps.filter(\.isEnabled).compactMap { app in
            let id = app.bundleId.lowercased()
            guard let rule = rules.first(where: { id.contains($0.token) }) else { return nil }
            return StreamHazard(app: app, role: rule.role)
        }
    }
}
