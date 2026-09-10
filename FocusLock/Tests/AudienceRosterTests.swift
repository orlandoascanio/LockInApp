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

    func testFinishingOneStartsANewLineRatherThanErasingIt() {
        var roster = filled(2)
        roster.apply(.done, from: "viewer0", now: now.addingTimeInterval(60))
        roster.submit(name: "viewer0", text: "and now the washing up", now: now.addingTimeInterval(600))

        XCTAssertEqual(roster.admitted.count, 3, "the finished task has earned its place on the wall")
        XCTAssertTrue(roster.admitted[0].isDone)
        XCTAssertEqual(roster.admitted[0].text, "task 0", "a finished row must not be overwritten")
        XCTAssertEqual(roster.admitted[2].name, "viewer0")
        XCTAssertFalse(roster.admitted[2].isDone)
        XCTAssertEqual(roster.admitted[2].joinedAt, now,
                       "someone on their second task has been here since their first")
    }

    func testDoneAlwaysTakesTheirNewestOpenTask() {
        var roster = filled(1)
        roster.apply(.done, from: "viewer0", now: now.addingTimeInterval(60))
        roster.submit(name: "viewer0", text: "second thing", now: now.addingTimeInterval(600))
        roster.apply(.done, from: "viewer0", now: now.addingTimeInterval(900))

        XCTAssertEqual(roster.admitted.map(\.isDone), [true, true])
        XCTAssertEqual(roster.tally.completed, 2)
    }

    func testPeopleAreCountedAsPeopleNotAsTasks() {
        var roster = filled(3)
        XCTAssertEqual(roster.peopleCount, 3)

        roster.apply(.done, from: "viewer0", now: now.addingTimeInterval(60))
        roster.submit(name: "viewer0", text: "second thing", now: now.addingTimeInterval(600))
        XCTAssertEqual(roster.admitted.count, 4)
        XCTAssertEqual(roster.peopleCount, 3,
                       "someone on their second task is still one person in the room")

        roster.block(name: "viewer0")
        XCTAssertEqual(roster.peopleCount, 2)
    }

    // MARK: - The running count

    func testTheTallyCountsTheStreamRatherThanThePage() {
        var roster = filled(3)
        XCTAssertEqual(roster.tally.label, "0/3")

        roster.apply(.done, from: "viewer1", now: now.addingTimeInterval(60))
        XCTAssertEqual(roster.tally.label, "1/3")

        roster.submit(name: "viewer1", text: "something else", now: now.addingTimeInterval(600))
        XCTAssertEqual(roster.tally.label, "1/4", "a second task is a second task, not a rewrite")
    }

    func testCorrectingATaskDoesNotInflateTheCount() {
        var roster = filled(1)
        roster.submit(name: "viewer0", text: "what I actually meant", now: now.addingTimeInterval(60))
        XCTAssertEqual(roster.tally.label, "0/1")
    }

    func testFinishingTwiceOnlyCountsOnce() {
        var roster = filled(1)
        roster.apply(.done, from: "viewer0", now: now.addingTimeInterval(60))
        roster.apply(.done, from: "viewer0", now: now.addingTimeInterval(120))
        XCTAssertEqual(roster.tally.label, "1/1")
    }

    func testHeldTasksAreCountedOnlyOnceTheyReachTheWall() {
        var roster = AudienceRoster(now: now)
        roster.submit(name: "maya", text: "read chapter 3", now: now)
        XCTAssertTrue(roster.tally.isEmpty, "nothing on screen yet is nothing to count")

        roster.approveAll()
        XCTAssertEqual(roster.tally.label, "0/1")
    }

    func testTakingARowDownTakesItOutOfTheCount() {
        var roster = filled(3)
        roster.apply(.done, from: "viewer0", now: now.addingTimeInterval(60))
        XCTAssertEqual(roster.tally.label, "1/3")

        roster.remove(roster.admitted[0].id)
        XCTAssertEqual(roster.tally.label, "0/2", "a task the host took down never happened")

        roster.block(name: "viewer1")
        XCTAssertEqual(roster.tally.label, "0/1")
    }

    func testRowsAgedOffALongWallStayInTheCount() {
        let roster = filled(AudienceRoster.maxTracked + 5)
        XCTAssertEqual(roster.admitted.count, AudienceRoster.maxTracked)
        XCTAssertEqual(roster.tally.total, AudienceRoster.maxTracked + 5,
                       "running out of room on the wall is not the same as withdrawing a task")
    }

    func testTheCountBelongsToOneStream() {
        var roster = filled(2)
        roster.apply(.done, from: "viewer0", now: now.addingTimeInterval(60))
        roster.clear(now: now.addingTimeInterval(3_600))
        XCTAssertTrue(roster.tally.isEmpty)
        XCTAssertEqual(roster.tally.label, "0/0")
    }

    /// A busy hour of chat, played through the roster the way it would really
    /// arrive: people joining, correcting themselves, finishing, starting
    /// something else, and the host taking rows down and blocking people. The
    /// point is not any one of those — it is that the count on screen still
    /// agrees with the wall after two thousand of them in an order nobody
    /// chose. Seeded, so a failure is reproducible.
    func testTheCountSurvivesAnHourOfRealisticChat() {
        var random = SeededGenerator(seed: 0x5EED)
        var roster = AudienceRoster(autoApprove: true, now: now)
        let names = (0..<60).map { "viewer\($0)" }
        var clock = now
        var everFinished = 0

        for step in 0..<2_000 {
            clock = clock.addingTimeInterval(.random(in: 5...45, using: &random))
            let who = names.randomElement(using: &random)!

            switch Int.random(in: 0..<100, using: &random) {
            case 0..<55:
                roster.submit(name: who, text: "task \(step)", now: clock)
            case 55..<85:
                if roster.markDone(name: who) { everFinished += 1 }
            case 85..<93:
                if let victim = roster.admitted.randomElement(using: &random) {
                    roster.remove(victim.id)
                }
            case 93..<97:
                roster.submit(name: who, text: "http://example.com buy followers", now: clock)
            default:
                roster.block(name: who)
            }

            XCTAssertGreaterThanOrEqual(roster.tally.total, roster.admitted.count,
                                        "every row on the wall was counted when it got there")
            XCTAssertGreaterThanOrEqual(roster.tally.completed,
                                        roster.admitted.filter(\.isDone).count,
                                        "every tick on screen was counted when it happened")
            XCTAssertLessThanOrEqual(roster.tally.completed, roster.tally.total,
                                     "more finished than posted is not a number anyone should see")
            XCTAssertGreaterThanOrEqual(roster.tally.completed, 0)
            XCTAssertLessThanOrEqual(roster.peopleCount, roster.admitted.count,
                                     "there can never be more people than rows they wrote")
        }

        XCTAssertGreaterThan(roster.tally.total, 0, "the run has to have exercised something")
        XCTAssertGreaterThan(everFinished, 0)
        XCTAssertLessThanOrEqual(roster.tally.completed, everFinished,
                                 "withdrawing a finished row must take it back out of the count")
        XCTAssertTrue(roster.admitted.allSatisfy { !roster.blocked.contains($0.name.lowercased()) },
                      "a blocked name must not be left on the wall")
        XCTAssertLessThanOrEqual(roster.admitted.count, AudienceRoster.maxTracked)
    }

    // MARK: - Running out of room

    func testAFullWallDropsFinishedRowsBeforeAnyoneStillWorking() {
        var roster = AudienceRoster(autoApprove: true, now: now)
        let finishers = (0..<120).map { "finisher\($0)" }
        for name in finishers {
            roster.submit(name: name, text: "an early task", now: now)
            roster.markDone(name: name)
        }
        for index in 0..<150 {
            roster.submit(name: "worker\(index)", text: "still going", now: now)
        }

        XCTAssertEqual(roster.admitted.count, AudienceRoster.maxTracked)
        XCTAssertEqual(roster.admitted.filter { !$0.isDone }.count, 150,
                       "nobody still working should be pushed off a wall they can see")
        XCTAssertEqual(roster.tally.total, 270, "ageing rows off is not withdrawing them")
        XCTAssertEqual(roster.tally.completed, 120)

        // Oldest finished first: the ones that survived are the recent ones.
        let survivingFinishers = roster.admitted.filter(\.isDone).map(\.name)
        XCTAssertEqual(survivingFinishers, Array(finishers.suffix(survivingFinishers.count)))
    }

    func testAWallOfNothingButOpenTasksStillGivesWay() {
        var roster = AudienceRoster(autoApprove: true, now: now)
        for index in 0..<(AudienceRoster.maxTracked + 30) {
            roster.submit(name: "worker\(index)", text: "task \(index)", now: now)
        }
        XCTAssertEqual(roster.admitted.count, AudienceRoster.maxTracked)
        XCTAssertEqual(roster.admitted.first?.name, "worker30",
                       "with nothing finished to drop, the oldest rows are what goes")
    }

    // MARK: - Surviving a quit

    func testTheWallIsWrittenDownAndReadBackAsItWas() throws {
        var roster = AudienceRoster(autoApprove: true, now: now)
        roster.submit(name: "maya", text: "read chapter 3", now: now)
        roster.markDone(name: "maya")
        roster.submit(name: "maya", text: "and then the dishes", now: now.addingTimeInterval(600))
        roster.submit(name: "tomas", text: "rewrite my CV", now: now.addingTimeInterval(60))
        roster.autoApprove = false
        roster.submit(name: "kit", text: "waiting to be shown", now: now.addingTimeInterval(120))
        roster.block(name: "spammer")

        let data = try JSONEncoder().encode(roster)
        let restored = try JSONDecoder().decode(AudienceRoster.self, from: data)

        XCTAssertEqual(restored.admitted, roster.admitted)
        XCTAssertEqual(restored.held, roster.held)
        XCTAssertEqual(restored.blocked, roster.blocked)
        XCTAssertEqual(restored.tally, roster.tally)
        XCTAssertEqual(restored.anchor, roster.anchor,
                       "paging is measured from the anchor, so a restored wall must not jump pages")
    }

    func testStrikesSurviveARelaunchSoNobodyGetsAFreshStart() throws {
        var roster = AudienceRoster(autoApprove: true, now: now)
        roster.submit(name: "chancer", text: "visit example.com now", now: now)
        XCTAssertTrue(roster.blocked.isEmpty, "one attempt is a warning, not a block")

        let data = try JSONEncoder().encode(roster)
        var restored = try JSONDecoder().decode(AudienceRoster.self, from: data)
        restored.submit(name: "chancer", text: "and also example.net", now: now.addingTimeInterval(60))
        XCTAssertTrue(restored.blocked.contains("chancer"),
                      "a relaunch must not hand someone their strikes back")
    }

    func testTheSavedWallNeverOutranksTheHostsOwnSettings() throws {
        var roster = AudienceRoster(autoApprove: true, now: now)
        roster.blockedTerms = ["somethingstale"]

        let data = try JSONEncoder().encode(roster)
        let restored = try JSONDecoder().decode(AudienceRoster.self, from: data)
        XCTAssertFalse(restored.autoApprove,
                       "approval is the host's setting, read back from config, never from here")
        XCTAssertEqual(restored.blockedTerms, AudienceFilter.defaultTerms,
                       "a stale word list on disk must not outrank one the host has edited")
    }

    func testOnlyChangesWorthSavingCountAsChanges() {
        var roster = filled(2)
        var same = roster
        same.autoApprove.toggle()
        same.blockedTerms = ["anything"]
        XCTAssertTrue(roster.matchesSavedState(of: same),
                      "settings read back from config are not a reason to rewrite the wall")

        var struck = roster
        struck.submit(name: "chancer", text: "visit example.com", now: now)
        XCTAssertFalse(roster.matchesSavedState(of: struck),
                       "a strike changes nothing on screen and still has to be written down")

        roster.markDone(name: "viewer0")
        XCTAssertFalse(same.matchesSavedState(of: roster))
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
        XCTAssertEqual(task.elapsedLabel(at: now.addingTimeInterval(30)), "now",
                       "someone who just arrived should not look like a forgotten row")
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

/// Reproducible pseudo-randomness. A generated-traffic test that cannot be
/// replayed is a test that reports a failure nobody can look at.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
