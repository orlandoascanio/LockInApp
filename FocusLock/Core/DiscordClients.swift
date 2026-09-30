import Darwin
import Foundation

/// Discord Rich Presence over the desktop app's local IPC socket. This is the
/// sanctioned way for an app to show an activity on your profile; changing
/// your custom status would need your account token, which Discord forbids.
public final class DiscordPresence {
    public struct Activity: Equatable {
        public var details: String
        public var state: String?
        public var endsAt: Date?

        public init(details: String, state: String? = nil, endsAt: Date? = nil) {
            self.details = details
            self.state = state
            self.endsAt = endsAt
        }
    }

    public enum Status: Equatable {
        case off
        case connected
        case discordNotRunning
        case failed(String)
    }

    public var onStatus: ((Status) -> Void)?

    private let queue = DispatchQueue(label: "com.lockin.discord-ipc")
    private var socketFD: Int32 = -1
    private var clientID = ""

    public init() {}

    deinit {
        close()
    }

    /// Replaces whatever LockIn was showing. `nil` clears it.
    public func update(_ activity: Activity?, clientID: String) {
        queue.async { [weak self] in
            self?.send(activity, clientID: clientID)
        }
    }

    public func disconnect() {
        queue.async { [weak self] in
            self?.close()
            self?.report(.off)
        }
    }

    // MARK: Protocol

    enum Opcode: UInt32 {
        case handshake = 0
        case frame = 1
        case close = 2
    }

    static func encodeFrame(opcode: Opcode, payload: [String: Any]) -> Data? {
        guard let json = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
        var data = Data()
        var op = opcode.rawValue.littleEndian
        var length = UInt32(json.count).littleEndian
        data.append(Data(bytes: &op, count: 4))
        data.append(Data(bytes: &length, count: 4))
        data.append(json)
        return data
    }

    static func activityPayload(_ activity: Activity?, pid: Int32) -> [String: Any] {
        var args: [String: Any] = ["pid": Int(pid)]
        if let activity {
            var body: [String: Any] = [
                "details": String(activity.details.prefix(128)),
                "assets": ["large_image": "lockin", "large_text": AppIdentity.name]
            ]
            if let state = activity.state, state.count >= 2 {
                body["state"] = String(state.prefix(128))
            }
            if let endsAt = activity.endsAt {
                body["timestamps"] = ["end": Int(endsAt.timeIntervalSince1970)]
            }
            args["activity"] = body
        } else {
            args["activity"] = NSNull()
        }
        return ["cmd": "SET_ACTIVITY", "args": args, "nonce": UUID().uuidString]
    }

    private func send(_ activity: Activity?, clientID: String) {
        if clientID != self.clientID {
            close()
            self.clientID = clientID
        }
        if socketFD < 0 {
            guard activity != nil else { return }
            guard connect() else { return }
        }

        guard
            let frame = Self.encodeFrame(opcode: .frame, payload: Self.activityPayload(activity, pid: getpid())),
            write(frame),
            readFrame() != nil
        else {
            // Discord restarted or the socket went stale: one fresh attempt.
            close()
            if activity != nil, connect(),
               let frame = Self.encodeFrame(opcode: .frame, payload: Self.activityPayload(activity, pid: getpid())),
               write(frame) {
                _ = readFrame()
            }
            return
        }
    }

    private func connect() -> Bool {
        for path in Self.candidateSocketPaths() {
            let fd = socket(AF_UNIX, SOCK_STREAM, 0)
            guard fd >= 0 else { continue }

            var timeout = timeval(tv_sec: 2, tv_usec: 0)
            setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
            setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
            var noSigPipe: Int32 = 1
            setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))

