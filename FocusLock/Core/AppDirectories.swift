import Foundation

enum AppDirectories {
    static func defaultSupportDirectory(fileManager: FileManager) -> URL {
        // For trying a build against throwaway data without touching your
        // real settings and history: QUIETWHILE_DATA_DIR=/tmp/quietwhile-test.
        // LOCKIN_DATA_DIR still works.
        let environment = ProcessInfo.processInfo.environment
        if let override = environment["QUIETWHILE_DATA_DIR"] ?? environment["LOCKIN_DATA_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }

        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let current = appSupport.appendingPathComponent(AppIdentity.name, isDirectory: true)

        // First launch under a new name: carry over the newest earlier folder.
        if !fileManager.fileExists(atPath: current.path),
           let legacy = AppIdentity.legacyNames
            .map({ appSupport.appendingPathComponent($0, isDirectory: true) })
            .first(where: { fileManager.fileExists(atPath: $0.path) }) {
            try? fileManager.copyItem(at: legacy, to: current)
        }

        return current
    }
}
