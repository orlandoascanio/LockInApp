import Foundation

/// Sets your Slack status and pauses notifications while you focus, using a
/// user token (`xoxp-…`) from a Slack app you created with the
/// `users.profile:write` and `dnd:write` scopes.
public final class SlackClient {
    public enum SlackError: LocalizedError, Equatable {
        case missingToken
        case api(String)
        case transport(String)

        public var errorDescription: String? {
            switch self {
            case .missingToken:
                return "Add a Slack user token first."
            case .api(let code):
                return Self.explanation(for: code)
            case .transport(let message):
                return "Could not reach Slack: \(message)"
            }
        }

        private static func explanation(for code: String) -> String {
            switch code {
            case "invalid_auth", "not_authed", "token_revoked", "account_inactive":
                return "Slack did not accept that token. Paste a fresh user token (xoxp-…)."
            case "missing_scope":
                return "The token is missing a scope. Add users.profile:write and dnd:write, then reinstall the Slack app."
            case "ratelimited":
                return "Slack is rate limiting LockIn. It will try again on the next block."
            default:
                return "Slack said: \(code)"
            }
        }
    }

    private let session: URLSession
    private let tokenProvider: () -> String?

    public init(session: URLSession = .shared, tokenProvider: @escaping () -> String?) {
        self.session = session
        self.tokenProvider = tokenProvider
    }

    /// Checks the token and returns the workspace name it belongs to.
    public func verify() async throws -> String {
        let json = try await call(Self.request(method: "auth.test", token: try token(), form: [:]))
        return json["team"] as? String ?? "Slack"
    }

    public func setStatus(text: String, emoji: String, until expiration: Date?) async throws {
        _ = try await call(Self.statusRequest(token: try token(), text: text, emoji: emoji, expiration: expiration))
    }

    public func clearStatus() async throws {
        _ = try await call(Self.statusRequest(token: try token(), text: "", emoji: "", expiration: nil))
    }

    public func pauseNotifications(minutes: Int) async throws {
        _ = try await call(Self.request(method: "dnd.setSnooze", token: try token(),
                                        form: ["num_minutes": String(max(1, minutes))]))
    }

    public func resumeNotifications() async throws {
        do {
            _ = try await call(Self.request(method: "dnd.endSnooze", token: try token(), form: [:]))
        } catch SlackError.api("snooze_not_active") {
            // Already over — the snooze ran out on its own or was ended in Slack.
        }
    }

    // MARK: Requests

    static func statusRequest(token: String, text: String, emoji: String, expiration: Date?) -> URLRequest {
        var profile: [String: Any] = [
            "status_text": String(text.prefix(100)),
            "status_emoji": emoji
        ]
        profile["status_expiration"] = expiration.map { Int($0.timeIntervalSince1970) } ?? 0

        var request = URLRequest(url: URL(string: "https://slack.com/api/users.profile.set")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["profile": profile])
        return request
    }

    static func request(method: String, token: String, form: [String: String]) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://slack.com/api/\(method)")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var components = URLComponents()
        components.queryItems = form.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        request.httpBody = Data((components.percentEncodedQuery ?? "").utf8)
        return request
    }

    private func token() throws -> String {
        guard let token = tokenProvider(), !token.isEmpty else { throw SlackError.missingToken }
        return token
    }

    private func call(_ request: URLRequest) async throws -> [String: Any] {
        let data: Data
        do {
            (data, _) = try await session.data(for: request)
        } catch {
            throw SlackError.transport(error.localizedDescription)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SlackError.api("unreadable_response")
        }
        guard json["ok"] as? Bool == true else {
            throw SlackError.api(json["error"] as? String ?? "unknown_error")
        }
        return json
    }
}
