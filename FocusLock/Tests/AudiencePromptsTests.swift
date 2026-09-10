import FocusLockCore
import XCTest

final class AudiencePromptsTests: XCTestCase {
    private func line(at elapsed: TimeInterval, remaining: TimeInterval = 1_500, company: Bool = false) -> String? {
        AudiencePrompts.line(remaining: remaining, elapsed: elapsed, hasCompany: company)
    }

    func testTheInstructionTakesEveryOtherTurn() {
        // It is the only line that says what to actually do, so it should be
        // on screen about half the time rather than one line in five.
        XCTAssertEqual(line(at: 0), AudiencePrompts.primary)
        XCTAssertNotEqual(line(at: AudiencePrompts.interval), AudiencePrompts.primary)
        XCTAssertEqual(line(at: AudiencePrompts.interval * 2), AudiencePrompts.primary)
        XCTAssertNotEqual(line(at: AudiencePrompts.interval * 3), AudiencePrompts.primary)
    }

    func testItHoldsStillForAWholeIntervalRatherThanFlickering() {
        let first = line(at: 0)
        XCTAssertEqual(line(at: AudiencePrompts.interval - 1), first)
        XCTAssertNotEqual(line(at: AudiencePrompts.interval + 1), first)
    }

    func testTheEndOfABlockIsLeftAlone() {
        // Someone finishing a thought does not need a fresh invitation.
        XCTAssertNil(line(at: 600, remaining: AudiencePrompts.quietTail))
        XCTAssertNil(line(at: 600, remaining: 30))
        XCTAssertNil(line(at: 600, remaining: 0))
        XCTAssertNotNil(line(at: 600, remaining: AudiencePrompts.quietTail + 1))
    }

    func testTheDoneLineOnlyAppearsOnceThereIsAWall() {
        let withoutCompany = (0..<40).compactMap { line(at: AudiencePrompts.interval * Double($0)) }
        XCTAssertFalse(withoutCompany.contains { $0.contains("!done") },
                       "nothing to tick off yet")

        let withCompany = (0..<40).compactMap { line(at: AudiencePrompts.interval * Double($0), company: true) }
        XCTAssertTrue(withCompany.contains { $0.contains("!done") })
    }

    func testEveryOtherLineGetsATurnAndNothingIsEmpty() {
        let seen = Set((0..<40).compactMap { line(at: AudiencePrompts.interval * Double($0), company: true) })
        XCTAssertEqual(seen.count, AudiencePrompts.secondary.count + 2, "every line should come round")
        XCTAssertFalse(seen.contains { $0.trimmingCharacters(in: .whitespaces).isEmpty })
    }
}
