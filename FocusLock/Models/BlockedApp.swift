import Foundation

public struct BlockedApp: Codable, Equatable, Hashable, Identifiable {
    public var id: String { bundleId }

    public var name: String
    public var bundleId: String

    public init(name: String, bundleId: String) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.bundleId = bundleId.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
