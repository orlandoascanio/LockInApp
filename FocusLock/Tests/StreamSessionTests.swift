import FocusLockCore
import XCTest

final class StreamSessionTests: XCTestCase {
    func testCSVKeepsFormulaLikeGoalsAsText() {
        let entry = SessionHistoryEntry(startedAt: Date(), endedAt: Date(), focusMinutes: 1,
                                        breakMinutes: 1, status: .completed, blockedAppsCount: 0,
                                        strictMode: false,
                                        task: SessionTask(goal: "=1+1", category: "Work", shared: true),
                                        checkIn: SessionCheckIn(outcome: .done, note: "@example"))
        let csv = ExportService().csvString(from: [entry])
        XCTAssertTrue(csv.contains("'=1+1"))
        XCTAssertTrue(csv.contains("'@example"))
    }

    func testLegacyDataLoadsWithoutTaskMetadata() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let config = try decoder.decode(AppConfig.self, from: Data("{\"focusMinutes\":25}".utf8))
        XCTAssertFalse(config.stream.enabled)
        XCTAssertEqual(config.stream.categories.count, 5)
        let oldState = #"{"state":"focus","startedAt":"2026-09-09T10:00:00Z","focusMinutes":25,"breakMinutes":5}"#
        XCTAssertNil(try decoder.decode(SessionState.self, from: Data(oldState.utf8)).task)
        let oldEntry = #"{"id":"00000000-0000-0000-0000-000000000123","startedAt":"2026-09-09T10:00:00Z","endedAt":"2026-09-09T10:25:00Z","focusMinutes":25,"breakMinutes":5,"status":"completed","blockedAppsCount":0,"strictMode":false}"#
        let entry = try decoder.decode(SessionHistoryEntry.self, from: Data(oldEntry.utf8))
        XCTAssertNil(entry.task)
        XCTAssertNil(entry.checkIn)
    }

    func testCategoriesNormalizeAndPersistWithoutDuplicates() throws {
        var settings = StreamSettings()
        XCTAssertFalse(settings.addCategory("  \n"))
        XCTAssertTrue(settings.addCategory("  Music  "))
        XCTAssertTrue(settings.addCategory("music"))
        XCTAssertEqual(settings.categories.filter { $0.lowercased() == "music" }.count, 1)
        XCTAssertEqual(settings.category, "Music")
        settings.goal = "Learn a song"
        settings.enabled = true
        let store = StateStore(baseDirectory: try temporaryDirectory())
        try store.saveConfig(AppConfig(stream: settings))
        XCTAssertEqual(store.loadConfig().stream, settings)
    }

    func testTaskSnapshotSurvivesFocusBreakAndCheckInUpdate() throws {
        let directory = try temporaryDirectory()
        let stateStore = StateStore(baseDirectory: directory)
        let historyStore = SessionHistoryStore(baseDirectory: directory)
        let start = Date(timeIntervalSince1970: 1_000)
        let engine = TimerEngine(stateStore: stateStore, historyStore: historyStore,
                                 notificationService: NoopNotificationService(), clock: { start })
        var draft = StreamSettings()
        draft.goal = "Finish the intro"
        draft.enabled = true
        let task = draft.task
        engine.startFocus(focusMinutes: 1, breakMinutes: 1, blockedAppsCount: 0, strictMode: false, task: task)
        draft.goal = "Next task"
        XCTAssertEqual(stateStore.loadSessionState()?.task?.goal, "Finish the intro")
        XCTAssertEqual(engine.snapshot.task, task)
        engine.refresh(now: start.addingTimeInterval(61))
        XCTAssertEqual(engine.snapshot.phase, .break)
        XCTAssertEqual(engine.snapshot.task, task)
        XCTAssertEqual(historyStore.loadHistory().first?.task, task)
        let checkIn = SessionCheckIn(outcome: .progress, note: "Next: add examples")
        try historyStore.saveCheckIn(taskID: task.id, checkIn: checkIn)
        try historyStore.saveCheckIn(taskID: task.id, checkIn: SessionCheckIn(outcome: .done, note: "Finished"))
        engine.refresh(now: start.addingTimeInterval(121))
        XCTAssertEqual(engine.snapshot.phase, .breakEnded)
        XCTAssertEqual(engine.snapshot.task, task)
        XCTAssertEqual(historyStore.loadHistory().count, 1)
        XCTAssertEqual(historyStore.loadHistory().first?.checkIn?.outcome, .done)
    }

    func testCancelledAndAbandonedTasksRetainMetadata() throws {
        for abandon in [false, true] {
            let directory = try temporaryDirectory()
            let history = SessionHistoryStore(baseDirectory: directory)
            let start = Date(timeIntervalSince1970: 2_000)
            let engine = TimerEngine(stateStore: StateStore(baseDirectory: directory), historyStore: history,
                                     notificationService: NoopNotificationService(), clock: { start })
            let task = SessionTask(goal: "Write", category: "Work", shared: true)
            engine.startFocus(focusMinutes: 25, breakMinutes: 5, blockedAppsCount: 0, strictMode: false, task: task)
            if abandon { engine.recordAbandonmentIfNeeded(now: start.addingTimeInterval(70)) }
            else { engine.stopSession(now: start.addingTimeInterval(70)) }
            XCTAssertEqual(history.loadHistory().first?.task, task)
            XCTAssertEqual(history.loadHistory().first?.status, abandon ? .abandoned : .cancelled)
        }
    }

    func testNoBreakCompletionRetainsTaskAndExportsCheckIn() throws {
        let directory = try temporaryDirectory()
        let history = SessionHistoryStore(baseDirectory: directory)
        let start = Date(timeIntervalSince1970: 3_000)
        let engine = TimerEngine(stateStore: StateStore(baseDirectory: directory), historyStore: history,
                                 notificationService: NoopNotificationService(), clock: { start })
        let task = SessionTask(goal: "Write, then revise", category: "Writing", shared: true)
        engine.startFocus(focusMinutes: 1, breakMinutes: 0, blockedAppsCount: 0, strictMode: false, task: task)
        engine.refresh(now: start.addingTimeInterval(60))
        XCTAssertEqual(engine.snapshot.phase, .completed)
        XCTAssertEqual(engine.snapshot.task, task)
        try history.saveCheckIn(taskID: task.id, checkIn: SessionCheckIn(outcome: .done, note: "A \"win\"\nfor today"))
        let export = ExportService()
        let csv = export.csvString(from: history.loadHistory())
        XCTAssertTrue(csv.contains("\"Write, then revise\""))
        XCTAssertTrue(csv.contains("\"A \"\"win\"\"\nfor today\""))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        XCTAssertEqual(try decoder.decode([SessionHistoryEntry].self, from: export.jsonData(from: history.loadHistory())), history.loadHistory())
    }

    func testStreamSettingsSurviveMissingAndUnknownFields() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // A settings file written before a field existed must not fail the
        // whole config decode and reset the app to defaults.
        let partial = #"{"focusMinutes":25,"blockedApps":[],"stream":{"enabled":true,"goal":"Read"}}"#
        let config = try decoder.decode(AppConfig.self, from: Data(partial.utf8))
        XCTAssertTrue(config.stream.enabled)
        XCTAssertEqual(config.stream.goal, "Read")
        XCTAssertEqual(config.stream.category, "Study")
        XCTAssertEqual(config.stream.categories, StreamSettings().categories)
        XCTAssertTrue(config.stream.showGoal)
        XCTAssertEqual(config.focusMinutes, 25)

        // A file from a newer build carrying fields this one does not know.
        let newer = #"{"stream":{"enabled":false,"goal":"","category":"Study","categories":["Study"],"darkAppearance":true,"showGoal":true,"showRoster":true}}"#
        XCTAssertEqual(try decoder.decode(AppConfig.self, from: Data(newer.utf8)).stream.categories, ["Study"])

        // A category outside its own list would render as a blank picker.
        let orphaned = #"{"stream":{"category":"Gone","categories":["Study","Coding"]}}"#
        XCTAssertEqual(try decoder.decode(AppConfig.self, from: Data(orphaned.utf8)).stream.category, "Study")
        let emptied = #"{"stream":{"categories":[]}}"#
        XCTAssertEqual(try decoder.decode(AppConfig.self, from: Data(emptied.utf8)).stream.categories.count, 5)
    }

    func testCompletedGoalClearsOnlyWhenItIsStillTheCurrentGoal() {
        var settings = StreamSettings()
        settings.goal = "Read chapter 3"
        let task = SessionTask(goal: "Read chapter 3", category: "Study", shared: true)

        XCTAssertFalse(settings.clearCompletedGoal(matching: task, outcome: .progress))
        XCTAssertFalse(settings.clearCompletedGoal(matching: task, outcome: .stuck))
        XCTAssertFalse(settings.clearCompletedGoal(matching: nil, outcome: .done))
        XCTAssertEqual(settings.goal, "Read chapter 3")

        // A goal rewritten mid-block belongs to the next block, not this one.
        var rewritten = settings
        rewritten.goal = "Read chapter 4"
        XCTAssertFalse(rewritten.clearCompletedGoal(matching: task, outcome: .done))
        XCTAssertEqual(rewritten.goal, "Read chapter 4")

        XCTAssertTrue(settings.clearCompletedGoal(matching: task, outcome: .done))
        XCTAssertTrue(settings.goal.isEmpty)
        XCTAssertFalse(settings.clearCompletedGoal(matching: task, outcome: .done))
    }

    func testStatsCanBeScopedToOneCategory() {
        let now = Date()
        func entry(_ category: String?, minutes: Int) -> SessionHistoryEntry {
            SessionHistoryEntry(startedAt: now, endedAt: now, focusMinutes: minutes,
                                breakMinutes: 0, status: .completed, blockedAppsCount: 0,
                                strictMode: false,
                                task: category.map { SessionTask(goal: "", category: $0, shared: false) })
        }
        let history = [entry("Coding", minutes: 50), entry("Study", minutes: 25), entry(nil, minutes: 10)]

        XCTAssertEqual(SessionStats.make(from: history, referenceDate: now).focusMinutesToday, 85)
        let coding = SessionStats.make(from: history.filter { $0.task?.category == "Coding" }, referenceDate: now)
        XCTAssertEqual(coding.focusMinutesToday, 50)
        XCTAssertEqual(coding.sessionsCompletedToday, 1)
    }

    func testCheckInPreservesUnknownHistoryLinesAndRejectsMissingTask() throws {
        let history = SessionHistoryStore(baseDirectory: try temporaryDirectory())
        let task = SessionTask(goal: "Read", category: "Study", shared: true)
        try history.append(SessionHistoryEntry(startedAt: Date(), endedAt: Date(), focusMinutes: 1,
                                               breakMinutes: 1, status: .completed, blockedAppsCount: 0,
                                               strictMode: false, task: task))
        var content = try String(contentsOf: history.historyURL)
        content += "unrecognized record\n"
        try content.write(to: history.historyURL, atomically: true, encoding: .utf8)
        try history.saveCheckIn(taskID: task.id, checkIn: SessionCheckIn(outcome: .done, note: ""))
        XCTAssertTrue(try String(contentsOf: history.historyURL).contains("unrecognized record"))
        XCTAssertThrowsError(try history.saveCheckIn(taskID: UUID(), checkIn: SessionCheckIn(outcome: .stuck, note: "")))
    }
}