            var address = sockaddr_un()
            address.sun_family = sa_family_t(AF_UNIX)
            let bytes = Array(path.utf8.prefix(103)) + [0]
            withUnsafeMutableBytes(of: &address.sun_path) { buffer in
                buffer.copyBytes(from: bytes)
            }
            let connected = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
                }
            }
            guard connected == 0 else {
                Darwin.close(fd)
                continue
            }

            socketFD = fd
            guard
                let handshake = Self.encodeFrame(opcode: .handshake, payload: ["v": 1, "client_id": clientID]),
                write(handshake),
                let reply = readFrame(),
                reply.opcode == Opcode.frame.rawValue
            else {
                let reason = readableError(from: nil)
                close()
                report(.failed(reason))
                return false
            }
            report(.connected)
            return true
        }
        report(.discordNotRunning)
        return false
    }

    /// Discord puts `discord-ipc-0…9` in the per-user temporary folder.
    static func candidateSocketPaths() -> [String] {
        let bases = [ProcessInfo.processInfo.environment["TMPDIR"], NSTemporaryDirectory(), "/tmp/"]
            .compactMap { $0 }
        var seen = Set<String>()
        return bases.flatMap { base -> [String] in
            let root = base.hasSuffix("/") ? base : base + "/"
            return (0..<10).map { "\(root)discord-ipc-\($0)" }
        }
        .filter { seen.insert($0).inserted && FileManager.default.fileExists(atPath: $0) }
    }

    private func write(_ data: Data) -> Bool {
        guard socketFD >= 0 else { return false }
        return data.withUnsafeBytes { buffer -> Bool in
            var offset = 0
            while offset < buffer.count {
                let sent = Darwin.write(socketFD, buffer.baseAddress!.advanced(by: offset), buffer.count - offset)
                guard sent > 0 else { return false }
                offset += sent
            }
            return true
        }
    }

    private func readFrame() -> (opcode: UInt32, body: [String: Any])? {
        guard socketFD >= 0 else { return nil }
        var header = [UInt8](repeating: 0, count: 8)
        guard readExactly(&header, count: 8) else { return nil }
        let opcode = header[0..<4].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }.littleEndian
        let length = Int(header[4..<8].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }.littleEndian)
        guard length >= 0, length < 1_000_000 else { return nil }
        var body = [UInt8](repeating: 0, count: length)
        guard readExactly(&body, count: length) else { return nil }
        let json = (try? JSONSerialization.jsonObject(with: Data(body))) as? [String: Any] ?? [:]
        if opcode == Opcode.close.rawValue {
            report(.failed(json["message"] as? String ?? "Discord closed the connection."))
            return nil
        }
        return (opcode, json)
    }

    private func readExactly(_ buffer: inout [UInt8], count: Int) -> Bool {
        var offset = 0
        while offset < count {
            let received = buffer.withUnsafeMutableBytes {
                Darwin.read(socketFD, $0.baseAddress!.advanced(by: offset), count - offset)
            }
            guard received > 0 else { return false }
            offset += received
        }
        return true
    }

    private func readableError(from json: [String: Any]?) -> String {
        json?["message"] as? String ?? "Discord refused the connection. Check the Application ID."
    }

    private func close() {
        if socketFD >= 0 {
            Darwin.close(socketFD)
        }
        socketFD = -1
    }

    private func report(_ status: Status) {
        DispatchQueue.main.async { [weak self] in
            self?.onStatus?(status)
        }
    }
}

/// Posts a message to a Discord channel through a webhook link.
public enum DiscordWebhook {
    public enum WebhookError: LocalizedError {
        case invalidLink
        case rejected(Int)
        case transport(String)

        public var errorDescription: String? {
            switch self {
            case .invalidLink:
                return "That is not a Discord webhook link. It starts with https://discord.com/api/webhooks/."
            case .rejected(let status):
                return status == 404
                    ? "Discord no longer knows that webhook. It may have been deleted."
                    : "Discord refused the message (HTTP \(status))."
            case .transport(let message):
                return "Could not reach Discord: \(message)"
            }
        }
    }

    public static func isValidLink(_ text: String) -> Bool {
        guard
            let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
            url.scheme == "https",
            let host = url.host?.lowercased()
        else {
            return false
        }
        let knownHost = ["discord.com", "discordapp.com", "canary.discord.com", "ptb.discord.com"].contains(host)
        return knownHost && url.path.hasPrefix("/api/webhooks/")
    }

    static func request(link: String, content: String) throws -> URLRequest {
        guard isValidLink(link), let url = URL(string: link.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw WebhookError.invalidLink
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Mentions are switched off so a goal containing "@everyone" stays text.
        let body: [String: Any] = [
            "username": AppIdentity.name,
            "content": String(content.prefix(1_900)),
            "allowed_mentions": ["parse": [String]()]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    public static func post(_ content: String, to link: String, session: URLSession = .shared) async throws {
        let request = try request(link: link, content: content)
        let response: URLResponse
        do {
            (_, response) = try await session.data(for: request)
        } catch {
            throw WebhookError.transport(error.localizedDescription)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw WebhookError.rejected(status) }
    }
}
