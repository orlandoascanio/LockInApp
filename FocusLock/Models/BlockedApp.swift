import Foundation

public struct BlockedApp: Codable, Equatable, Hashable, Identifiable {
    public var id: String { bundleId }

    public var name: String
    public var bundleId: String

    /// Per-app override for how this app is guarded. `nil` means "follow the
    /// global behaviour from Settings", which is what every app added before
    /// per-app overrides existed decodes to.
    public var behavior: BlockerMode?

    /// Lets an app stay in the list while being temporarily exempt from
    /// guarding, so removing and re-adding it is not the only way to pause it.
    public var isEnabled: Bool

    public init(
        name: String,
        bundleId: String,
        behavior: BlockerMode? = nil,
        isEnabled: Bool = true
    ) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.bundleId = bundleId.trimmingCharacters(in: .whitespacesAndNewlines)
        self.behavior = behavior
        self.isEnabled = isEnabled
    }

    /// The behaviour actually applied to this app, resolving the override
    /// against the global default.
    public func effectiveBehavior(default fallback: BlockerMode) -> BlockerMode {
        behavior ?? fallback
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case bundleId
        case behavior
        case isEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        bundleId = try container.decode(String.self, forKey: .bundleId)
        behavior = try container.decodeIfPresent(BlockerMode.self, forKey: .behavior)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }
}
