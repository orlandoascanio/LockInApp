import CoreGraphics
import FocusLockCore
import XCTest

final class HUDSettingsTests: XCTestCase {
    /// A 1710×1074 laptop screen with a 33-point menu bar.
    private let area = CGRect(x: 0, y: 0, width: 1710, height: 1041)
    private let compact = CGSize(width: 150, height: 32)
    private let expanded = CGSize(width: 340, height: 52)

    func testDefaultSitsTopRightUnderTheMenuBar() {
        let frame = HUDPlacement.default.frame(size: compact, in: area)
        XCTAssertEqual(frame.maxX, area.maxX - 12)
        XCTAssertEqual(frame.maxY, area.maxY - 12)
    }

    func testGrowingKeepsTheAnchoredEdgeStill() {
        let placement = HUDPlacement.default
        let small = placement.frame(size: compact, in: area)
        let large = placement.frame(size: expanded, in: area)
        XCTAssertEqual(small.maxX, large.maxX)
        XCTAssertEqual(small.maxY, large.maxY)
    }

    func testDropNearACornerSnapsIntoIt() {
        let dropped = CGRect(x: 20, y: 30, width: 150, height: 32)
        let placement = HUDPlacement.snapped(frame: dropped, in: area)
        XCTAssertEqual(placement, HUDPlacement(horizontal: .start, vertical: .end, dx: 12, dy: 12))
        XCTAssertEqual(placement.frame(size: compact, in: area).origin, CGPoint(x: 12, y: 12))
    }

    func testDropNearTheTopMiddleCentres() {
        let dropped = CGRect(x: area.midX - 75 + 25, y: area.maxY - 32 - 20, width: 150, height: 32)
        let placement = HUDPlacement.snapped(frame: dropped, in: area)
        XCTAssertEqual(placement, HUDPlacement(horizontal: .center, vertical: .start, dx: 0, dy: 12))
    }

    func testDropInOpenSpaceStaysPutAndAnchorsToTheNearerSide() {
        let dropped = CGRect(x: 1300, y: 600, width: 340, height: 52)
        let placement = HUDPlacement.snapped(frame: dropped, in: area)
        XCTAssertEqual(placement.horizontal, .end)
        XCTAssertEqual(placement.vertical, .center)
        XCTAssertEqual(placement.frame(size: expanded, in: area), dropped)
    }

    func testDraggedOffScreenComesBackInside() {
        let dropped = CGRect(x: -200, y: 2000, width: 150, height: 32)
        let frame = HUDPlacement.snapped(frame: dropped, in: area).frame(size: compact, in: area)
        XCTAssertTrue(area.contains(frame))
    }

    func testPlacementIsRememberedPerDisplay() throws {
        var settings = HUDSettings()
        let corner = HUDPlacement(horizontal: .start, vertical: .end, dx: 12, dy: 12)
        settings.placements["external"] = corner
        settings.lastDisplay = "external"

        let decoded = try JSONDecoder().decode(HUDSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(decoded.placement(forDisplay: "external"), corner)
        XCTAssertEqual(decoded.placement(forDisplay: "laptop"), .default)
        XCTAssertEqual(decoded.lastDisplay, "external")
    }

    func testOlderConfigsGetTheNewDefaults() throws {
        let json = Data(#"{"focusMinutes":25,"breakMinutes":5,"pinnedHUDEnabled":true}"#.utf8)
        let config = try JSONDecoder().decode(AppConfig.self, from: json)
        XCTAssertEqual(config.hud, HUDSettings())
        XCTAssertEqual(config.hud.size, .compact)
        XCTAssertEqual(config.hud.restingOpacity, 0.35)
        XCTAssertFalse(config.hud.clickThrough)
    }
}
