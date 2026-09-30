import FocusLockCore
import XCTest

final class ExportServiceTests: XCTestCase {
    func testCSVExportFormatting() throws {
        let service = ExportService()
        let entry = SessionHistoryEntry(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!,
            startedAt: ISO8601DateFormatter().date(from: "2026-06-12T10:00:00Z")!,
            endedAt: ISO8601DateFormatter().date(from: "2026-06-12T10:25:00Z")!,
            focusMinutes: 25,
            breakMinutes: 5,
            status: .completed,
            blockedAppsCount: 3,
            strictMode: true
        )

        let csv = service.csvString(from: [entry])

        XCTAssertTrue(csv.hasPrefix("id,startedAt,endedAt,durationMinutes,focusMinutes,breakMinutes,status,blockedAppsCount,strictMode,category,goal,checkIn,note\n"))
        XCTAssertTrue(csv.contains("00000000-0000-0000-0000-000000000123,2026-06-12T10:00:00Z,2026-06-12T10:25:00Z,25,25,5,completed,3,true"))
    }

    func testJSONExportFormatting() throws {
        let service = ExportService()
        let entry = SessionHistoryEntry(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000124")!,
            startedAt: ISO8601DateFormatter().date(from: "2026-06-12T11:00:00Z")!,
            endedAt: ISO8601DateFormatter().date(from: "2026-06-12T11:45:00Z")!,
            focusMinutes: 45,
            breakMinutes: 10,
            status: .cancelled,
            blockedAppsCount: 2,
            strictMode: false
        )

        let data = try service.jsonData(from: [entry])
        let decoded = try JSONDecoder.focusLockDecoder.decode([SessionHistoryEntry].self, from: data)

        XCTAssertEqual(decoded, [entry])
    }
}

private extension JSONDecoder {
    static var focusLockDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
