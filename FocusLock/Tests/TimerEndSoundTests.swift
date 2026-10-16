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

    func testEveryMacOSSoundIsOffered() throws {
        let installed = try FileManager.default.contentsOfDirectory(atPath: "/System/Library/Sounds")
            .filter { $0.hasSuffix(".aiff") }
            .map { String($0.dropLast(5)) }
        let offered = Set(TimerEndSound.allCases.compactMap(\.systemSoundName))
        XCTAssertTrue(Set(installed).isSubset(of: offered), "Not offered: \(Set(installed).subtracting(offered))")
    }

    func testBreakSoundStartsAsTheSoundChosenBeforeItExisted() throws {
        let json = Data(#"{"focusMinutes":25,"breakMinutes":5,"timerEndSound":"submarine"}"#.utf8)
        let config = try JSONDecoder().decode(AppConfig.self, from: json)
        XCTAssertEqual(config.timerEndSound, .submarine)
        XCTAssertEqual(config.breakEndSound, .submarine)
    }

    func testFocusAndBreakSoundsAreKeptApart() throws {
        var config = AppConfig()
        config.timerEndSound = .tink
        config.breakEndSound = .off
        let decoded = try JSONDecoder().decode(AppConfig.self, from: JSONEncoder().encode(config))
        XCTAssertEqual(decoded.timerEndSound, .tink)
        XCTAssertEqual(decoded.breakEndSound, .off)
    }

}
