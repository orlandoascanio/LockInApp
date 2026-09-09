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
    /// Focus blocks can span a full day while still keeping timer arithmetic
    /// and accidental input within a practical bound.
    public static let focusMinutesRange = 1...1_440

    public var focusMinutes: Int
    public var breakMinutes: Int
    public var blockerMode: BlockerMode
    public var breakEndBehavior: BreakEndBehavior
    /// Grace period and countdown used when `breakEndBehavior` is `.autopilot`.
    public var autoResume: AutoResumePlanner
    public var blockedApps: [BlockedApp]

    /// Goal, category, and canvas options used when hosting a shared session.
    public var stream: StreamSettings

    /// Keeps the countdown strip floating above every window during a session.
    public var pinnedHUDEnabled: Bool

    public var strictMode: Bool {
        get { blockerMode != .guardScreen }
        set { blockerMode = newValue ? .hideOnly : .guardScreen }
    }

    public init(
        focusMinutes: Int = 50,
        breakMinutes: Int = 10,
        blockerMode: BlockerMode = .guardScreen,
        strictMode: Bool? = nil,
        breakEndBehavior: BreakEndBehavior = .ask,
        autoResume: AutoResumePlanner = .default,
        blockedApps: [BlockedApp] = [],
        pinnedHUDEnabled: Bool = true,
        stream: StreamSettings = StreamSettings()
    ) {
        self.focusMinutes = Self.normalizedFocusMinutes(focusMinutes)
        self.breakMinutes = max(0, breakMinutes)
        self.blockerMode = strictMode.map { $0 ? .hideOnly : .guardScreen } ?? blockerMode
        self.breakEndBehavior = breakEndBehavior
        self.autoResume = autoResume
        self.blockedApps = blockedApps
        self.pinnedHUDEnabled = pinnedHUDEnabled
        self.stream = stream
    }

    public static let `default` = AppConfig()

    private enum CodingKeys: String, CodingKey {
        case focusMinutes
        case breakMinutes
        case blockerMode
        case strictMode
        case breakEndBehavior
        case autoStartFocusAfterBreak
        case autoResume
        case blockedApps
        case pinnedHUDEnabled
        case stream
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        focusMinutes = Self.normalizedFocusMinutes(
            try container.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? 50
        )
        breakMinutes = max(0, try container.decodeIfPresent(Int.self, forKey: .breakMinutes) ?? 10)
        if let decodedMode = try container.decodeIfPresent(BlockerMode.self, forKey: .blockerMode) {
            blockerMode = decodedMode
        } else {
            let legacyStrictMode = try container.decodeIfPresent(Bool.self, forKey: .strictMode) ?? false
            blockerMode = legacyStrictMode ? .hideOnly : .guardScreen
        }
        if let decodedBehavior = try container.decodeIfPresent(BreakEndBehavior.self, forKey: .breakEndBehavior) {
            breakEndBehavior = decodedBehavior
        } else {
            // Configs written before autopilot existed only knew "ask" or "go".
            let legacyAutoStart = try container.decodeIfPresent(Bool.self, forKey: .autoStartFocusAfterBreak) ?? false
            breakEndBehavior = legacyAutoStart ? .startImmediately : .ask
        }
        autoResume = try container.decodeIfPresent(AutoResumePlanner.self, forKey: .autoResume) ?? .default
        blockedApps = try container.decodeIfPresent([BlockedApp].self, forKey: .blockedApps) ?? []
        stream = try container.decodeIfPresent(StreamSettings.self, forKey: .stream) ?? StreamSettings()
        pinnedHUDEnabled = try container.decodeIfPresent(Bool.self, forKey: .pinnedHUDEnabled) ?? true
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(focusMinutes, forKey: .focusMinutes)
        try container.encode(breakMinutes, forKey: .breakMinutes)
        try container.encode(blockerMode, forKey: .blockerMode)
        try container.encode(breakEndBehavior, forKey: .breakEndBehavior)
        try container.encode(autoResume, forKey: .autoResume)
        try container.encode(blockedApps, forKey: .blockedApps)
        try container.encode(pinnedHUDEnabled, forKey: .pinnedHUDEnabled)
        try container.encode(stream, forKey: .stream)
    }

    public static func normalizedFocusMinutes(_ minutes: Int) -> Int {
        min(focusMinutesRange.upperBound, max(focusMinutesRange.lowerBound, minutes))
    }
}
