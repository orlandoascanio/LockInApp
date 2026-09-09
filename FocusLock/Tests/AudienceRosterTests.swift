import FocusLockCore
import XCTest

final class AudienceRosterTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 10_000)

    private func filled(_ count: Int) -> AudienceRoster {
        var roster = AudienceRoster(autoApprove: true, now: now)
        for index in 0..<count {
            roster.submit(name: "viewer\(index)", text: "task \(index)", now: now)
        }
        return roster
    }

    // MARK: - Getting on screen

    func testSubmissionsAreHeldForApprovalByDefault() {
        var roster = AudienceRoster(now: now)

        guard case .held = roster.submit(name: "maya", text: "read chapter 3", now: now) else {
            return XCTFail("a stranger's text must not reach the broadcast unreviewed")
        }
        XCTAssertTrue(roster.admitted.isEmpty)
        XCTAssertEqual(roster.held.count, 1)

        XCTAssertTrue(roster.approve(roster.held[0].id))
        XCTAssertEqual(roster.admitted.map(\.name), ["maya"])
        XCTAssertTrue(roster.held.isEmpty)
    }

    func testAutoApproveAdmitsImmediately() {
        var roster = AudienceRoster(autoApprove: true, now: now)
        guard case .admitted = roster.submit(name: "tom", text: "rewrite my CV", now: now) else {
            return XCTFail("auto-approve should skip the queue")
        }
        XCTAssertEqual(roster.admitted.count, 1)
    }

    func testOneTaskPerPersonKeepsTheirRowAndPosition() {
        var roster = filled(3)
        let originalID = roster.admitted[0].id

        roster.submit(name: "VIEWER0", text: "changed my mind", now: now.addingTimeInterval(60))

        XCTAssertEqual(roster.admitted.count, 3, "a second task must replace, not stack")
        XCTAssertEqual(roster.admitted[0].id, originalID, "the row should update, not jump to the end")
        XCTAssertEqual(roster.admitted[0].text, "changed my mind")
    }

    func testDoneMarksTheirRowWithoutRemovingIt() {
        var roster = filled(2)
        roster.apply(.done, from: "viewer1", now: now)
        XCTAssertEqual(roster.admitted.count, 2)
        XCTAssertTrue(roster.admitted[1].isDone)
        XCTAssertFalse(roster.admitted[0].isDone)
    }

    // MARK: - What must never reach the broadcast

    func testLinksAreRefusedButOrdinaryDotsSurvive() {
        var roster = AudienceRoster(autoApprove: true, now: now)
        for (index, advert) in ["check out twitch.tv/me", "https://example.com", "WWW.Spam.NET", "buy at shop.xyz"].enumerated() {
            XCTAssertEqual(roster.submit(name: "spammer\(index)", text: advert, now: now),
                           .rejected(.containsLink), advert)
        }
        // A task that merely contains a dot is not an advert.
        guard case .admitted = roster.submit(name: "kai", text: "fix index.js and v1.2 notes", now: now) else {
            return XCTFail("ordinary punctuation should not be treated as a link")
        }
    }

    func testTextIsFlattenedAndCapped() {
        var roster = AudienceRoster(autoApprove: true, now: now)
        roster.submit(name: "  ana\n", text: "line one\nline two\tand\u{0007}more", now: now)
        let task = roster.admitted[0]
        XCTAssertEqual(task.name, "ana")
        XCTAssertFalse(task.text.contains("\n"), "newlines would break the window layout")
        XCTAssertEqual(task.text, "line one line two and more")

        roster.submit(name: "sam", text: String(repeating: "x", count: 500), now: now)
        XCTAssertEqual(roster.admitted[1].text.count, AudienceRoster.maxTaskLength)
    }

    func testRepeatSubmissionsAreRateLimited() {
        var roster = AudienceRoster(autoApprove: true, now: now)
        roster.submit(name: "maya", text: "first", now: now)
        XCTAssertEqual(roster.submit(name: "maya", text: "spam", now: now.addingTimeInterval(2)), .rejected(.tooSoon))
        guard case .admitted = roster.submit(name: "maya", text: "second", now: now.addingTimeInterval(30)) else {
            return XCTFail("waiting should be enough to post again")
        }
    }

    func testBlockingClearsTheirTextFromScreenImmediately() {
        var roster = filled(3)
        roster.block(name: "Viewer1")

        XCTAssertEqual(roster.admitted.map(\.name), ["viewer0", "viewer2"])
        XCTAssertEqual(roster.submit(name: "viewer1", text: "again", now: now.addingTimeInterval(600)),
                       .rejected(.blocked))

        roster.unblock(name: "viewer1")
        guard case .admitted = roster.submit(name: "viewer1", text: "sorry", now: now.addingTimeInterval(600)) else {
            return XCTFail("unblocking should let them back in")
        }
    }

    func testEmptyOrNamelessSubmissionsAreRejected() {
        var roster = AudienceRoster(autoApprove: true, now: now)
        XCTAssertEqual(roster.submit(name: "maya", text: "   ", now: now), .rejected(.empty))
        XCTAssertEqual(roster.submit(name: " ", text: "something", now: now), .rejected(.empty))
    }

    // MARK: - Everyone gets seen

    func testEveryoneFitsOnOnePageWhenThereAreFewPeople() {
        let page = filled(6).page(size: 8, at: now)
        XCTAssertEqual(page.count, 1)
        XCTAssertFalse(page.rotates, "a roster that fits must not flicker")
        XCTAssertEqual(page.interval, 0)
        XCTAssertEqual(page.tasks.count, 6)
    }

    func testLargeRostersPageThroughEveryNameWithinOneBlock() {
        let roster = filled(100)
        let page = roster.page(size: 8, at: now)
        XCTAssertEqual(page.count, 13)
        XCTAssertTrue(page.rotates)

        // A fixed minute per page would leave the last person unseen for 13
        // minutes; the interval tightens instead so a full pass stays short.
        XCTAssertLessThanOrEqual(Double(page.count) * page.interval, AudienceRoster.fullCycleTarget + 1)
        XCTAssertGreaterThanOrEqual(page.interval, AudienceRoster.minimumPageInterval)

        // Every single person appears within one full cycle.
        var seen = Set<String>()
        for step in 0..<page.count {
            let at = now.addingTimeInterval(page.interval * (Double(step) + 0.5))
            let current = roster.page(size: 8, at: at)
            XCTAssertEqual(current.index, step)
            current.tasks.forEach { seen.insert($0.name) }
        }
        XCTAssertEqual(seen.count, 100)

        // And it wraps rather than running off the end.
        XCTAssertEqual(roster.page(size: 8, at: now.addingTimeInterval(page.interval * 13.5)).index, 0)
    }

    func testTwoPagesRotateSlowlyRatherThanFlickering() {
        let page = filled(10).page(size: 8, at: now)
        XCTAssertEqual(page.count, 2)
        XCTAssertEqual(page.interval, AudienceRoster.maximumPageInterval)
    }

    func testAnEmptyRosterStillReportsAReadablePage() {
        let page = AudienceRoster(now: now).page(size: 8, at: now)
        XCTAssertTrue(page.tasks.isEmpty)
        XCTAssertFalse(page.rotates)
        XCTAssertEqual(page.count, 1)
    }

    // MARK: - Words

    func testBlockedWordsSurviveTheUsualDodges() {
        var roster = AudienceRoster(autoApprove: true, now: now)
        roster.blockedTerms = ["badword", "slur"]

        let dodges = ["badword", "BadWord", "b4dw0rd", "b a d w o r d", "b.a.d.w.o.r.d",
                      "baaaadwooord", "bádwörd", "my badword task"]
        for (index, dodge) in dodges.enumerated() {
            // A fresh sender each time, so this measures the filter and not
            // the strike counter that follows it.
            XCTAssertEqual(roster.submit(name: "viewer\(index)", text: dodge, now: now),
                           .rejected(.blockedWord), dodge)
        }
    }

    func testOrdinaryWordsAreNotCaughtByShortEntries() {
        var roster = AudienceRoster(autoApprove: true, now: now)
        roster.blockedTerms = ["ass", "hell"]

        // The Scunthorpe problem: a short entry must not fire inside a word.
        for (index, innocent) in ["classroom notes", "pass my exam", "hello everyone", "shell script"].enumerated() {
            guard case .admitted = roster.submit(name: "viewer\(index)", text: innocent, now: now) else {
                return XCTFail("should allow: \(innocent)")
            }
        }
        // The word itself, standing alone, is still refused.
        XCTAssertEqual(roster.submit(name: "rude", text: "ass", now: now), .rejected(.blockedWord))
    }

    func testTheNameIsFilteredTooSinceItGoesOnScreen() {
        var roster = AudienceRoster(autoApprove: true, now: now)
        roster.blockedTerms = ["badword"]
        XCTAssertEqual(roster.submit(name: "badword_fan", text: "reading", now: now), .rejected(.blockedWord))
    }

    func testTwoDeliberateAttemptsBlockThemForTheStream() {
        var roster = AudienceRoster(autoApprove: true, now: now)
        roster.blockedTerms = ["badword"]

        XCTAssertEqual(roster.submit(name: "troll", text: "badword", now: now), .rejected(.blockedWord))
        XCTAssertEqual(roster.submit(name: "troll", text: "spam.com", now: now.addingTimeInterval(60)),
                       .rejected(.blocked), "the second deliberate attempt should end it")
        XCTAssertTrue(roster.blocked.contains("troll"))

        // An honest mistake is not a strike: an empty task must not count.
        var forgiving = AudienceRoster(autoApprove: true, now: now)
        forgiving.submit(name: "maya", text: "  ", now: now)
        forgiving.submit(name: "maya", text: "   ", now: now)
        XCTAssertFalse(forgiving.blocked.contains("maya"))
        XCTAssertTrue(AudienceRoster.Rejection.blockedWord.isDeliberate)
        XCTAssertFalse(AudienceRoster.Rejection.tooSoon.isDeliberate)
    }

    func testDefaultTermsAreAppliedWithoutConfiguration() {
        var roster = AudienceRoster(autoApprove: true, now: now)
        XCTAssertEqual(roster.submit(name: "viewer", text: "kys", now: now), .rejected(.blockedWord))
    }

    func testHostWordListMergesFromFile() throws {
        let url = try temporaryDirectory().appendingPathComponent("blocked-words.txt")
        try "# a comment\n\nlocalterm\n  spaced term  \n".write(to: url, atomically: true, encoding: .utf8)
        let terms = AudienceFilter.terms(fromFileAt: url)
        XCTAssertEqual(terms, ["localterm", "spaced term"])
        XCTAssertTrue(AudienceFilter.terms(fromFileAt: url.appendingPathComponent("missing")).isEmpty)
    }

    // MARK: - How long they have been here

    func testElapsedLabelReadsAsTimeSpentNotNoise() {
        let task = AudienceTask(name: "maya", text: "reading", joinedAt: now)
        XCTAssertNil(task.elapsedLabel(at: now.addingTimeInterval(30)), "under a minute should show nothing")
        XCTAssertEqual(task.elapsedLabel(at: now.addingTimeInterval(60)), "1m")
        XCTAssertEqual(task.elapsedLabel(at: now.addingTimeInterval(34 * 60)), "34m")
        XCTAssertEqual(task.elapsedLabel(at: now.addingTimeInterval(60 * 60)), "1h")
        XCTAssertEqual(task.elapsedLabel(at: now.addingTimeInterval(82 * 60)), "1h 22m")
    }

    func testTimeOnScreenSurvivesChangingYourTask() {
        var roster = filled(1)
        let joined = roster.admitted[0].joinedAt
        roster.submit(name: "viewer0", text: "changed my mind", now: now.addingTimeInterval(1_800))
        XCTAssertEqual(roster.admitted[0].joinedAt, joined,
                       "updating a task must not reset how long they have been here")
    }

    // MARK: - Being told about it

    func testArrivalsAreGroupedIntoOneInterruption() {
        var throttle = AudienceAlertThrottle()

        XCTAssertTrue(throttle.shouldAlert(waiting: 1, at: now))
        XCTAssertFalse(throttle.shouldAlert(waiting: 2, at: now.addingTimeInterval(1)))
        XCTAssertFalse(throttle.shouldAlert(waiting: 20, at: now.addingTimeInterval(14)),
                       "a rush of arrivals is one interruption, not twenty")
        XCTAssertTrue(throttle.shouldAlert(waiting: 21, at: now.addingTimeInterval(16)))
    }

    func testClearingTheQueueLetsTheNextPersonThroughImmediately() {
        var throttle = AudienceAlertThrottle()
        XCTAssertTrue(throttle.shouldAlert(waiting: 1, at: now))

        // Host approves everyone.
        XCTAssertFalse(throttle.shouldAlert(waiting: 0, at: now.addingTimeInterval(2)))

        // The next arrival should not serve out someone else's cooldown.
        XCTAssertTrue(throttle.shouldAlert(waiting: 1, at: now.addingTimeInterval(3)))
    }

    func testAnEmptyQueueNeverAlerts() {
        var throttle = AudienceAlertThrottle()
        XCTAssertFalse(throttle.shouldAlert(waiting: 0, at: now))
    }

    // MARK: - Commands

    func testAdvertisedCommandAndItsNearSynonymsAllLand() {
        XCTAssertEqual(AudienceCommand.parse("!task read chapter 3"), .task("read chapter 3"))
        XCTAssertEqual(AudienceCommand.parse("!goal read chapter 3"), .task("read chapter 3"))
        XCTAssertEqual(AudienceCommand.parse("!doing laundry"), .task("laundry"))
        XCTAssertEqual(AudienceCommand.parse("  !TASK:  thesis intro  "), .task("thesis intro"))
        XCTAssertEqual(AudienceCommand.parse("!done"), .done)
        XCTAssertEqual(AudienceCommand.parse("!finished!"), .done)
    }

    func testOrdinaryChatIsNotACommand() {
        XCTAssertNil(AudienceCommand.parse("good luck everyone"))
        XCTAssertNil(AudienceCommand.parse("!"))
        XCTAssertNil(AudienceCommand.parse("!lurk"))
        XCTAssertNil(AudienceCommand.parse("!task"), "a bare command is someone testing it, not a submission")
        XCTAssertNil(AudienceCommand.parse("i will !task later"))
    }
}
