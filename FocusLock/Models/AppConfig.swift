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

/// Light, dark, or whatever macOS is set to.
public enum AppearancePreference: String, Codable, Equatable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: return "Match System"
        case .light: return "Light"
        case .dark: return "Dark"
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
    public var blockedSites: [BlockedSite]

    /// The goal and category the next block runs with.
    public var task: FocusTaskSettings

    /// Keeps the countdown strip floating above every window during a session.
    public var pinnedHUDEnabled: Bool

    public var strict: StrictModeSettings
    public var schedules: [FocusSchedule]
    public var breakSuggestions: BreakSuggestionSettings
    public var hotkeys: HotkeySettings
    public var integrations: IntegrationSettings
    public var appearance: AppearancePreference

    /// False only on a brand-new install, until the welcome guide is finished
    /// or skipped.
    public var onboardingCompleted: Bool

    /// Ask "are you sure?" before ending a session, skipping a focus block,
    /// or quitting while one is running.
    public var confirmBeforeEnding: Bool

    public init(
        focusMinutes: Int = 50,
        breakMinutes: Int = 10,
        blockerMode: BlockerMode = .guardScreen,
        breakEndBehavior: BreakEndBehavior = .ask,
        autoResume: AutoResumePlanner = .default,
        blockedApps: [BlockedApp] = [],
        blockedSites: [BlockedSite] = [],
        pinnedHUDEnabled: Bool = true,
        task: FocusTaskSettings = FocusTaskSettings(),
        strict: StrictModeSettings = StrictModeSettings(),
        schedules: [FocusSchedule] = [],
        breakSuggestions: BreakSuggestionSettings = BreakSuggestionSettings(),
        hotkeys: HotkeySettings = HotkeySettings(),
        integrations: IntegrationSettings = IntegrationSettings(),
        appearance: AppearancePreference = .system,
        onboardingCompleted: Bool = false,
        confirmBeforeEnding: Bool = true
    ) {
        self.focusMinutes = Self.normalizedFocusMinutes(focusMinutes)
        self.breakMinutes = max(0, breakMinutes)
        self.blockerMode = blockerMode
        self.breakEndBehavior = breakEndBehavior
        self.autoResume = autoResume
        self.blockedApps = blockedApps
        self.blockedSites = blockedSites
        self.pinnedHUDEnabled = pinnedHUDEnabled
        self.task = task
        self.strict = strict
        self.schedules = schedules
        self.breakSuggestions = breakSuggestions
        self.hotkeys = hotkeys
        self.integrations = integrations
        self.appearance = appearance
        self.onboardingCompleted = onboardingCompleted
        self.confirmBeforeEnding = confirmBeforeEnding
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
        case blockedSites
        case pinnedHUDEnabled
        case task
        case stream
        case strict
        case schedules
        case breakSuggestions
        case hotkeys
        case integrations
        case appearance
        case onboardingCompleted
        case confirmBeforeEnding
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
            // Before blocker modes existed, "strict" meant hiding without the guard screen.
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
        blockedSites = (try? container.decodeIfPresent([BlockedSite].self, forKey: .blockedSites)) ?? []
        // Goals and categories used to live with the stream settings; a config
        // from those builds carries them over rather than losing the list.
        task = (try? container.decodeIfPresent(FocusTaskSettings.self, forKey: .task))
            ?? (try? container.decodeIfPresent(FocusTaskSettings.self, forKey: .stream))
            ?? FocusTaskSettings()
        pinnedHUDEnabled = try container.decodeIfPresent(Bool.self, forKey: .pinnedHUDEnabled) ?? true
        // A section this build cannot read falls back alone instead of
        // resetting every other setting with it.
        strict = (try? container.decodeIfPresent(StrictModeSettings.self, forKey: .strict)) ?? StrictModeSettings()
        schedules = (try? container.decodeIfPresent([FocusSchedule].self, forKey: .schedules)) ?? []
        breakSuggestions = (try? container.decodeIfPresent(BreakSuggestionSettings.self, forKey: .breakSuggestions))
            ?? BreakSuggestionSettings()
        hotkeys = (try? container.decodeIfPresent(HotkeySettings.self, forKey: .hotkeys)) ?? HotkeySettings()
        integrations = (try? container.decodeIfPresent(IntegrationSettings.self, forKey: .integrations))
            ?? IntegrationSettings()
        appearance = (try? container.decodeIfPresent(AppearancePreference.self, forKey: .appearance)) ?? .system
        // A config written before the welcome guide existed belongs to someone
        // already using the app, who should not be walked through it.
        onboardingCompleted = (try? container.decodeIfPresent(Bool.self, forKey: .onboardingCompleted)) ?? true
        confirmBeforeEnding = (try? container.decodeIfPresent(Bool.self, forKey: .confirmBeforeEnding)) ?? true
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(focusMinutes, forKey: .focusMinutes)
        try container.encode(breakMinutes, forKey: .breakMinutes)
        try container.encode(blockerMode, forKey: .blockerMode)
        try container.encode(breakEndBehavior, forKey: .breakEndBehavior)
        try container.encode(autoResume, forKey: .autoResume)
        try container.encode(blockedApps, forKey: .blockedApps)
        try container.encode(blockedSites, forKey: .blockedSites)
        try container.encode(pinnedHUDEnabled, forKey: .pinnedHUDEnabled)
        try container.encode(task, forKey: .task)
        try container.encode(strict, forKey: .strict)
        try container.encode(schedules, forKey: .schedules)
        try container.encode(breakSuggestions, forKey: .breakSuggestions)
        try container.encode(hotkeys, forKey: .hotkeys)
        try container.encode(integrations, forKey: .integrations)
        try container.encode(appearance, forKey: .appearance)
        try container.encode(onboardingCompleted, forKey: .onboardingCompleted)
        try container.encode(confirmBeforeEnding, forKey: .confirmBeforeEnding)
    }

    public static func normalizedFocusMinutes(_ minutes: Int) -> Int {
        min(focusMinutesRange.upperBound, max(focusMinutesRange.lowerBound, minutes))
    }
}
