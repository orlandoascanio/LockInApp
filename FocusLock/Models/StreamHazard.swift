import Foundation

/// An app you are guarding that your own stream depends on.
///
/// Guarding OBS mid-session takes the broadcast down; guarding the browser
/// takes chat away; guarding the music app takes the soundtrack with it. The
/// README asks you to remember. This checks instead.
public struct StreamHazard: Identifiable, Equatable {
    public enum Role: String, Equatable {
        case broadcast
        case chat
        case music

        public var consequence: String {
            switch self {
            case .broadcast: return "guarding this takes your broadcast down mid-session"
            case .chat: return "guarding this means you cannot see chat during breaks"
            case .music: return "guarding this stops your session soundtrack"
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
        ("com.apple.safari", .chat),
        ("com.google.chrome", .chat),
        ("org.mozilla.firefox", .chat),
        ("thebrowser.browser", .chat),
        ("microsoft.edgemac", .chat),
        ("brave.browser", .chat),
        ("hnc.discord", .chat),
        ("com.apple.music", .music),
        ("spotify.client", .music)
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
