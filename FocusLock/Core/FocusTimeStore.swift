import Foundation

/// Where one focus block's time went: seconds per app in front, and per
/// website for browsers Quietwhile was already allowed to read. Only totals
/// are kept, never page addresses or titles.
public struct FocusTimeRecord: Codable, Equatable {
    /// Its history entry's `startedAt`.
    public var blockStartedAt: Date
    /// Seconds, by bundle id.
    public var apps: [String: Double]
    /// Display names, by bundle id, as they were when recorded.
    public var appNames: [String: String]
    /// Seconds, by host.
    public var sites: [String: Double]

    public init(blockStartedAt: Date, apps: [String: Double] = [:], appNames: [String: String] = [:], sites: [String: Double] = [:]) {
        self.blockStartedAt = blockStartedAt
        self.apps = apps
        self.appNames = appNames
        self.sites = sites
    }

    public var isEmpty: Bool {
        apps.isEmpty && sites.isEmpty
    }
}

/// Adds up the current block's time as the app ticks, then hands it over as
/// one record when the block ends.
public struct FocusTimeAccumulator: Equatable {
    public private(set) var blockStartedAt: Date?
    private var apps: [String: Double] = [:]
    private var appNames: [String: String] = [:]
    private var sites: [String: Double] = [:]

    /// The longest gap one tick may count. A Mac that slept, or a stalled
    /// main thread, is not an hour in whichever app was in front.
    public static let maxStep: TimeInterval = 5

    public init() {}

    public mutating func begin(blockStartedAt: Date) {
        guard self.blockStartedAt != blockStartedAt else { return }
        self = FocusTimeAccumulator()
        self.blockStartedAt = blockStartedAt
    }

    public mutating func addApp(bundleId: String, name: String, seconds: TimeInterval) {
        guard blockStartedAt != nil, seconds > 0 else { return }
        apps[bundleId, default: 0] += min(seconds, Self.maxStep)
        appNames[bundleId] = name
    }

    public mutating func addSite(host: String, seconds: TimeInterval) {
        guard blockStartedAt != nil, seconds > 0, let host = Self.normalizedHost(host) else { return }
        sites[host, default: 0] += seconds
    }

    /// The block's record, and a fresh start. `nil` when nothing was counted.
    public mutating func finish() -> FocusTimeRecord? {
        defer { self = FocusTimeAccumulator() }
        guard let blockStartedAt else { return nil }
        let record = FocusTimeRecord(blockStartedAt: blockStartedAt, apps: apps, appNames: appNames, sites: sites)
        return record.isEmpty ? nil : record
    }

    /// "www.github.com" and "github.com" are one site.
    public static func normalizedHost(_ host: String) -> String? {
        var host = host.lowercased().trimmingCharacters(in: .whitespaces)
        if host.hasPrefix("www.") { host.removeFirst(4) }
        return host.isEmpty ? nil : host
    }
}

public final class FocusTimeStore {
    public let logURL: URL

    private let baseDirectory: URL
    private let fileManager: FileManager

    public init(baseDirectory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.baseDirectory = baseDirectory ?? AppDirectories.defaultSupportDirectory(fileManager: fileManager)
        logURL = self.baseDirectory.appendingPathComponent("focus-time.jsonl")
    }

    public func append(_ record: FocusTimeRecord) {
        JSONLines.append(record, to: logURL, in: baseDirectory, fileManager: fileManager)
    }

    public func load() -> [FocusTimeRecord] {
        JSONLines.load(FocusTimeRecord.self, from: logURL)
    }

    public func reset() {
        try? fileManager.removeItem(at: logURL)
    }
}
