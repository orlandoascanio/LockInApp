import Foundation

/// Decides whether a viewer's words are allowed on the broadcast.
///
/// A word list alone is weak — people space letters out, swap digits for
/// letters, stretch vowels, add accents. So text is folded down to a plain
/// form first, and the list is folded the same way, which means one entry
/// catches its variants instead of needing an entry per spelling.
///
/// It is still only a filter. Nothing here is a guarantee: lists are always
/// incomplete and anyone determined will get past one. Approve-first is what
/// actually protects the stream; this is what makes approve-first survivable
/// when chat is busy.
public enum AudienceFilter {
    /// Digits and symbols that stand in for letters.
    private static let substitutions: [Character: Character] = [
        "0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "6": "g",
        "7": "t", "8": "b", "9": "g", "@": "a", "$": "s", "|": "i", "!": "i", "+": "t"
    ]

    /// Repeated letters are folded down to `maxRun`.
    ///
    /// Neither limit works alone. Keeping two protects ordinary words that are
    /// spelled with doubles — "pass", "assess", "hello" — but leaves
    /// "baaaadwooord" as "baadwoord", which no entry matches. Collapsing to
    /// one catches the stretch but turns "pass" into "pas". So text is checked
    /// against both forms, with the entries folded the same way each time.
    static func fold(_ value: some StringProtocol, maxRun: Int = 2) -> String {
        let base = String(value).folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
                                         locale: Locale(identifier: "en_US"))
        var out = ""
        var run: (character: Character, count: Int)?
        for character in base {
            let mapped = substitutions[character] ?? character
            guard mapped.isLetter else { continue }
            if let current = run, current.character == mapped {
                guard current.count < maxRun else { continue }
                run = (mapped, current.count + 1)
            } else {
                run = (mapped, 1)
            }
            out.append(mapped)
        }
        return out
    }

    /// Word boundaries survive here, which keeps short entries from matching
    /// inside innocent words.
    static func foldedTokens(_ text: String, maxRun: Int = 2) -> [String] {
        text.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" })
            .map { fold($0, maxRun: maxRun) }
            .filter { !$0.isEmpty }
    }

    /// Everything run together, which is how "s l u r" and "s.l.u.r" are
    /// caught. Only longer entries are matched against this, because a short
    /// one would fire inside ordinary words — the reason "class" must not trip
    /// a three-letter entry.
    static let minimumSubstringLength = 5

    public static func isAllowed(_ text: String, terms: Set<String>) -> Bool {
        guard !terms.isEmpty else { return true }
        return ![2, 1].contains { matches(text, terms: terms, maxRun: $0) }
    }

    private static func matches(_ text: String, terms: Set<String>, maxRun: Int) -> Bool {
        let folded = terms.map { fold($0, maxRun: maxRun) }.filter { !$0.isEmpty }
        let tokens = foldedTokens(text, maxRun: maxRun)

        for term in folded {
            if tokens.contains(term) {
                return true
            }
            if term.count >= minimumSubstringLength && tokens.contains(where: { $0.contains(term) }) {
                return true
            }
        }

        let collapsed = tokens.joined()
        return folded.contains { $0.count >= minimumSubstringLength && collapsed.contains($0) }
    }

    /// A starting point, not a policy. Slurs and the terms that matter on your
    /// platform belong in the host's own list — see `blocked-words.txt` in the
    /// LockIn support folder, one term per line, which is merged with this.
    public static let defaultTerms: Set<String> = [
        "fuck", "shit", "bitch", "cunt", "whore", "slut", "bastard",
        "dick", "cock", "pussy", "wank", "asshole", "retard", "rape",
        "nazi", "kys", "kill yourself"
    ]

    /// One term per line; blank lines and `#` comments ignored.
    public static func terms(fromFileAt url: URL) -> Set<String> {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return Set(
            contents
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        )
    }
}
