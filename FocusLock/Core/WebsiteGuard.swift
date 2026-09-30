import Foundation

/// A browser LockIn can read the current tab of through Apple Events.
/// Firefox has no scripting dictionary for tabs, so it is not on the list.
public enum SupportedBrowser: String, CaseIterable, Identifiable {
    case safari = "com.apple.Safari"
    case safariPreview = "com.apple.SafariTechnologyPreview"
    case chrome = "com.google.Chrome"
    case chromeBeta = "com.google.Chrome.beta"
    case chromium = "org.chromium.Chromium"
    case brave = "com.brave.Browser"
    case edge = "com.microsoft.edgemac"
    case arc = "company.thebrowser.Browser"
    case vivaldi = "com.vivaldi.Vivaldi"
    case opera = "com.operasoftware.Opera"

    public var id: String { rawValue }
    public var bundleIdentifier: String { rawValue }

    public var displayName: String {
        switch self {
        case .safari: return "Safari"
        case .safariPreview: return "Safari Technology Preview"
        case .chrome: return "Google Chrome"
        case .chromeBeta: return "Google Chrome Beta"
        case .chromium: return "Chromium"
        case .brave: return "Brave"
        case .edge: return "Microsoft Edge"
        case .arc: return "Arc"
        case .vivaldi: return "Vivaldi"
        case .opera: return "Opera"
        }
    }

    private var isSafari: Bool {
        self == .safari || self == .safariPreview
    }

    private var tabReference: String {
        isSafari ? "current tab of front window" : "active tab of front window"
    }

    var readScript: String {
        """
        tell application id "\(bundleIdentifier)"
            if (count of windows) is 0 then return ""
            return URL of \(tabReference)
        end tell
        """
    }

    func redirectScript(to url: String) -> String {
        let escaped = url
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return """
        tell application id "\(bundleIdentifier)"
            if (count of windows) is 0 then return
            set URL of \(tabReference) to "\(escaped)"
        end tell
        """
    }
}

public enum BrowserScriptError: Error, Equatable {
    /// The user said no to LockIn controlling this browser, or has not been asked yet.
    case notPermitted
    case failed(String)
}

public protocol BrowserScripting: AnyObject {
    func currentURL(in browser: SupportedBrowser) -> Result<URL?, BrowserScriptError>
    func redirect(_ browser: SupportedBrowser, to url: String) -> Bool
}

/// Runs the browser scripts through `NSAppleScript`. Only ever used from the
/// guard's own serial queue: `NSAppleScript` is not safe to share across threads.
public final class AppleScriptBrowserScripting: BrowserScripting {
    public init() {}

    public func currentURL(in browser: SupportedBrowser) -> Result<URL?, BrowserScriptError> {
        switch run(browser.readScript) {
        case .success(let text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return .success(trimmed.isEmpty ? nil : URL(string: trimmed))
        case .failure(let error):
            return .failure(error)
        }
    }

    public func redirect(_ browser: SupportedBrowser, to url: String) -> Bool {
        if case .success = run(browser.redirectScript(to: url)) {
            return true
        }
        return false
    }

    private func run(_ source: String) -> Result<String, BrowserScriptError> {
        guard let script = NSAppleScript(source: source) else {
            return .failure(.failed("could not compile the script"))
        }
        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let number = errorInfo[NSAppleScript.errorNumber] as? Int ?? 0
            // -1743: not authorised to send Apple Events; -1744: would need to ask.
            if number == -1743 || number == -1744 {
                return .failure(.notPermitted)
            }
            return .failure(.failed(errorInfo[NSAppleScript.errorMessage] as? String ?? "error \(number)"))
        }
        return .success(result.stringValue ?? "")
    }
}

public struct BlockedVisit: Equatable {
    public var site: BlockedSite
    public var browser: SupportedBrowser
    public var url: URL
}

/// Guards websites without a browser extension: while a supported browser is
/// frontmost during focus, it reads the current tab's address about once a
/// second and swaps a blocked page out for LockIn's own.
public final class WebsiteGuard {
    public var onBlocked: ((BlockedVisit) -> Void)?
    public var onPermissionDenied: ((SupportedBrowser) -> Void)?

    private let scripting: BrowserScripting
    private let queue = DispatchQueue(label: "com.lockin.website-guard")
    private let blockedPage: (BlockedSite, Date?) -> String

