@testable import FocusLockCore
import XCTest

final class BlockedSiteTests: XCTestCase {
    func testNormalizesWhateverIsPasted() {
        XCTAssertEqual(SitePattern.normalize("YouTube.com"), "youtube.com")
        XCTAssertEqual(SitePattern.normalize("https://www.youtube.com/"), "youtube.com")
        XCTAssertEqual(SitePattern.normalize("reddit.com/r/all/?sort=top#x"), "reddit.com/r/all")
        // A pasted link means the site, not the one video it points at.
        XCTAssertEqual(SitePattern.normalize("https://www.YouTube.com/watch?v=abc"), "youtube.com")
        XCTAssertEqual(SitePattern.normalize(" news.ycombinator.com:443 "), "news.ycombinator.com")
        XCTAssertNil(SitePattern.normalize("localhost"))
        XCTAssertNil(SitePattern.normalize("not a site"))
        XCTAssertNil(SitePattern.normalize("ftp://example.com"))
        XCTAssertNil(SitePattern.normalize(""))
    }

    func testHostCoversSubdomainsButNotLookalikes() {
        let site = BlockedSite(pattern: "youtube.com")
        XCTAssertTrue(site.matches(URL(string: "https://www.youtube.com/watch?v=1")!))
        XCTAssertTrue(site.matches(URL(string: "https://m.youtube.com/")!))
        XCTAssertFalse(site.matches(URL(string: "https://notyoutube.com/")!))
        XCTAssertFalse(site.matches(URL(string: "https://youtube.com.evil.io/")!))
        XCTAssertFalse(site.matches(URL(string: "file:///youtube.com")!))
    }

    func testPathPatternCoversOnlyThatSection() {
        let site = BlockedSite(pattern: "reddit.com/r/all")
        XCTAssertTrue(site.matches(URL(string: "https://www.reddit.com/r/all")!))
        XCTAssertTrue(site.matches(URL(string: "https://reddit.com/r/all/top")!))
        XCTAssertFalse(site.matches(URL(string: "https://reddit.com/r/allergies")!))
        XCTAssertFalse(site.matches(URL(string: "https://reddit.com/r/swift")!))
    }
}

final class ScheduleEvaluatorTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func testWeekdayMorningWindow() {
        let schedule = FocusSchedule(weekdays: FocusSchedule.weekdaysOnly, startMinute: 540, endMinute: 720)
        // 2026-09-28 is a Monday, 2026-09-27 a Sunday.
        XCTAssertNotNil(ScheduleEvaluator.activeOccurrence(in: [schedule], at: date(2026, 9, 28, 9, 30), calendar: calendar))
        XCTAssertNil(ScheduleEvaluator.activeOccurrence(in: [schedule], at: date(2026, 9, 28, 8, 59), calendar: calendar))
        XCTAssertNil(ScheduleEvaluator.activeOccurrence(in: [schedule], at: date(2026, 9, 28, 12, 0), calendar: calendar))
        XCTAssertNil(ScheduleEvaluator.activeOccurrence(in: [schedule], at: date(2026, 9, 27, 10), calendar: calendar))
    }

    func testOvernightWindowRunsPastMidnight() {
        // Friday 22:00 to 02:00.
        let schedule = FocusSchedule(weekdays: [6], startMinute: 22 * 60, endMinute: 2 * 60)
        let saturdayOne = date(2026, 10, 3, 1)
        let occurrence = ScheduleEvaluator.activeOccurrence(in: [schedule], at: saturdayOne, calendar: calendar)
        XCTAssertEqual(occurrence?.start, date(2026, 10, 2, 22))
        XCTAssertEqual(occurrence?.end, date(2026, 10, 3, 2))
        XCTAssertNil(ScheduleEvaluator.activeOccurrence(in: [schedule], at: date(2026, 10, 3, 22, 30), calendar: calendar))
    }

    func testDisabledAndEmptySchedulesNeverRun() {
        var disabled = FocusSchedule(weekdays: [2], startMinute: 0, endMinute: 23 * 60)
        disabled.isEnabled = false
        let noDays = FocusSchedule(weekdays: [], startMinute: 0, endMinute: 23 * 60)
        XCTAssertNil(ScheduleEvaluator.activeOccurrence(in: [disabled, noDays], at: date(2026, 9, 28, 10), calendar: calendar))
    }

    func testNextOccurrenceSkipsTheWeekend() {
        let schedule = FocusSchedule(weekdays: FocusSchedule.weekdaysOnly, startMinute: 540, endMinute: 720)
        let fridayAfternoon = date(2026, 10, 2, 15)
        let next = ScheduleEvaluator.nextOccurrence(in: [schedule], after: fridayAfternoon, calendar: calendar)
        XCTAssertEqual(next?.start, date(2026, 10, 5, 9))
    }

    func testWindowKeepsWallClockTimesAcrossDaylightSaving() {
        // US clocks go back on 2026-11-01.
        let schedule = FocusSchedule(weekdays: [1], startMinute: 540, endMinute: 720)
        let occurrence = ScheduleEvaluator.activeOccurrence(in: [schedule], at: date(2026, 11, 1, 9, 5), calendar: calendar)
        XCTAssertEqual(calendar.component(.hour, from: occurrence!.start), 9)
        XCTAssertEqual(calendar.component(.hour, from: occurrence!.end), 12)
    }

    func testOccurrenceKeyDiffersBetweenDays() {
        let schedule = FocusSchedule(weekdays: FocusSchedule.weekdaysOnly, startMinute: 540, endMinute: 720)
        let monday = ScheduleEvaluator.activeOccurrence(in: [schedule], at: date(2026, 9, 28, 10), calendar: calendar)
        let tuesday = ScheduleEvaluator.activeOccurrence(in: [schedule], at: date(2026, 9, 29, 10), calendar: calendar)
        XCTAssertNotEqual(monday?.key, tuesday?.key)
    }
}

