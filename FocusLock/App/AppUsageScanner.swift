import AppKit
import CoreServices
import FocusLockCore

/// Reads how the apps on this Mac are actually used, for the welcome guide's
/// suggestions: Spotlight's launch records, what sits in the Dock, and what
/// is open right now. All of it is already on the Mac and none of it needs a
/// permission; nothing is sent anywhere.
enum AppUsageScanner {
    /// Never offered: apps LockIn refuses to guard, and browsers, which are
    /// guarded one website at a time instead.
    static let excludedBundleIds: Set<String> = AppBlocker.protectedBundleIdentifiers
        .union(SupportedBrowser.allCases.map(\.bundleIdentifier))
        .union(["org.mozilla.firefox"])

    static func suggestions(now: Date = Date()) -> AppSuggestionList {
        AppSuggestions.rank(scan(), now: now, excluding: excludedBundleIds, likelyLimit: 6, frequentLimit: 3)
    }

    static func scan() -> [AppUsage] {
        let running = Set(
            NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular }
                .compactMap(\.bundleIdentifier)
        )
        let docked = dockBundleIds()

        var urls = applicationURLs()
        // An app run from somewhere unusual is still an app in use.
        urls += NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap(\.bundleURL)

        var seen = Set<String>()
        return urls.compactMap { url in
            guard
                let bundle = Bundle(url: url),
                let bundleId = bundle.bundleIdentifier,
                seen.insert(bundleId).inserted
            else {
                return nil
            }

            let item = MDItemCreateWithURL(kCFAllocatorDefault, url as CFURL)
            let lastUsed = item.flatMap { MDItemCopyAttribute($0, kMDItemLastUsedDate) } as? Date
            let useCount = (item.flatMap { MDItemCopyAttribute($0, "kMDItemUseCount" as CFString) } as? NSNumber)?.intValue ?? 0
            let displayName = FileManager.default.displayName(atPath: url.path)

            return AppUsage(
                name: displayName.hasSuffix(".app") ? String(displayName.dropLast(4)) : displayName,
                bundleId: bundleId,
                url: url,
                category: bundle.object(forInfoDictionaryKey: "LSApplicationCategoryType") as? String,
                lastUsed: lastUsed,
                useCount: useCount,
                isRunning: running.contains(bundleId),
                isInDock: docked.contains(bundleId)
            )
        }
    }

    private static func applicationURLs() -> [URL] {
        let fileManager = FileManager.default
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true)
        ]

        var found: [URL] = []
        for root in roots {
            let entries = (try? fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []
            for entry in entries {
                if entry.pathExtension == "app" {
                    found.append(entry)
                } else if entry.hasDirectoryPath {
                    // One level down covers suites that install into a folder.
                    let nested = (try? fileManager.contentsOfDirectory(
                        at: entry,
                        includingPropertiesForKeys: nil,
                        options: [.skipsHiddenFiles]
                    )) ?? []
                    found += nested.filter { $0.pathExtension == "app" }
                }
            }
        }
        return found
    }

    private static func dockBundleIds() -> Set<String> {
        let tiles = UserDefaults(suiteName: "com.apple.dock")?.array(forKey: "persistent-apps") ?? []
        return Set(tiles.compactMap { tile in
            ((tile as? [String: Any])?["tile-data"] as? [String: Any])?["bundle-identifier"] as? String
        })
    }
}
