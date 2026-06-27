import Foundation

public enum BlockerMode: String, Codable, Equatable, CaseIterable, Identifiable {
    case guardScreen = "guard"
    case hideOnly
    case quitApp

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .guardScreen:
            return "Guard Screen"
        case .hideOnly:
            return "Hide Only"
        case .quitApp:
            return "Quit App"
        }
    }

    public var helperText: String {
        switch self {
        case .guardScreen:
            return "Guard Screen keeps apps like Discord running in the background while stopping you from actively using them."
        case .hideOnly:
            return "Hide Only hides guarded apps without showing the guard screen."
        case .quitApp:
            return "Quit App asks guarded apps to quit when opened during focus."
        }
    }
}

public struct AppConfig: Codable, Equatable {
    public var focusMinutes: Int
    public var breakMinutes: Int
    public var blockerMode: BlockerMode
    public var autoStartFocusAfterBreak: Bool
    public var blockedApps: [BlockedApp]

    public var strictMode: Bool {
        get { blockerMode != .guardScreen }
        set { blockerMode = newValue ? .hideOnly : .guardScreen }
    }

    public init(
        focusMinutes: Int = 25,
        breakMinutes: Int = 5,
        blockerMode: BlockerMode = .guardScreen,
        strictMode: Bool? = nil,
        autoStartFocusAfterBreak: Bool = false,
        blockedApps: [BlockedApp] = []
    ) {
        self.focusMinutes = max(1, focusMinutes)
        self.breakMinutes = max(0, breakMinutes)
        self.blockerMode = strictMode.map { $0 ? .hideOnly : .guardScreen } ?? blockerMode
        self.autoStartFocusAfterBreak = autoStartFocusAfterBreak
        self.blockedApps = blockedApps
    }

    public static let `default` = AppConfig()

    private enum CodingKeys: String, CodingKey {
        case focusMinutes
        case breakMinutes
        case blockerMode
        case strictMode
        case autoStartFocusAfterBreak
        case blockedApps
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        focusMinutes = max(1, try container.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? 25)
        breakMinutes = max(0, try container.decodeIfPresent(Int.self, forKey: .breakMinutes) ?? 5)
        if let decodedMode = try container.decodeIfPresent(BlockerMode.self, forKey: .blockerMode) {
            blockerMode = decodedMode
        } else {
            let legacyStrictMode = try container.decodeIfPresent(Bool.self, forKey: .strictMode) ?? false
            blockerMode = legacyStrictMode ? .hideOnly : .guardScreen
        }
        autoStartFocusAfterBreak = try container.decodeIfPresent(Bool.self, forKey: .autoStartFocusAfterBreak) ?? false
        blockedApps = try container.decodeIfPresent([BlockedApp].self, forKey: .blockedApps) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(focusMinutes, forKey: .focusMinutes)
        try container.encode(breakMinutes, forKey: .breakMinutes)
        try container.encode(blockerMode, forKey: .blockerMode)
        try container.encode(autoStartFocusAfterBreak, forKey: .autoStartFocusAfterBreak)
        try container.encode(blockedApps, forKey: .blockedApps)
    }
}