final class StrictModeTests: XCTestCase {
    func testLockHoldsOnlyDuringStrictFocus() {
        XCTAssertTrue(StrictPolicy.isLocked(phase: .focus, sessionIsStrict: true))
        XCTAssertFalse(StrictPolicy.isLocked(phase: .break, sessionIsStrict: true))
        XCTAssertFalse(StrictPolicy.isLocked(phase: .focus, sessionIsStrict: false))
        XCTAssertFalse(StrictPolicy.allows(.endSession, phase: .focus, sessionIsStrict: true))
        XCTAssertTrue(StrictPolicy.allows(.endSession, phase: .breakEnded, sessionIsStrict: true))
    }

    func testEscapeNeedsTheSentenceThenTheWait() {
        var escape = StrictEscape(waitSeconds: 120)
        let start = Date(timeIntervalSince1970: 0)

        XCTAssertFalse(escape.request(typed: "let me out", at: start))
        XCTAssertNil(escape.remaining(at: start))

        XCTAssertTrue(escape.request(typed: "  i am ending THIS focus block early on purpose. ", at: start))
        XCTAssertEqual(escape.remaining(at: start.addingTimeInterval(30)), 90)
        XCTAssertFalse(escape.isReady(at: start.addingTimeInterval(119)))
        XCTAssertTrue(escape.isReady(at: start.addingTimeInterval(120)))
    }

    func testRetypingDoesNotRestartTheWait() {
        var escape = StrictEscape(waitSeconds: 120)
        let start = Date(timeIntervalSince1970: 0)
        escape.request(typed: StrictEscape.phrase, at: start)
        escape.request(typed: StrictEscape.phrase, at: start.addingTimeInterval(100))
        XCTAssertEqual(escape.remaining(at: start.addingTimeInterval(100)), 20)

        escape.cancel()
        XCTAssertNil(escape.remaining(at: start.addingTimeInterval(100)))
    }

    func testMissingWordDoesNotCount() {
        XCTAssertFalse(StrictEscape.accepts("I am ending this block early on purpose"))
    }
}

