import FocusLockCore
import XCTest

final class TimerEndSoundTests: XCTestCase {
    func testOnlyARunOutTimerCounts() {
        XCTAssertTrue(TimerEndSound.timerRanOut(from: .focus, to: .break))
        XCTAssertTrue(TimerEndSound.timerRanOut(from: .focus, to: .completed))
        XCTAssertTrue(TimerEndSound.timerRanOut(from: .break, to: .breakEnded))

        // Starting, stopping, and restoring after a relaunch are not endings.
        XCTAssertFalse(TimerEndSound.timerRanOut(from: .idle, to: .focus))
        XCTAssertFalse(TimerEndSound.timerRanOut(from: .breakEnded, to: .focus))
        XCTAssertFalse(TimerEndSound.timerRanOut(from: .focus, to: .cancelled))
        XCTAssertFalse(TimerEndSound.timerRanOut(from: .idle, to: .break))
        XCTAssertFalse(TimerEndSound.timerRanOut(from: .focus, to: .focus))
    }

    func testEverySoundButOffIsARealSystemSound() {
        XCTAssertNil(TimerEndSound.off.systemSoundName)
        for sound in TimerEndSound.allCases where sound != .off {
            let name = try! XCTUnwrap(sound.systemSoundName)
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: "/System/Library/Sounds/\(name).aiff"),
                "\(name) is not a macOS system sound"
            )
        }
    }

    func testSoundDefaultsOnForExistingConfigs() throws {
        let json = Data(#"{"focusMinutes":25,"breakMinutes":5}"#.utf8)
        let config = try JSONDecoder().decode(AppConfig.self, from: json)
        XCTAssertEqual(config.timerEndSound, .glass)
    }

    func testSoundChoiceSurvivesARoundTrip() throws {
        var config = AppConfig()
        config.timerEndSound = .off
        let decoded = try JSONDecoder().decode(AppConfig.self, from: JSONEncoder().encode(config))
        XCTAssertEqual(decoded.timerEndSound, .off)
    }

}
