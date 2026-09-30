import Foundation
import FocusLockCore

/// Brings LockIn back if it is force-quit during a strict block.
///
/// A per-user launch agent is kept alive by launchd only while a lock file
/// exists (`KeepAlive` → `PathState`). The lock is created when a strict block
/// starts and removed when it ends, so outside strict blocks the agent sits
/// idle and costs nothing. Each run checks once for LockIn and relaunches it;
/// launchd runs it again ten seconds later for as long as the lock is there.
/// No privileges are involved — the agent is yours, in ~/Library/LaunchAgents.
final class StrictWatchdog {
    static let label = "com.lockin.app.watchdog"

    private let fileManager = FileManager.default

    private var agentURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(Self.label).plist")
    }

    private var lockURL: URL {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return support.appendingPathComponent(AppIdentity.name, isDirectory: true)
            .appendingPathComponent("strict-lock")
    }

    func arm() {
        installIfNeeded()
        guard !fileManager.fileExists(atPath: lockURL.path) else { return }
        try? fileManager.createDirectory(at: lockURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? Data(Bundle.main.bundlePath.utf8).write(to: lockURL, options: .atomic)
    }

    func disarm() {
        try? fileManager.removeItem(at: lockURL)
    }

    func uninstall() {
        disarm()
        guard fileManager.fileExists(atPath: agentURL.path) else { return }
        launchctl(["bootout", "gui/\(getuid())/\(Self.label)"])
        try? fileManager.removeItem(at: agentURL)
    }

    private func installIfNeeded() {
        let plist = agentPlist()
        if let existing = try? Data(contentsOf: agentURL), existing == plist {
            return
        }
        try? fileManager.createDirectory(at: agentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        launchctl(["bootout", "gui/\(getuid())/\(Self.label)"])
        do {
            try plist.write(to: agentURL, options: .atomic)
        } catch {
            FocusLockLog.debug("watchdog install failed: \(error.localizedDescription)")
            return
        }
        launchctl(["bootstrap", "gui/\(getuid())", agentURL.path])
    }

    /// If LockIn is gone, reopen it; if it can no longer be found (deleted),
    /// drop the lock so launchd stops trying.
    private func agentPlist() -> Data {
        let lock = lockURL.path.replacingOccurrences(of: "'", with: "'\\''")
        let script = """
        LOCK='\(lock)'
        [ -f "$LOCK" ] || exit 0
        /usr/bin/pgrep -qx '\(AppIdentity.name)' && exit 0
        /usr/bin/open -b '\(AppIdentity.bundleIdentifier)' || /bin/rm -f "$LOCK"
        """
        let dictionary: [String: Any] = [
            "Label": Self.label,
            "ProgramArguments": ["/bin/sh", "-c", script],
            "KeepAlive": ["PathState": [lockURL.path: true]],
            "ThrottleInterval": 10,
            "ProcessType": "Background"
        ]
        return (try? PropertyListSerialization.data(fromPropertyList: dictionary, format: .xml, options: 0)) ?? Data()
    }

    @discardableResult
    private func launchctl(_ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }
}