final class BreakSuggestionTests: XCTestCase {
    func testRotatesThroughEnabledKindsAndSkipsWalksOnShortBreaks() {
        var settings = BreakSuggestionSettings()
        let kinds = (1...12).compactMap {
            BreakSuggestions.suggestion(forCycle: $0, breakMinutes: 5, settings: settings)?.kind
        }
        XCTAssertEqual(Set(kinds).count, BreakSuggestionKind.allCases.count)

        let short = (1...12).compactMap {
            BreakSuggestions.suggestion(forCycle: $0, breakMinutes: 3, settings: settings)?.kind
        }
        XCTAssertFalse(short.contains(.walk))

        settings.kinds = [.water]
        XCTAssertEqual(BreakSuggestions.suggestion(forCycle: 7, breakMinutes: 5, settings: settings)?.kind, .water)
    }

    func testLongBreaksLeanTowardsAWalk() {
        let settings = BreakSuggestionSettings()
        let walks = (1...10).filter {
            BreakSuggestions.suggestion(forCycle: $0, breakMinutes: 15, settings: settings)?.kind == .walk
        }
        XCTAssertGreaterThanOrEqual(walks.count, 5)
    }

    func testOffOrEmptyGivesNothing() {
        var settings = BreakSuggestionSettings()
        settings.enabled = false
        XCTAssertNil(BreakSuggestions.suggestion(forCycle: 1, breakMinutes: 5, settings: settings))
        settings.enabled = true
        settings.kinds = [.walk]
        XCTAssertNil(BreakSuggestions.suggestion(forCycle: 1, breakMinutes: 2, settings: settings))
    }

    func testUnknownKindsFromANewerBuildAreDropped() throws {
        let json = #"{"enabled":true,"kinds":["water","levitate"],"eyeReminderDuringFocus":true}"#
        let settings = try JSONDecoder().decode(BreakSuggestionSettings.self, from: Data(json.utf8))
        XCTAssertEqual(settings.kinds, [.water])
        XCTAssertTrue(settings.eyeReminderDuringFocus)
    }
}

final class HotkeySettingsTests: XCTestCase {
    func testAssigningATakenComboMovesIt() {
        var settings = HotkeySettings()
        let startCombo = settings.start
        settings.assign(startCombo, to: .skip)
        XCTAssertNil(settings.start)
        XCTAssertEqual(settings.skip, startCombo)
    }

