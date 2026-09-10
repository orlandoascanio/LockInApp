import FocusLockCore
import XCTest

final class StreamStagecraftTests: XCTestCase {
    func testMotionMigrationPreservesExistingStreamSettings() throws {
        let data = Data(#"{"stream":{"goal":"Read chapter 3","darkAppearance":false,"plannedBlocks":6}}"#.utf8)
        let config = try JSONDecoder().decode(AppConfig.self, from: data)
        XCTAssertEqual(config.stream.motion, .ambient)
        XCTAssertEqual(config.stream.goal, "Read chapter 3")
        XCTAssertFalse(config.stream.darkAppearance)
        XCTAssertEqual(config.stream.plannedBlocks, 6)

        let future = Data(#"{"stream":{"motion":"future-mode","goal":"Keep this goal"}}"#.utf8)
        let migrated = try JSONDecoder().decode(AppConfig.self, from: future)
        XCTAssertEqual(migrated.stream.motion, .ambient)
        XCTAssertEqual(migrated.stream.goal, "Keep this goal")
    }

    func testCommandLegendIsOnForStreamsSavedBeforeItExisted() throws {
        let data = Data(#"{"stream":{"goal":"Read chapter 3","showGoal":false}}"#.utf8)
        let config = try JSONDecoder().decode(AppConfig.self, from: data)
        XCTAssertTrue(config.stream.showCommands,
                      "a wall nobody knows how to join is the failure this exists to prevent")
        XCTAssertFalse(config.stream.showGoal)
    }

    func testCommandLegendAdvertisesTheCommandsThatActuallyWork() {
        for entry in AudienceCommand.legend {
            XCTAssertNotNil(AudienceCommand.parse("\(entry.command) tidy the kitchen"),
                            "\(entry.command) is on screen, so it has to be a command")
            XCTAssertFalse(entry.meaning.isEmpty)
        }
        XCTAssertTrue(AudienceCommand.legend.map(\.command).contains(AudienceCommand.advertised))
    }

    func testTheTickerStopsRepeatingCommandsThatAreAlreadyOnScreen() {
        let slots = (0..<8).map { slot in
            AudiencePrompts.line(remaining: 1_800,
                                 elapsed: AudiencePrompts.interval * Double(slot),
                                 hasCompany: true,
                                 commandsShown: true)
        }
        XCTAssertFalse(slots.contains(AudiencePrompts.primary),
                       "the legend already says this, and a screen should not say it twice")
        XCTAssertFalse(slots.contains(AudiencePrompts.withCompany))
        XCTAssertTrue(slots.allSatisfy { $0.map(AudiencePrompts.secondary.contains) ?? false })
    }

    func testTheTickerStillCarriesTheInstructionWithoutTheLegend() {
        let slots = (0..<4).map { slot in
            AudiencePrompts.line(remaining: 1_800,
                                 elapsed: AudiencePrompts.interval * Double(slot),
                                 hasCompany: true)
        }
        XCTAssertTrue(slots.contains(AudiencePrompts.primary),
                      "with the commands off, this line is the only thing telling anyone what to type")
    }

    func testMotionChoicesSurviveSavingAndReloading() throws {
        let store = StateStore(baseDirectory: try temporaryDirectory())
        for mode in StreamMotion.allCases {
            var config = AppConfig()
            config.stream.motion = mode
            config.stream.goal = "A goal worth keeping"
            try store.saveConfig(config)
            let loaded = store.loadConfig()
            XCTAssertEqual(loaded.stream.motion, mode)
            XCTAssertEqual(loaded.stream.goal, config.stream.goal)
        }
    }

    func testBlockNumberCountsUpAcrossBlocksAndSurvivesTheBreak() throws {
        let directory = try temporaryDirectory()
        let stateStore = StateStore(baseDirectory: directory)
        let engine = TimerEngine(stateStore: stateStore,
                                 historyStore: SessionHistoryStore(baseDirectory: directory),
                                 notificationService: NoopNotificationService(),
                                 clock: { Date(timeIntervalSince1970: 1_000) })

        engine.startFocus(focusMinutes: 1, breakMinutes: 1, blockedAppsCount: 0, strictMode: false, cycle: 1)
        XCTAssertEqual(engine.snapshot.currentCycle, 1)

        // The break belongs to the block it follows, so it keeps that number.
        engine.refresh(now: Date(timeIntervalSince1970: 1_061))
        XCTAssertEqual(engine.snapshot.phase, .break)
        XCTAssertEqual(engine.snapshot.currentCycle, 1)
        XCTAssertEqual(stateStore.loadSessionState()?.currentCycle, 1)

        engine.refresh(now: Date(timeIntervalSince1970: 1_121))
        XCTAssertEqual(engine.snapshot.phase, .breakEnded)
        XCTAssertEqual(engine.snapshot.currentCycle, 1)

        engine.startFocus(focusMinutes: 1, breakMinutes: 1, blockedAppsCount: 0, strictMode: false,
                          cycle: engine.snapshot.currentCycle + 1)
        XCTAssertEqual(engine.snapshot.currentCycle, 2)
        // Persisted, so relaunching mid-stream does not restart the count.
        XCTAssertEqual(stateStore.loadSessionState()?.currentCycle, 2)
    }

    func testPresetsSetDurationsCategoryAndInvitationWithoutTouchingTheGoal() {
        var config = AppConfig()
        config.stream.goal = "Read chapter 3"

        let read = StreamPreset.all.first { $0.name == "Read with me" }!
        read.apply(to: &config)

        XCTAssertEqual(config.focusMinutes, 25)
        XCTAssertEqual(config.breakMinutes, 5)
        XCTAssertEqual(config.stream.category, "Reading")
        XCTAssertTrue(config.stream.categories.contains("Reading"))
        XCTAssertEqual(config.stream.plannedBlocks, 4)
        XCTAssertEqual(config.stream.invitation, read.invitation)
        XCTAssertEqual(config.stream.goal, "Read chapter 3")
        XCTAssertTrue(read.matches(config))

        // Applying a second preset must not accumulate duplicate categories.
        read.apply(to: &config)
        XCTAssertEqual(config.stream.categories.filter { $0 == "Reading" }.count, 1)

        let deep = StreamPreset.all.first { $0.name == "Deep work" }!
        deep.apply(to: &config)
        XCTAssertEqual(config.focusMinutes, 90)
        XCTAssertFalse(read.matches(config))
        XCTAssertTrue(deep.matches(config))
    }

    // MARK: - Surviving a quit

    func testAStreamRunSurvivesAQuitWithItsWallAndItsStartTime() throws {
        let store = StateStore(baseDirectory: try temporaryDirectory())
        XCTAssertNil(store.loadStreamRun(), "nothing has run yet")

        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        var roster = AudienceRoster(autoApprove: true, now: startedAt)
        roster.submit(name: "maya", text: "read chapter 3", now: startedAt)
        roster.markDone(name: "maya")
        roster.submit(name: "tomas", text: "rewrite my CV", now: startedAt)

        try store.saveStreamRun(StreamRunState(startedAt: startedAt, roster: roster))

        let restored = try XCTUnwrap(store.loadStreamRun())
        XCTAssertEqual(restored.startedAt, startedAt,
                       "without this the recap has no run to measure and comes back empty")
        XCTAssertEqual(restored.roster.admitted.map(\.text), ["read chapter 3", "rewrite my CV"])
        XCTAssertEqual(restored.roster.tally.label, "1/2")
    }

    func testAHalfWrittenRunIsKeptAsideRatherThanCrashingTheApp() throws {
        let directory = try temporaryDirectory()
        let store = StateStore(baseDirectory: directory)
        try store.prepareDirectory()
        try Data("{ not json at all".utf8).write(to: store.streamRunURL)

        XCTAssertNil(store.loadStreamRun())
        let kept = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasPrefix("stream-run.json.invalid-") }
        XCTAssertEqual(kept.count, 1, "the only record of an hour's work is worth a copy")
    }

    func testAnEmptyRunFileStillYieldsAUsableRun() throws {
        let store = StateStore(baseDirectory: try temporaryDirectory())
        try store.prepareDirectory()
        try Data("{}".utf8).write(to: store.streamRunURL)

        let restored = try XCTUnwrap(store.loadStreamRun())
        XCTAssertTrue(restored.roster.isEmpty)
        XCTAssertTrue(restored.roster.tally.isEmpty)
    }

    // MARK: - Recap

    func testTheRecapCarriesWhatTheRoomGotThroughNotJustTheHost() {
        var roster = AudienceRoster(autoApprove: true, now: .distantPast)
        for index in 0..<5 {
            roster.submit(name: "viewer\(index)", text: "task \(index)", now: .distantPast)
        }
        roster.markDone(name: "viewer0")
        roster.markDone(name: "viewer1")

        let recap = StreamRecap(blocks: 3, focusMinutes: 150, categories: [], goalsCompleted: 1,
                                companions: roster.peopleCount, tally: roster.tally)
        XCTAssertTrue(recap.detailLines.contains("2 of 5 tasks finished between us"))
        XCTAssertTrue(recap.text.contains("2 of 5 tasks finished between us"),
                      "the copied recap is the one that gets posted, so it needs the number too")
    }

    func testARecapWithNothingFinishedDoesNotAdvertiseAZero() {
        let recap = StreamRecap(blocks: 2, focusMinutes: 100, categories: [], goalsCompleted: 0,
                                companions: 4, tally: AudienceTally())
        XCTAssertFalse(recap.detailLines.contains { $0.contains("tasks finished") })
    }

    // MARK: - Music

    func testEveryShippedMusicSourceOpens() {
        XCTAssertFalse(StreamMusicSource.all.isEmpty)
        for source in StreamMusicSource.all {
            var settings = StreamSettings()
            settings.playlistURL = source.link
            XCTAssertNotNil(settings.playlistDestination,
                            "\(source.name) is on the page, so its link has to survive the scheme check")
            XCTAssertEqual(source.url?.scheme, "https",
                           "\(source.name) sends a host to a browser; plain http is not good enough for that")
            XCTAssertFalse(source.sound.isEmpty)
            XCTAssertFalse(source.terms.isEmpty,
                           "\(source.name) without its condition is the half of the advice that gets people muted")
        }
    }

    func testMusicSourcesAreDistinctAndLofiLeads() {
        XCTAssertEqual(Set(StreamMusicSource.all.map(\.id)).count, StreamMusicSource.all.count)
        XCTAssertEqual(Set(StreamMusicSource.all.map(\.link)).count, StreamMusicSource.all.count)
        XCTAssertTrue(StreamMusicSource.all[0].sound.lowercased().contains("lofi"),
                      "a co-working room reaches for lofi first")
    }

    func testGuardedAppsThatWouldBreakTheStreamAreFlagged() {
        let apps = [
            BlockedApp(name: "OBS", bundleId: "com.obsproject.obs-studio"),
            BlockedApp(name: "Streamlabs", bundleId: "com.streamlabs.slobs"),
            BlockedApp(name: "Chrome", bundleId: "com.google.Chrome"),
            BlockedApp(name: "Discord", bundleId: "com.hnc.Discord"),
            BlockedApp(name: "Spotify", bundleId: "com.spotify.client"),
            BlockedApp(name: "Slack", bundleId: "com.tinyspeck.slackmacgap"),
            BlockedApp(name: "OBS spare", bundleId: "com.obsproject.obs-studio2", isEnabled: false)
        ]

        let hazards = StreamHazard.hazards(in: apps)
        XCTAssertEqual(hazards.map(\.app.name), ["OBS", "Streamlabs"])
        XCTAssertEqual(hazards.map(\.role), [.broadcast, .broadcast])

        // Guarding a browser, Discord, or a music player during a focus block
        // is what this app is for. Warning about them would teach the host to
        // scroll past the one warning that matters.
        for ordinary in ["Chrome", "Discord", "Spotify", "Slack"] {
            XCTAssertFalse(hazards.contains { $0.app.name == ordinary }, ordinary)
        }
        // An entry toggled off is already harmless.
        XCTAssertFalse(hazards.contains { $0.app.name == "OBS spare" })
        XCTAssertTrue(StreamHazard.hazards(in: []).isEmpty)
    }

    func testPlaylistOnlyOpensMusicAndWebSchemes() {
        var settings = StreamSettings()
        XCTAssertNil(settings.playlistDestination)

        settings.playlistURL = "  https://open.spotify.com/playlist/abc  "
        XCTAssertEqual(settings.playlistDestination?.host, "open.spotify.com")

        settings.playlistURL = "spotify:playlist:abc"
        XCTAssertNotNil(settings.playlistDestination)

        for hostile in ["file:///Users/me/secret", "ssh://box", "x-apple-systempreferences://x", "not a url at all"] {
            settings.playlistURL = hostile
            XCTAssertNil(settings.playlistDestination, "should refuse \(hostile)")
        }
    }

    func testRecapCoversOnlyTheCurrentRun() {
        let runStart = Date(timeIntervalSince1970: 10_000)
        func block(_ category: String, minutes: Int, at offset: TimeInterval, done: Bool = false) -> SessionHistoryEntry {
            SessionHistoryEntry(startedAt: runStart.addingTimeInterval(offset),
                                endedAt: runStart.addingTimeInterval(offset + 60),
                                focusMinutes: minutes, breakMinutes: 5, status: .completed,
                                blockedAppsCount: 0, strictMode: false,
                                task: SessionTask(goal: "g", category: category, shared: true),
                                checkIn: done ? SessionCheckIn(outcome: .done, note: "") : nil)
        }

        let history = [
            block("Coding", minutes: 50, at: 0, done: true),
            block("Coding", minutes: 50, at: 3_600),
            block("Writing", minutes: 25, at: 7_200, done: true),
            // Yesterday's stream must not be counted into tonight's recap.
            block("Study", minutes: 90, at: -86_400)
        ]

        let recap = StreamRecap.make(from: history, since: runStart, companions: 7)
        XCTAssertEqual(recap.blocks, 3)
        XCTAssertEqual(recap.focusMinutes, 125)
        XCTAssertEqual(recap.categories.map(\.name), ["Coding", "Writing"])
        XCTAssertEqual(recap.categories.first?.minutes, 100)
        XCTAssertEqual(recap.goalsCompleted, 2)
        XCTAssertEqual(recap.headline, "3 blocks · 2h 5m · Coding")
        XCTAssertTrue(recap.text.contains("2 goals finished"))
        XCTAssertTrue(recap.text.contains("7 people worked alongside"))
        XCTAssertFalse(recap.text.contains("Study"))

        // The end card sizes the headline and the detail differently, so it
        // needs them apart rather than as one block of text.
        XCTAssertEqual(recap.detailLines,
                       ["Coding 1h 40m · Writing 25m", "2 goals finished", "7 people worked alongside"])
        XCTAssertEqual(([recap.headline] + recap.detailLines).joined(separator: "\n"), recap.text)
    }

    func testRecapIsEmptyBeforeAnythingIsFinished() {
        let recap = StreamRecap.make(from: [], since: Date())
        XCTAssertTrue(recap.isEmpty)
        // A single block reads in the singular, and a lone category is not
        // repeated on a second line.
        let one = StreamRecap.make(from: [
            SessionHistoryEntry(startedAt: Date(), endedAt: Date(), focusMinutes: 25, breakMinutes: 5,
                                status: .completed, blockedAppsCount: 0, strictMode: false,
                                task: SessionTask(goal: "", category: "Reading", shared: true))
        ], since: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(one.headline, "1 block · 25m · Reading")
        XCTAssertEqual(one.text, "1 block · 25m · Reading")
        XCTAssertTrue(one.detailLines.isEmpty, "a lone category should not repeat under itself")
    }

    func testPlannedBlocksStayInRangeWhenDecoded() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let wild = #"{"stream":{"plannedBlocks":900}}"#
        XCTAssertEqual(try decoder.decode(AppConfig.self, from: Data(wild.utf8)).stream.plannedBlocks, 12)
        let zero = #"{"stream":{"plannedBlocks":0}}"#
        XCTAssertEqual(try decoder.decode(AppConfig.self, from: Data(zero.utf8)).stream.plannedBlocks, 1)
    }
}
