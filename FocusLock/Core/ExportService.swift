import Foundation

public final class ExportService {
    public enum ExportError: Error {
        case writeFailed
    }

    public init() {}

    public func csvString(from history: [SessionHistoryEntry]) -> String {
        let header = "id,startedAt,endedAt,durationMinutes,focusMinutes,breakMinutes,status,blockedAppsCount,strictMode"

        let rows = history
            .sorted { $0.startedAt < $1.startedAt }
            .map { entry in
                [
                    entry.id.uuidString,
                    Self.isoString(entry.startedAt),
                    Self.isoString(entry.endedAt),
                    String(entry.durationMinutes),
                    String(entry.focusMinutes),
                    String(entry.breakMinutes),
                    entry.status.rawValue,
                    String(entry.blockedAppsCount),
                    String(entry.strictMode)
                ]
                .map(Self.csvEscape)
                .joined(separator: ",")
            }

        return ([header] + rows).joined(separator: "\n") + "\n"
    }

    public func jsonData(from history: [SessionHistoryEntry]) throws -> Data {
        try FocusLockJSONCoding.encoder.encode(history.sorted { $0.startedAt < $1.startedAt })
    }

    public func exportCSV(_ history: [SessionHistoryEntry], to url: URL) throws {
        guard let data = csvString(from: history).data(using: .utf8) else {
            throw ExportError.writeFailed
        }
        try data.write(to: url, options: [.atomic])
    }

    public func exportJSON(_ history: [SessionHistoryEntry], to url: URL) throws {
        let data = try jsonData(from: history)
        try data.write(to: url, options: [.atomic])
    }

    private static func isoString(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func csvEscape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else {
            return value
        }

        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