    func testClearedShortcutStaysClearedButMissingOnesGetDefaults() throws {
        var settings = HotkeySettings()
        settings.stop = nil
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(HotkeySettings.self, from: data)
        XCTAssertNil(decoded.stop)
        XCTAssertNotNil(decoded.start)

        let legacy = try JSONDecoder().decode(HotkeySettings.self, from: Data(#"{"enabled":false}"#.utf8))
        XCTAssertFalse(legacy.enabled)
        XCTAssertEqual(legacy.start, HotkeySettings().start)
    }

    func testComboWithoutACommandModifierIsNotUsable() {
        XCTAssertFalse(KeyCombo(keyCode: 1, modifiers: KeyCombo.shift).isUsable)
        XCTAssertTrue(KeyCombo(keyCode: 1, modifiers: KeyCombo.option).isUsable)
        XCTAssertEqual(KeyCombo(keyCode: 1, modifiers: KeyCombo.control | KeyCombo.option | KeyCombo.command).modifierSymbols, "⌃⌥⌘")
    }
}

final class ConfigMigrationTests: XCTestCase {
    func testGoalsAndCategoriesComeAcrossFromStreamSettings() throws {
        let json = """
        {"focusMinutes":25,"breakMinutes":5,"blockerMode":"guard","blockedApps":[],
         "stream":{"enabled":true,"goal":"Ship v1","category":"Coding",
                   "categories":["Study","Coding","Side project"],"twitchChannel":"someone"}}
        """
        let config = try JSONDecoder().decode(AppConfig.self, from: Data(json.utf8))
        XCTAssertEqual(config.task.goal, "Ship v1")
        XCTAssertEqual(config.task.category, "Coding")
        XCTAssertEqual(config.task.categories, ["Study", "Coding", "Side project"])
        XCTAssertFalse(config.strict.enabled)
        XCTAssertTrue(config.schedules.isEmpty)
        XCTAssertTrue(config.hotkeys.enabled)
    }

    func testOneUnreadableSectionDoesNotResetTheRest() throws {
        let json = """
        {"focusMinutes":40,"breakMinutes":8,"blockerMode":"hideOnly","blockedApps":[],
         "schedules":"garbage","strict":{"enabled":true}}
        """
        let config = try JSONDecoder().decode(AppConfig.self, from: Data(json.utf8))
        XCTAssertEqual(config.focusMinutes, 40)
        XCTAssertEqual(config.blockerMode, .hideOnly)
        XCTAssertTrue(config.strict.enabled)
        XCTAssertTrue(config.schedules.isEmpty)
    }

    func testOldHistoryWithSharedFlagStillDecodes() throws {
        let line = #"{"blockedAppsCount":0,"breakMinutes":5,"endedAt":"2026-01-01T10:25:00Z","focusMinutes":25,"id":"0B8E6D1E-6F7B-4C7E-9A33-7E6A3C5B8D21","startedAt":"2026-01-01T10:00:00Z","status":"completed","strictMode":false,"task":{"category":"Study","goal":"Read","id":"7C1E0C3A-2B1D-4E7A-8F0B-1B2C3D4E5F60","shared":true}}"#
        let entry = try FocusLockJSONCoding.decoder.decode(SessionHistoryEntry.self, from: Data(line.utf8))
        XCTAssertEqual(entry.task?.goal, "Read")
    }
}

final class RunRecapTests: XCTestCase {
    private func entry(_ minutesAfter: Double, focus: Int, category: String, goal: String,
                       status: SessionHistoryStatus = .completed, outcome: CheckInOutcome? = nil) -> SessionHistoryEntry {
        let start = Date(timeIntervalSince1970: 10_000 + minutesAfter * 60)
        return SessionHistoryEntry(
            startedAt: start,
            endedAt: start.addingTimeInterval(TimeInterval(focus * 60)),
            focusMinutes: focus,
            breakMinutes: 5,
            status: status,
            blockedAppsCount: 0,
            strictMode: false,
            task: SessionTask(goal: goal, category: category),
            checkIn: outcome.map { SessionCheckIn(outcome: $0, note: "") }
        )
    }

    func testSumsOnlyThisRunsCompletedBlocks() {
        let history = [
            entry(-100, focus: 25, category: "Old", goal: "Before"),
            entry(0, focus: 50, category: "Coding", goal: "Ship v1"),
            entry(60, focus: 50, category: "Coding", goal: "Ship v1", outcome: .done),
            entry(120, focus: 25, category: "Writing", goal: "Post"),
            entry(150, focus: 25, category: "Writing", goal: "Post", status: .cancelled)
        ]
        let recap = RunRecap.make(from: history, since: Date(timeIntervalSince1970: 10_000))
        XCTAssertEqual(recap.blocks, 3)
        XCTAssertEqual(recap.focusMinutes, 125)
        XCTAssertEqual(recap.categories.map(\.name), ["Coding", "Writing"])
        XCTAssertEqual(recap.goalsDone, 1)
        XCTAssertEqual(recap.text, """
        LockIn recap · 3 blocks · 2h 5m focused
        Coding 1h 40m · Writing 25m
        ✓ Ship v1
        – Post
        """)
    }
}

final class TimerStrictAndSkipTests: XCTestCase {
    private func makeEngine(_ directory: URL, at date: Date) -> (TimerEngine, StateStore, SessionHistoryStore) {
        let stateStore = StateStore(baseDirectory: directory)
        let historyStore = SessionHistoryStore(baseDirectory: directory)
        let engine = TimerEngine(
            stateStore: stateStore,
            historyStore: historyStore,
            notificationService: NoopNotificationService(),
            clock: { date }
        )
        return (engine, stateStore, historyStore)
    }

    func testStrictSessionResumesAfterRelaunchInsteadOfBeingAbandoned() throws {
        let directory = try temporaryDirectory()
        let start = Date(timeIntervalSince1970: 50_000)
        try StateStore(baseDirectory: directory).saveSessionState(SessionState(
            state: .focus, startedAt: start, focusMinutes: 25, breakMinutes: 5, strictMode: true
        ))

        let (engine, stateStore, historyStore) = makeEngine(directory, at: start.addingTimeInterval(600))

        XCTAssertEqual(engine.snapshot.phase, .focus)
        XCTAssertTrue(engine.snapshot.isStrict)
        XCTAssertEqual(Int(engine.snapshot.remainingSeconds), 900)
        XCTAssertEqual(stateStore.loadSessionState()?.state, .focus)
        XCTAssertTrue(historyStore.loadHistory().isEmpty)
    }

    func testRelaxedSessionIsStillAbandonedOnRelaunch() throws {
        let directory = try temporaryDirectory()
        let start = Date(timeIntervalSince1970: 50_000)
        try StateStore(baseDirectory: directory).saveSessionState(SessionState(
            state: .focus, startedAt: start, focusMinutes: 25, breakMinutes: 5, strictMode: false
        ))

        let (engine, _, historyStore) = makeEngine(directory, at: start.addingTimeInterval(600))

        XCTAssertEqual(engine.snapshot.phase, .idle)
        XCTAssertEqual(historyStore.loadHistory().first?.status, .abandoned)
    }

    func testSkipFocusLogsTheMinutesWorkedAndStartsTheBreakNow() throws {
        let directory = try temporaryDirectory()
        let start = Date(timeIntervalSince1970: 60_000)
        let (engine, stateStore, historyStore) = makeEngine(directory, at: start)
        engine.startFocus(focusMinutes: 50, breakMinutes: 10, blockedAppsCount: 0, strictMode: false, now: start)

        let skipAt = start.addingTimeInterval(31 * 60 + 20)
        engine.skipFocus(now: skipAt)

        XCTAssertEqual(engine.snapshot.phase, .break)
        XCTAssertEqual(Int(engine.snapshot.remainingSeconds), 600)
        XCTAssertEqual(historyStore.loadHistory().first?.status, .completed)
        XCTAssertEqual(historyStore.loadHistory().first?.focusMinutes, 31)

        engine.refresh(now: skipAt.addingTimeInterval(601))
        XCTAssertEqual(engine.snapshot.phase, .breakEnded)
        XCTAssertEqual(stateStore.loadSessionState()?.focusMinutes, 50)
    }

    func testSkipInTheFirstMinuteCountsAsCancelled() throws {
        let directory = try temporaryDirectory()
        let start = Date(timeIntervalSince1970: 70_000)
        let (engine, _, historyStore) = makeEngine(directory, at: start)
        engine.startFocus(focusMinutes: 25, breakMinutes: 0, blockedAppsCount: 0, strictMode: false, now: start)

        engine.skipFocus(now: start.addingTimeInterval(20))

        XCTAssertEqual(engine.snapshot.phase, .completed)
        XCTAssertEqual(historyStore.loadHistory().first?.status, .cancelled)
    }
}

final class WebsiteGuardTests: XCTestCase {
    private final class StubScripting: BrowserScripting {
        var url: Result<URL?, BrowserScriptError> = .success(nil)
        private(set) var redirects: [String] = []

        func currentURL(in browser: SupportedBrowser) -> Result<URL?, BrowserScriptError> { url }

        func redirect(_ browser: SupportedBrowser, to url: String) -> Bool {
            redirects.append(url)
            return true
        }
    }

    func testRedirectsAMatchingTab() {
        let scripting = StubScripting()
        scripting.url = .success(URL(string: "https://www.youtube.com/watch?v=1"))
        let guardian = WebsiteGuard(scripting: scripting, blockedPage: { site, _ in "blocked:\(site.pattern)" })

        let outcome = guardian.inspect(.chrome, sites: [BlockedSite(pattern: "youtube.com")], endsAt: nil)

        guard case .blocked(let visit) = outcome else { return XCTFail("expected a block") }
        XCTAssertEqual(visit.site.pattern, "youtube.com")
        XCTAssertEqual(scripting.redirects, ["blocked:youtube.com"])
    }

    func testLeavesOtherSitesAlone() {
        let scripting = StubScripting()
        scripting.url = .success(URL(string: "https://developer.apple.com/"))
        let guardian = WebsiteGuard(scripting: scripting)

        guard case .clear = guardian.inspect(.safari, sites: [BlockedSite(pattern: "youtube.com")], endsAt: nil) else {
            return XCTFail("expected no block")
        }
        XCTAssertTrue(scripting.redirects.isEmpty)
    }

    func testReportsAMissingPermission() {
        let scripting = StubScripting()
        scripting.url = .failure(.notPermitted)
        let guardian = WebsiteGuard(scripting: scripting)

        guard case .denied = guardian.inspect(.arc, sites: [BlockedSite(pattern: "x.com")], endsAt: nil) else {
            return XCTFail("expected a permission problem")
        }
    }

    func testBlockedPageEscapesTheHost() {
        let html = BlockedPage.html(for: "<script>.com", until: nil)
        XCTAssertFalse(html.contains("<script>.com"))
        XCTAssertTrue(BlockedPage.dataURL(for: BlockedSite(pattern: "x.com"), until: nil).hasPrefix("data:text/html"))
    }

    func testRedirectScriptEscapesQuotes() {
        XCTAssertTrue(SupportedBrowser.safari.redirectScript(to: #"a"b"#).contains(#""a\"b""#))
        XCTAssertTrue(SupportedBrowser.chrome.readScript.contains("active tab of front window"))
        XCTAssertTrue(SupportedBrowser.safari.readScript.contains("current tab of front window"))
    }
}

final class IntegrationRequestTests: XCTestCase {
    func testSlackStatusRequestCarriesTheExpiry() throws {
        let expiry = Date(timeIntervalSince1970: 1_800_000_000)
        let request = SlackClient.statusRequest(token: "xoxp-1", text: "Focusing", emoji: ":lock:", expiration: expiry)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer xoxp-1")
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as? [String: Any]
        let profile = body?["profile"] as? [String: Any]
        XCTAssertEqual(profile?["status_text"] as? String, "Focusing")
        XCTAssertEqual(profile?["status_expiration"] as? Int, 1_800_000_000)
    }

    func testSlackFormRequestIsEncoded() {
        let request = SlackClient.request(method: "dnd.setSnooze", token: "t", form: ["num_minutes": "25"])
        XCTAssertEqual(request.url?.absoluteString, "https://slack.com/api/dnd.setSnooze")
        XCTAssertEqual(String(data: request.httpBody!, encoding: .utf8), "num_minutes=25")
    }

    func testDiscordFramesAreLittleEndianWithLength() throws {
        let frame = try XCTUnwrap(DiscordPresence.encodeFrame(opcode: .handshake, payload: ["v": 1]))
        XCTAssertEqual(Array(frame.prefix(4)), [0, 0, 0, 0])
        let length = frame[4..<8].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }.littleEndian
        XCTAssertEqual(Int(length), frame.count - 8)
    }

    func testDiscordActivityPayloadClearsWithNull() {
        let clear = DiscordPresence.activityPayload(nil, pid: 42)
        let args = clear["args"] as? [String: Any]
        XCTAssertTrue(args?["activity"] is NSNull)

        let set = DiscordPresence.activityPayload(.init(details: "Focusing", state: "Ship v1",
                                                        endsAt: Date(timeIntervalSince1970: 100)), pid: 42)
        let activity = (set["args"] as? [String: Any])?["activity"] as? [String: Any]
        XCTAssertEqual((activity?["timestamps"] as? [String: Int])?["end"], 100)
    }

    func testWebhookLinksAreCheckedAndMentionsDisabled() throws {
        XCTAssertTrue(DiscordWebhook.isValidLink("https://discord.com/api/webhooks/1/abc"))
        XCTAssertFalse(DiscordWebhook.isValidLink("https://evil.com/api/webhooks/1/abc"))
        XCTAssertFalse(DiscordWebhook.isValidLink("http://discord.com/api/webhooks/1/abc"))

        let request = try DiscordWebhook.request(link: "https://discord.com/api/webhooks/1/abc", content: "@everyone hi")
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as? [String: Any]
        XCTAssertEqual((body?["allowed_mentions"] as? [String: [String]])?["parse"], [])
    }

    func testDiscordClientIDLooksLikeASnowflake() {
        var settings = IntegrationSettings()
        settings.discordClientID = "1234567890123456789"
        XCTAssertTrue(settings.hasValidDiscordClientID)
        settings.discordClientID = "abc"
        XCTAssertFalse(settings.hasValidDiscordClientID)
    }
}
