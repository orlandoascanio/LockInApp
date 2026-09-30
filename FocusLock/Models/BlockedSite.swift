import Foundation

/// A website guarded during focus, stored as a host with an optional path
/// prefix: `youtube.com`, or `reddit.com/r/all` to leave the rest of Reddit
/// alone. A host also covers its subdomains, so `youtube.com` catches
/// `m.youtube.com`.
public struct BlockedSite: Codable, Equatable, Hashable, Identifiable {
    public var id: UUID
    public var pattern: String
    public var isEnabled: Bool

    public init(id: UUID = UUID(), pattern: String, isEnabled: Bool = true) {
        self.id = id
        self.pattern = pattern
        self.isEnabled = isEnabled
    }

    /// Builds a site from whatever was typed or pasted — a bare domain, a full
    /// link, with or without `www.` — or `nil` if it does not name a website.
    public init?(input: String) {
        guard let pattern = SitePattern.normalize(input) else { return nil }
        self.init(pattern: pattern)
    }

    public var host: String { SitePattern.split(pattern).host }

    public func matches(_ url: URL) -> Bool {
        SitePattern.matches(pattern: pattern, url: url)
    }
}

public enum SitePattern {
    /// Lowercased `host[/path]` with the scheme, `www.`, port, query, fragment,
    /// and trailing slash stripped. `nil` for anything without a dotted host.
    ///
    /// A pasted link (one with a scheme) keeps only its site: someone pasting
    /// a video they keep going back to means "this site", not "this one
    /// page". A path is kept only when typed on purpose, as in `reddit.com/r/all`.
    public static func normalize(_ input: String) -> String? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !text.isEmpty, !text.contains(" ") else { return nil }
        let isPastedLink = text.contains("://")
        if !isPastedLink {
            text = "https://" + text
        }
        guard
            let components = URLComponents(string: text),
            let rawHost = components.host,
            ["http", "https"].contains(components.scheme ?? "")
        else {
            return nil
        }

        let host = strippingWWW(rawHost)
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2, labels.allSatisfy({ !$0.isEmpty }) else { return nil }

        var path = isPastedLink ? "" : components.path
        while path.hasSuffix("/") {
            path.removeLast()
        }
        return host + path
    }

    public static func split(_ pattern: String) -> (host: String, path: String) {
        guard let slash = pattern.firstIndex(of: "/") else { return (pattern, "") }
        return (String(pattern[..<slash]), String(pattern[slash...]))
    }

    public static func matches(pattern: String, url: URL) -> Bool {
        guard
            let scheme = url.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            let rawHost = url.host?.lowercased()
        else {
            return false
        }

        let (patternHost, patternPath) = split(pattern)
        let host = strippingWWW(rawHost)
        guard host == patternHost || host.hasSuffix("." + patternHost) else { return false }
        guard !patternPath.isEmpty else { return true }

        // `/r/all` covers `/r/all/top` but not `/r/allergies`.
        let path = url.path.lowercased()
        return path == patternPath || path.hasPrefix(patternPath + "/")
    }

    private static func strippingWWW(_ host: String) -> String {
        host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}
