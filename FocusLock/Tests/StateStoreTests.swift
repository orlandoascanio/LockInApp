import FocusLockCore
import XCTest

final class StateStoreTests: XCTestCase {
    func testSaveAndLoadConfig() throws {
        let directory = try temporaryDirectory()
        let store = StateStore(baseDirectory: directory)
        let config = AppConfig(
            focusMinutes: 45,
            breakMinutes: 10,
            blockerMode: .hideOnly,
            blockedApps: [BlockedApp(name: "Slack", bundleId: "com.tinyspeck.slackmacgap")],
            blockedSites: [BlockedSite(pattern: "youtube.com")],
            strict: StrictModeSettings(enabled: true),
            schedules: [FocusSchedule(strict: true)]
        )

        try store.saveConfig(config)

        XCTAssertEqual(store.loadConfig(), config)
    }

    func testBlockedAppsPersistInConfig() throws {
        let directory = try temporaryDirectory()
        let store = StateStore(baseDirectory: directory)
        let blockedApps = [
            BlockedApp(name: "Discord", bundleId: "com.hnc.Discord"),
            BlockedApp(name: "Slack", bundleId: "com.tinyspeck.slackmacgap")
        ]

        try store.saveConfig(AppConfig(blockedApps: blockedApps))

        let loaded = store.loadConfig()

        XCTAssertEqual(loaded.blockedApps, blockedApps)
    }

    func testLoadConfigCreatesDefaultWhenMissing() throws {
        let directory = try temporaryDirectory()
        let store = StateStore(baseDirectory: directory)

        let config = store.loadConfig()

        XCTAssertEqual(config, .default)
        XCTAssertEqual(config.blockerMode, .guardScreen)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.configURL.path))

        let data = try Data(contentsOf: store.configURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["blockerMode"] as? String, "guard")
        XCTAssertNil(json?["strictMode"])
    }

    func testLegacyStrictModeConfigMigratesToHideOnly() throws {
        let directory = try temporaryDirectory()
        let store = StateStore(baseDirectory: directory)
        try store.prepareDirectory()
        try Data("""
        {
          "focusMinutes": 25,
          "breakMinutes": 5,
          "strictMode": true,
          "autoStartFocusAfterBreak": false,
          "blockedApps": []
        }
        """.utf8).write(to: store.configURL)

        let config = store.loadConfig()

        XCTAssertEqual(config.blockerMode, .hideOnly)

        let data = try Data(contentsOf: store.configURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["blockerMode"] as? String, "hideOnly")
        XCTAssertNil(json?["strictMode"])
    }

    func testInvalidConfigJSONRecoversSafely() throws {
        let directory = try temporaryDirectory()
        let store = StateStore(baseDirectory: directory)
        try store.prepareDirectory()
        try Data("{not-json".utf8).write(to: store.configURL)

        let config = store.loadConfig()
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)

        XCTAssertEqual(config, .default)
        XCTAssertTrue(files.contains { $0.hasPrefix("config.json.invalid-") })
    }

    func testSessionStateSaveLoadAndClear() throws {
        let directory = try temporaryDirectory()
        let store = StateStore(baseDirectory: directory)
        let state = SessionState(
            state: .focus,
            startedAt: Date(timeIntervalSince1970: 100),
            focusMinutes: 25,
            breakMinutes: 5,
            currentCycle: 1,
            blockedAppsCount: 4,
            strictMode: true
        )

        try store.saveSessionState(state)

        XCTAssertEqual(store.loadSessionState(), state)

        try store.clearSessionState()

        XCTAssertNil(store.loadSessionState())
    }
}
