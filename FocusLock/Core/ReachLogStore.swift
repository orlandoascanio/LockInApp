import Foundation

/// One time a guarded app or website was reached for during focus.
public struct Reach: Codable, Equatable {
    public enum Kind: String, Codable {
        case app
        case site
    }

    public var at: Date
    /// The bundle id for an app, the host for a website.
    public var key: String
    public var name: String
    public var kind: Kind
    /// The focus block it happened in: its history entry's `startedAt`.
    public var blockStartedAt: Date?

    public init(at: Date, key: String, name: String, kind: Kind, blockStartedAt: Date?) {
        self.at = at
        self.key = key
        self.name = name
        self.kind = kind
        self.blockStartedAt = blockStartedAt
    }

    /// Minutes into its block, when the block is known.
    public var minuteIntoBlock: Int? {
        blockStartedAt.map { max(0, Int(at.timeIntervalSince($0) / 60)) }
    }
}

/// Every reach, one JSON object per line, so recording one is an append and
/// never a rewrite. Kept on this Mac only, for Insights.
public final class ReachLogStore {
    public let logURL: URL

    private let baseDirectory: URL
    private let fileManager: FileManager

    public init(baseDirectory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.baseDirectory = baseDirectory ?? AppDirectories.defaultSupportDirectory(fileManager: fileManager)
        logURL = self.baseDirectory.appendingPathComponent("reach-log.jsonl")
    }

    public func append(_ reach: Reach) {
        JSONLines.append(reach, to: logURL, in: baseDirectory, fileManager: fileManager)
    }

    /// Every reach on record, oldest first. A line this build cannot read is
    /// skipped rather than losing the rest.
    public func load() -> [Reach] {
        JSONLines.load(Reach.self, from: logURL)
    }

    public func reset() {
        try? fileManager.removeItem(at: logURL)
    }
}

/// Appending to and reading from a JSON Lines file.
enum JSONLines {
    static func append<T: Encodable>(_ value: T, to url: URL, in directory: URL, fileManager: FileManager) {
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            var data = try FocusLockJSONCoding.lineEncoder.encode(value)
            data.append(0x0A)
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } else {
                try data.write(to: url, options: [.atomic])
            }
        } catch {
            FocusLockLog.debug("could not append to \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    static func load<T: Decodable>(_ type: T.Type, from url: URL) -> [T] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { line in
            try? FocusLockJSONCoding.decoder.decode(T.self, from: Data(line.utf8))
        }
    }
}
