import Foundation

/// Reads a Twitch channel's chat, anonymously.
///
/// Twitch accepts a read-only connection from any nick beginning `justinfan`
/// with no password, which is why this needs no account, no OAuth app, and no
/// API key from the host. Nothing is ever sent to the channel: the client
/// speaks only the handshake and the PONG that keeps it alive.
public final class TwitchChatClient {
    public enum State: Equatable {
        case idle
        case connecting
        case connected(channel: String)
        case reconnecting(attempt: Int)
        case failed(String)

        public var isLive: Bool {
            if case .connected = self { return true }
            return false
        }

        public var summary: String {
            switch self {
            case .idle: return "Not connected"
            case .connecting: return "Connecting…"
            case .connected(let channel): return "Reading #\(channel)"
            case .reconnecting(let attempt): return "Connection lost — retrying (\(attempt))"
            case .failed(let reason): return reason
            }
        }
    }

    public static let endpoint = URL(string: "wss://irc-ws.chat.twitch.tv:443")!

    /// Caps the backoff. A stream runs for hours, so retrying forever at a
    /// sane interval is better than giving up on a host who is mid-session.
    public static let maximumRetryDelay: TimeInterval = 60

    public private(set) var state: State = .idle {
        didSet {
            guard state != oldValue else { return }
            let state = state
            deliver { self.onState?(state) }
        }
    }

    public var onMessage: ((TwitchChatMessage) -> Void)?
    public var onState: ((State) -> Void)?

    private let session: URLSession
    private var task: URLSessionWebSocketTask?
    private var channel: String?
    private var attempt = 0

    /// Distinguishes a dropped connection, which should come back, from the
    /// host switching it off, which should not.
    private var wantsConnection = false

    public init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Connecting

    /// Returns false when the channel is not a name Twitch could have.
    @discardableResult
    public func connect(channel rawChannel: String) -> Bool {
        guard let channel = TwitchIRC.normalizeChannel(rawChannel) else {
            state = .failed("That is not a Twitch channel name.")
            return false
        }

        self.channel = channel
        wantsConnection = true
        attempt = 0
        openSocket()
        return true
    }

    public func disconnect() {
        wantsConnection = false
        closeSocket()
        state = .idle
    }

    private func openSocket() {
        guard let channel else { return }
        closeSocket()

        if case .reconnecting = state {} else {
            state = .connecting
        }

        let task = session.webSocketTask(with: Self.endpoint)
        self.task = task
        task.resume()

        // Tags carry the display name, so people appear on the wall as they
        // chose to be called rather than as a lowercase login.
        send("CAP REQ :twitch.tv/tags")
        send("NICK justinfan\(Int.random(in: 10_000...99_999))")
        send("JOIN #\(channel)")

        listen()
    }

    private func closeSocket() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    private func send(_ line: String) {
        task?.send(.string(line + "\r\n")) { _ in }
    }

    // MARK: - Reading

    private func listen() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                self.handleDrop(error)
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handle(frame: text)
                case .data(let data):
                    self.handle(frame: String(decoding: data, as: UTF8.self))
                @unknown default:
                    break
                }
                self.listen()
            }
        }
    }

    private func handle(frame: String) {
        for event in TwitchIRC.events(in: frame) {
            switch event {
            case .ping(let payload):
                // Unanswered, the server closes the connection within minutes.
                send("PONG :\(payload)")
            case .welcomed:
                attempt = 0
                if let channel {
                    state = .connected(channel: channel)
                }
            case .message(let message):
                deliver { self.onMessage?(message) }
            case .notice, .other:
                break
            }
        }
    }

    private func handleDrop(_ error: Error) {
        task = nil
        guard wantsConnection else { return }

        attempt += 1
        state = .reconnecting(attempt: attempt)

        let delay = min(Self.maximumRetryDelay, pow(2, Double(min(attempt, 6))))
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.wantsConnection else { return }
            self.openSocket()
        }
    }

    /// Callbacks land on the main queue: everything downstream of here is UI.
    private func deliver(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
}
