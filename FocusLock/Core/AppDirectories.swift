import Foundation

enum AppDirectories {
    static func defaultSupportDirectory(fileManager: FileManager) -> URL {
        // For trying a build against throwaway data without touching your
        // real settings and history: LOCKIN_DATA_DIR=/tmp/lockin-test.
        if let override = ProcessInfo.processInfo.environment["LOCKIN_DATA_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }

        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let current = appSupport.appendingPathComponent(AppIdentity.name, isDirectory: true)
        let legacy = appSupport.appendingPathComponent(AppIdentity.legacyName, isDirectory: true)

        if !fileManager.fileExists(atPath: current.path), fileManager.fileExists(atPath: legacy.path) {
            try? fileManager.copyItem(at: legacy, to: current)
        }

        return current
    }
}
