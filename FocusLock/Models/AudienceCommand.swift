import Foundation

/// What a viewer typed in chat, once it is recognizable as an instruction.
///
/// Parsing lives here rather than in a chat client so that Twitch, YouTube,
/// and the host typing one in by hand all agree on what counts as a command.
public enum AudienceCommand: Equatable {
    case task(String)
    case done

    /// `!task` is the one the audience window advertises — it is the format's
    /// own word. The rest are near-synonyms a newcomer might guess, accepted
    /// silently, because being ignored is a worse first impression than a
    /// slightly wrong command.
    public static let taskAliases: Set<String> = ["task", "goal", "doing", "working", "focus", "working_on"]
    public static let doneAliases: Set<String> = ["done", "finished", "complete", "completed"]

    public static let advertised = "!task"

    /// One line each, in the order a newcomer needs them. The aliases above
    /// forgive a wrong guess; this is what stops anyone having to guess.
    public struct Legend: Identifiable, Equatable {
        public let command: String
        public let meaning: String
        public var id: String { command }
    }

    public static let legend = [
        Legend(command: "!task", meaning: "what you're working on"),
        Legend(command: "!done", meaning: "when you finish it")
    ]

    public static func parse(_ message: String) -> AudienceCommand? {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("!") else { return nil }

        let body = trimmed.dropFirst()
        let parts = body.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        // Trailing punctuation is common ("!task:" or "!done!") and should not
        // be the difference between appearing on screen and not.
        guard let verb = parts.first?.lowercased().filter({ $0.isLetter || $0 == "_" }), !verb.isEmpty else {
            return nil
        }

        if doneAliases.contains(verb) {
            return .done
        }
        if taskAliases.contains(verb) {
            let text = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : ""
            // A bare "!task" is someone testing the command, not a submission.
            return text.isEmpty ? nil : .task(text)
        }
        return nil
    }
}
