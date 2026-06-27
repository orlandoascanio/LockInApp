import Foundation

public final class StateStore {
    public let baseDirectory: URL
    public let configURL: URL
    public let sessionStateURL: URL

    private let fileManager: FileManager

    public init(
        baseDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager

        if let baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            self.baseDirectory = AppDirectories.defaultSupportDirectory(fileManager: fileManager)
        }

        configURL = self.baseDirectory.appendingPathComponent("config.json")
        sessionStateURL = self.baseDirectory.appendingPathComponent("session-state.json")
    }

    public func prepareDirectory() throws {
        try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    }

    public func loadConfig() -> AppConfig {
        do {
            try prepareDirectory()

            guard fileManager.fileExists(atPath: configURL.path) else {
                let defaultConfig = AppConfig.default
                try saveConfig(defaultConfig)
                return defaultConfig
            }

            let data = try Data(contentsOf: configURL)
            let config = try FocusLockJSONCoding.decoder.decode(AppConfig.self, from: data)
            if !configUsesCurrentSchema(data) {
                try? saveConfig(config)
            }
            return config
        } catch {
            preserveInvalidFileIfNeeded(configURL)
            let defaultConfig = AppConfig.default
            try? saveConfig(defaultConfig)
            return defaultConfig
        }
    }

    public func saveConfig(_ config: AppConfig) throws {
        try prepareDirectory()
        let data = try FocusLockJSONCoding.encoder.encode(config)
        try atomicWrite(data, to: configURL)
    }

    public func loadSessionState() -> SessionState? {
        do {
            try prepareDirectory()

            guard fileManager.fileExists(atPath: sessionStateURL.path) else {
                return nil
            }

            let data = try Data(contentsOf: sessionStateURL)
            return try FocusLockJSONCoding.decoder.decode(SessionState.self, from: data)
        } catch {
            preserveInvalidFileIfNeeded(sessionStateURL)
            try? clearSessionState()
            return nil
        }
    }

    public func saveSessionState(_ state: SessionState) throws {
        try prepareDirectory()
        let data = try FocusLockJSONCoding.encoder.encode(state)
        try atomicWrite(data, to: sessionStateURL)
    }

    public func clearSessionState() throws {
        guard fileManager.fileExists(atPath: sessionStateURL.path) else {
            return
        }
        try fileManager.removeItem(at: sessionStateURL)
    }

    private func atomicWrite(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: [.atomic])
    }

    private func preserveInvalidFileIfNeeded(_ url: URL) {
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }

        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backupURL = url.deletingLastPathComponent()
            .appendingPathComponent("\(url.lastPathComponent).invalid-\(stamp)")

        try? fileManager.copyItem(at: url, to: backupURL)
    }

    private func configUsesCurrentSchema(_ data: Data) -> Bool {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let dictionary = object as? [String: Any]
        else {
            return false
        }

        return dictionary["blockerMode"] != nil
    }
}
