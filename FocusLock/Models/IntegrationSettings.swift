import Foundation

/// Slack and Discord preferences. The secrets — the Slack token and the
/// Discord webhook link — live in the Keychain, never in this file.
public struct IntegrationSettings: Codable, Equatable {
    public var slackEnabled = false
    public var slackStatusText = "Focusing"
    public var slackStatusEmoji = ":lock:"
    /// Pauses Slack notifications for the length of each focus block.
    public var slackPauseNotifications = true

    /// Shows "Focusing · 18 min left" on your Discord profile via Rich Presence.
    public var discordPresenceEnabled = false
    /// The Application ID of a Discord app you created, which Rich Presence
    /// needs to name the activity.
    public var discordClientID = ""

    /// Posts a recap to a channel webhook when a run of blocks ends.
    public var discordRecapEnabled = false

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case slackEnabled, slackStatusText, slackStatusEmoji, slackPauseNotifications
        case discordPresenceEnabled, discordClientID, discordRecapEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = IntegrationSettings()
        slackEnabled = try container.decodeIfPresent(Bool.self, forKey: .slackEnabled) ?? fallback.slackEnabled
        slackStatusText = try container.decodeIfPresent(String.self, forKey: .slackStatusText) ?? fallback.slackStatusText
        slackStatusEmoji = try container.decodeIfPresent(String.self, forKey: .slackStatusEmoji) ?? fallback.slackStatusEmoji
        slackPauseNotifications = try container.decodeIfPresent(Bool.self, forKey: .slackPauseNotifications)
            ?? fallback.slackPauseNotifications
        discordPresenceEnabled = try container.decodeIfPresent(Bool.self, forKey: .discordPresenceEnabled)
            ?? fallback.discordPresenceEnabled
        discordClientID = try container.decodeIfPresent(String.self, forKey: .discordClientID) ?? fallback.discordClientID
        discordRecapEnabled = try container.decodeIfPresent(Bool.self, forKey: .discordRecapEnabled)
            ?? fallback.discordRecapEnabled
    }

    /// Discord application IDs are snowflakes: a long run of digits.
    public var hasValidDiscordClientID: Bool {
        let id = discordClientID.trimmingCharacters(in: .whitespaces)
        return (15...22).contains(id.count) && id.allSatisfy(\.isNumber)
    }
}
