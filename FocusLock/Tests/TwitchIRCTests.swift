import FocusLockCore
import XCTest

final class TwitchIRCTests: XCTestCase {
    func testPlainMessageUsesTheLoginWhenThereAreNoTags() {
        let line = ":maya!maya@maya.tmi.twitch.tv PRIVMSG #piping16 :!task read chapter 3"
        XCTAssertEqual(TwitchIRC.parse(line),
                       .message(TwitchChatMessage(name: "maya", text: "!task read chapter 3")))
    }

    func testDisplayNameWinsSoPeopleAppearAsTheyChoseToBeCalled() {
        let line = "@badge-info=;color=#FF0000;display-name=MayaB;user-id=1 :mayab!mayab@mayab.tmi.twitch.tv PRIVMSG #piping16 :!task thesis intro"
        XCTAssertEqual(TwitchIRC.parse(line),
                       .message(TwitchChatMessage(name: "MayaB", text: "!task thesis intro")))
    }

    func testTagEscapesSurviveSoNamesWithSpacesArrangeIntact() {
        let line = "@display-name=Maya\\sB. :maya!maya@maya.tmi.twitch.tv PRIVMSG #c :hello"
        guard case .message(let message) = TwitchIRC.parse(line) else { return XCTFail("expected a message") }
        XCTAssertEqual(message.name, "Maya B.")
    }

    func testAnEmptyDisplayNameTagFallsBackRatherThanShowingNobody() {
        let line = "@display-name= :maya!maya@maya.tmi.twitch.tv PRIVMSG #c :hi"
        guard case .message(let message) = TwitchIRC.parse(line) else { return XCTFail("expected a message") }
        XCTAssertEqual(message.name, "maya")
    }

    func testMessagesKeepColonsAndSpacesOfTheirOwn() {
        let line = ":kai!kai@kai.tmi.twitch.tv PRIVMSG #c :!task 3:30 — read: chapter 4"
        guard case .message(let message) = TwitchIRC.parse(line) else { return XCTFail("expected a message") }
        XCTAssertEqual(message.text, "!task 3:30 — read: chapter 4")
    }

    func testPingIsRecognisedBecauseIgnoringItEndsTheConnection() {
        XCTAssertEqual(TwitchIRC.parse("PING :tmi.twitch.tv"), .ping("tmi.twitch.tv"))
    }

    func testHousekeepingLinesAreNotMistakenForChat() {
        XCTAssertEqual(TwitchIRC.parse(":tmi.twitch.tv 001 justinfan1 :Welcome, GLHF!"), .welcomed)
        XCTAssertEqual(TwitchIRC.parse(":justinfan1!justinfan1@justinfan1.tmi.twitch.tv JOIN #piping16"), .other)
        XCTAssertEqual(TwitchIRC.parse(":tmi.twitch.tv 353 justinfan1 = #piping16 :justinfan1"), .other)
        XCTAssertEqual(TwitchIRC.parse(""), .other)
        XCTAssertEqual(TwitchIRC.parse("@only-tags-and-nothing-else"), .other)
        guard case .notice = TwitchIRC.parse(":tmi.twitch.tv NOTICE * :Improperly formatted auth") else {
            return XCTFail("expected a notice")
        }
    }

    func testOneFrameCanCarrySeveralLines() {
        let frame = "PING :tmi.twitch.tv\r\n:a!a@a.tmi.twitch.tv PRIVMSG #c :first\r\n:b!b@b.tmi.twitch.tv PRIVMSG #c :second\r\n"
        let events = TwitchIRC.events(in: frame)
        XCTAssertEqual(events.count, 3)
        XCTAssertEqual(events.first, .ping("tmi.twitch.tv"))
        guard case .message(let last) = events.last else { return XCTFail("expected a message") }
        XCTAssertEqual(last.text, "second")
    }

    /// The whole path a stranger's words travel, from the wire to the screen.
    func testARawChatLineTravelsAllTheWayToTheWallOrIsStopped() {
        var roster = AudienceRoster(autoApprove: true)
        roster.blockedTerms = ["badword"]

        func feed(_ line: String) {
            guard case .message(let chat) = TwitchIRC.parse(line),
                  let command = AudienceCommand.parse(chat.text) else { return }
            roster.apply(command, from: chat.name)
        }

        feed("@display-name=Maya :maya!maya@maya.tmi.twitch.tv PRIVMSG #piping16 :!task read chapter 3")
        XCTAssertEqual(roster.admitted.map(\.name), ["Maya"])
        XCTAssertEqual(roster.admitted.first?.text, "read chapter 3")

        // Ordinary chat is not a command and must not put anyone on screen.
        feed(":tom!tom@tom.tmi.twitch.tv PRIVMSG #piping16 :good luck everyone")
        XCTAssertEqual(roster.admitted.count, 1)

        // The rules apply no matter what carried the words here.
        feed(":spam!spam@spam.tmi.twitch.tv PRIVMSG #piping16 :!task follow twitch.tv/me")
        feed(":rude!rude@rude.tmi.twitch.tv PRIVMSG #piping16 :!task b4dw0rd")
        XCTAssertEqual(roster.admitted.count, 1)

        feed("@display-name=Maya :maya!maya@maya.tmi.twitch.tv PRIVMSG #piping16 :!done")
        XCTAssertTrue(roster.admitted[0].isDone)
    }

    func testChannelNamesAreAcceptedInEveryShapeAHostMightPasteThem() {
        for input in ["Piping16", "  piping16 ", "#piping16", "twitch.tv/Piping16",
                      "https://www.twitch.tv/piping16", "https://twitch.tv/piping16/about?x=1"] {
            XCTAssertEqual(TwitchIRC.normalizeChannel(input), "piping16", input)
        }
        for bad in ["", "ab", "has space", "bad!chars", String(repeating: "a", count: 26)] {
            XCTAssertNil(TwitchIRC.normalizeChannel(bad), bad)
        }
    }
}
