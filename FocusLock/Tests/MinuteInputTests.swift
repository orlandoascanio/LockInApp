import XCTest
@testable import FocusLockCore

final class MinuteInputTests: XCTestCase {
    func testKeepsOnlyASCIIDigits() {
        XCTAssertEqual(MinuteInput.digitsOnly("60"), "60")
        XCTAssertEqual(MinuteInput.digitsOnly("1 hour"), "1")
        XCTAssertEqual(MinuteInput.digitsOnly("git"), "")
        XCTAssertEqual(MinuteInput.digitsOnly("1h 30m"), "130")
    }

    func testParsesDigitsAsMinutes() {
        XCTAssertEqual(MinuteInput.parseMinutes("0"), 0)
        XCTAssertEqual(MinuteInput.parseMinutes("60"), 60)
        XCTAssertEqual(MinuteInput.parseMinutes("180"), 180)
    }

    func testRejectsEmptyOrNonNumericInput() {
        XCTAssertNil(MinuteInput.parseMinutes(""))
        XCTAssertNil(MinuteInput.parseMinutes("git"))
        XCTAssertNil(MinuteInput.parseMinutes("60m"))
        XCTAssertNil(MinuteInput.parseMinutes("-5"))
    }
}