    private var sites: [BlockedSite] = []
    private var endsAt: Date?
    private var isChecking = false
    private var deniedBrowsers: Set<SupportedBrowser> = []

    public init(
        scripting: BrowserScripting = AppleScriptBrowserScripting(),
        blockedPage: @escaping (BlockedSite, Date?) -> String = BlockedPage.dataURL
    ) {
        self.scripting = scripting
        self.blockedPage = blockedPage
    }

    public var isActive: Bool { !sites.isEmpty }

    public func update(sites: [BlockedSite], endsAt: Date?) {
        self.sites = sites.filter(\.isEnabled)
        self.endsAt = endsAt
    }

    public func stop() {
        sites = []
        endsAt = nil
    }

    /// Asked again after a denial only when the user says they fixed it.
    public func resetPermissionMemory() {
        deniedBrowsers.removeAll()
    }

    /// Call on each tick with the frontmost app. Does nothing unless that app is
    /// a supported browser and there is something to guard; never overlaps a
    /// check still in flight, since a browser busy loading can take a moment
    /// to answer.
    public func check(frontmostBundleIdentifier: String?, completion: (() -> Void)? = nil) {
        guard
            !sites.isEmpty,
            !isChecking,
            let frontmostBundleIdentifier,
            let browser = SupportedBrowser(rawValue: frontmostBundleIdentifier),
            !deniedBrowsers.contains(browser)
        else {
            completion?()
            return
        }

        isChecking = true
        let sites = self.sites
        let endsAt = self.endsAt
        queue.async { [weak self] in
            guard let self else { return }
            let outcome = self.inspect(browser, sites: sites, endsAt: endsAt)
            DispatchQueue.main.async {
                self.isChecking = false
                switch outcome {
                case .blocked(let visit):
                    self.onBlocked?(visit)
                case .denied:
                    self.deniedBrowsers.insert(browser)
                    self.onPermissionDenied?(browser)
                case .clear:
                    break
                }
                completion?()
            }
        }
    }

    enum Outcome {
        case clear
        case blocked(BlockedVisit)
        case denied
    }

    func inspect(_ browser: SupportedBrowser, sites: [BlockedSite], endsAt: Date?) -> Outcome {
        switch scripting.currentURL(in: browser) {
        case .failure(.notPermitted):
            return .denied
        case .failure, .success(nil):
            return .clear
        case .success(let url?):
            guard let site = sites.first(where: { $0.matches(url) }) else { return .clear }
            guard scripting.redirect(browser, to: blockedPage(site, endsAt)) else { return .clear }
            return .blocked(BlockedVisit(site: site, browser: browser, url: url))
        }
    }
}

/// The page a blocked tab is replaced with. A `data:` URL rather than a file,
/// so there is nothing on disk for the browser to be refused access to.
public enum BlockedPage {
    public static func dataURL(for site: BlockedSite, until endsAt: Date?) -> String {
        let html = html(for: site.host, until: endsAt)
        return "data:text/html;charset=utf-8;base64," + Data(html.utf8).base64EncodedString()
    }

    static func html(for host: String, until endsAt: Date?) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        let until = endsAt.map { "until \(formatter.string(from: $0))" } ?? "until this block ends"
        let safeHost = host
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        return """
        <!doctype html><html><head><meta charset="utf-8"><title>Not now · LockIn</title>
        <style>
        :root{color-scheme:light dark;--bg:#F4EFE3;--ink:#1F2A24;--soft:#6B7169;--accent:#2F5D4A}
        @media (prefers-color-scheme:dark){:root{--bg:#17201C;--ink:#ECE7DA;--soft:#9AA197;--accent:#7FB89C}}
        html,body{height:100%;margin:0;background:var(--bg);color:var(--ink);
        font:16px/1.5 -apple-system,BlinkMacSystemFont,sans-serif}
        main{height:100%;display:flex;flex-direction:column;align-items:center;justify-content:center;
        text-align:center;padding:0 24px}
        small{letter-spacing:.14em;text-transform:uppercase;color:var(--accent);font-weight:600;font-size:12px}
        h1{font-size:44px;margin:.2em 0;font-weight:700}p{color:var(--soft);max-width:30em}
        </style></head><body><main>
        <small>LockIn</small><h1>Not now.</h1>
        <p><b>\(safeHost)</b> is guarded \(until). Close this tab and get back to the thing you sat down to do.</p>
        </main></body></html>
        """
    }
}
