import Foundation

/// One chat message, reduced to the two things the wall needs.
public struct TwitchChatMessage: Equatable {
    public let name: String
    public let text: String

    public init(name: String, text: String) {
        self.name = name
        self.text = text
    }
}

/// Parsing for Twitch's IRC dialect, kept apart from the socket so the format
/// can be tested without a network — which matters, because the awkward parts
/// here are all shapes of line rather than anything to do with connecting.
public enum TwitchIRC {
    public enum Event: Equatable {
        case message(TwitchChatMessage)
        /// Must be answered or the server drops the connection.
        case ping(String)
        case welcomed
        case notice(String)
        case other
    }

    /// A single frame can carry several lines, so nothing may assume one
    /// message per read.
    public static func events(in frame: String) -> [Event] {
        frame
            .components(separatedBy: "\r\n")
            .flatMap { $0.components(separatedBy: "\n") }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map(parse)
    }

    public static func parse(_ raw: String) -> Event {
        var line = raw.trimmingCharacters(in: CharacterSet(charactersIn: "\r\n"))
        var tags: [String: String] = [:]

        if line.hasPrefix("@") {
            guard let split = line.firstIndex(of: " ") else { return .other }
            tags = parseTags(String(line[line.index(after: line.startIndex)..<split]))
            line = String(line[line.index(after: split)...])
        }

        if line.hasPrefix("PING") {
            return .ping(payload(of: line) ?? "tmi.twitch.tv")
        }

        var prefix = ""
        if line.hasPrefix(":") {
            guard let split = line.firstIndex(of: " ") else { return .other }
            prefix = String(line[line.index(after: line.startIndex)..<split])
            line = String(line[line.index(after: split)...])
        }

        let command = line.prefix(while: { $0 != " " })
        switch command {
        case "PRIVMSG":
            guard let text = payload(of: line), !text.isEmpty else { return .other }
            return .message(TwitchChatMessage(name: displayName(tags: tags, prefix: prefix), text: text))
        case "001":
            return .welcomed
        case "NOTICE":
            return .notice(payload(of: line) ?? "")
        default:
            return .other
        }
    }

    /// Everything after the first " :" — the trailing parameter, which is the
    /// only one allowed to contain spaces or further colons.
    private static func payload(of line: String) -> String? {
        guard let marker = line.range(of: " :") else { return nil }
        return String(line[marker.upperBound...])
    }

    /// The display name is what someone chose to be called, including its
    /// capitalisation; the login in the prefix is the fallback.
    private static func displayName(tags: [String: String], prefix: String) -> String {
        if let display = tags["display-name"], !display.isEmpty {
            return display
        }
        return String(prefix.prefix(while: { $0 != "!" }))
    }

    private static func parseTags(_ raw: String) -> [String: String] {
        var tags: [String: String] = [:]
        for pair in raw.components(separatedBy: ";") {
            guard let equals = pair.firstIndex(of: "=") else { continue }
            let key = String(pair[pair.startIndex..<equals])
            tags[key] = unescape(String(pair[pair.index(after: equals)...]))
        }
        return tags
    }

    /// IRCv3 escapes, which is how a space survives inside a tag value.
    private static func unescape(_ value: String) -> String {
        guard value.contains("\\") else { return value }
        var out = ""
        var escaping = false
        for character in value {
            if escaping {
                switch character {
                case "s": out.append(" ")
                case "n": out.append("\n")
                case "r": out.append("\r")
                case ":": out.append(";")
                default: out.append(character)
                }
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else {
                out.append(character)
            }
        }
        return out
    }

    /// Hosts paste all sorts of things into a channel field — a full URL, a
    /// leading hash, their name with capitals. All of them mean one channel.
    public static func normalizeChannel(_ raw: String) -> String? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for prefix in ["https://", "http://", "www.", "twitch.tv/", "m.twitch.tv/"] {
            if value.hasPrefix(prefix) {
                value = String(value.dropFirst(prefix.count))
            }
        }
        value = value.components(separatedBy: "/").first ?? value
        value = value.components(separatedBy: "?").first ?? value
        value = value.trimmingCharacters(in: CharacterSet(charactersIn: "#"))

        // Twitch logins are letters, digits and underscore, 3-25 characters.
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_")
        guard (3...25).contains(value.count),
              value.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return nil
        }
        return value
    }
}
