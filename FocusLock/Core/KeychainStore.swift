import Foundation
import Security

/// Secrets that must not sit in `config.json`: the Slack token and the
/// Discord webhook link, which both let anyone holding them act as you.
public struct KeychainStore {
    public enum Key: String, CaseIterable {
        case slackToken = "slack-user-token"
        case discordWebhook = "discord-webhook-url"
    }

    public let service: String

    public init(service: String = AppIdentity.bundleIdentifier) {
        self.service = service
    }

    public func string(for key: Key) -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// An empty or whitespace-only value removes the item.
    @discardableResult
    public func set(_ value: String?, for key: Key) -> Bool {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else {
            let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
            return status == errSecSuccess || status == errSecItemNotFound
        }

        let data = Data(trimmed.utf8)
        let update = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery(for: key) as CFDictionary, update as CFDictionary)
        if status == errSecSuccess {
            return true
        }
        guard status == errSecItemNotFound else { return false }

        var add = baseQuery(for: key)
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    public func has(_ key: Key) -> Bool {
        string(for: key) != nil
    }

    private func baseQuery(for key: Key) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
    }
}
