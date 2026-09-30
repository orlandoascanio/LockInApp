import Foundation

public enum BreakSuggestionKind: String, Codable, CaseIterable, Identifiable {
    case eyes
    case water
    case stretch
    case walk
    case breathe
    case posture

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .eyes: return "Rest your eyes"
        case .water: return "Drink water"
        case .stretch: return "Stretch"
        case .walk: return "Walk"
        case .breathe: return "Breathe"
        case .posture: return "Posture"
        }
    }

    /// Short breaks have no room for a walk; everything else fits in a minute.
    var minimumBreakMinutes: Int {
        self == .walk ? 5 : 0
    }
}

public struct BreakSuggestion: Equatable {
    public var kind: BreakSuggestionKind
    public var title: String
    public var detail: String
    public var systemImage: String

    public init(kind: BreakSuggestionKind, title: String, detail: String, systemImage: String) {
        self.kind = kind
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
    }
}

public struct BreakSuggestionSettings: Codable, Equatable {
    public var enabled = true
    public var kinds: Set<BreakSuggestionKind> = Set(BreakSuggestionKind.allCases)
    /// A quiet 20-20-20 reminder every 20 minutes inside long focus blocks.
    public var eyeReminderDuringFocus = false

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case enabled, kinds, eyeReminderDuringFocus
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = BreakSuggestionSettings()
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? fallback.enabled
        // Kinds from a newer build are dropped rather than failing the section.
        let names = try container.decodeIfPresent([String].self, forKey: .kinds)
        kinds = names.map { Set($0.compactMap(BreakSuggestionKind.init(rawValue:))) } ?? fallback.kinds
        eyeReminderDuringFocus = try container.decodeIfPresent(Bool.self, forKey: .eyeReminderDuringFocus)
            ?? fallback.eyeReminderDuringFocus
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(kinds.map(\.rawValue).sorted(), forKey: .kinds)
        try container.encode(eyeReminderDuringFocus, forKey: .eyeReminderDuringFocus)
    }
}

public enum BreakSuggestions {
    /// Seconds of focus between 20-20-20 reminders.
    public static let eyeReminderInterval: TimeInterval = 20 * 60

    public static let eyeReminder = BreakSuggestion(
        kind: .eyes,
        title: "20-20-20",
        detail: "Look at something about 20 feet (6 m) away for 20 seconds.",
        systemImage: "eye"
    )

    /// Deterministic for a given block, so the notification, the main window,
    /// and the HUD all show the same suggestion. Rotates through the enabled
    /// kinds as the run goes on, and prefers a walk once a break is long
    /// enough to take one.
    public static func suggestion(
        forCycle cycle: Int,
        breakMinutes: Int,
        settings: BreakSuggestionSettings
    ) -> BreakSuggestion? {
        guard settings.enabled else { return nil }
        let kinds = BreakSuggestionKind.allCases.filter {
            settings.kinds.contains($0) && breakMinutes >= $0.minimumBreakMinutes
        }
        guard !kinds.isEmpty else { return nil }

        let index = max(0, cycle - 1)
        let kind: BreakSuggestionKind
        if breakMinutes >= 10, kinds.contains(.walk), index % 2 == 1 {
            kind = .walk
        } else {
            kind = kinds[index % kinds.count]
        }

        let variants = catalog[kind] ?? []
        guard !variants.isEmpty else { return nil }
        return variants[(index / kinds.count) % variants.count]
    }

    static let catalog: [BreakSuggestionKind: [BreakSuggestion]] = [
        .eyes: [
            BreakSuggestion(kind: .eyes, title: "20-20-20 for your eyes",
                            detail: "Look at something about 20 feet (6 m) away for 20 seconds, then blink slowly a few times.",
                            systemImage: "eye"),
            BreakSuggestion(kind: .eyes, title: "Look out a window",
                            detail: "Let your eyes settle on the farthest thing you can see for half a minute.",
                            systemImage: "eye")
        ],
        .water: [
            BreakSuggestion(kind: .water, title: "Drink some water",
                            detail: "Refill your glass before you sit back down.",
                            systemImage: "drop"),
            BreakSuggestion(kind: .water, title: "Hydrate",
                            detail: "A full glass now beats a headache in an hour.",
                            systemImage: "drop")
        ],
        .stretch: [
            BreakSuggestion(kind: .stretch, title: "Roll your shoulders",
                            detail: "Ten slow rolls backwards, then pull each arm across your chest for 15 seconds.",
                            systemImage: "figure.flexibility"),
            BreakSuggestion(kind: .stretch, title: "Reach up, fold down",
                            detail: "Stand, reach for the ceiling, then fold forward and let your arms hang for a few breaths.",
                            systemImage: "figure.flexibility"),
            BreakSuggestion(kind: .stretch, title: "Loosen your neck",
                            detail: "Tilt an ear towards each shoulder and hold 15 seconds a side. No rolling.",
                            systemImage: "figure.flexibility")
        ],
        .walk: [
            BreakSuggestion(kind: .walk, title: "Take a short walk",
                            detail: "Leave the desk. A lap of the room or a few minutes outside resets your attention.",
                            systemImage: "figure.walk")
        ],
        .breathe: [
            BreakSuggestion(kind: .breathe, title: "Box breathing",
                            detail: "In for 4, hold for 4, out for 4, hold for 4. Four rounds.",
                            systemImage: "wind"),
            BreakSuggestion(kind: .breathe, title: "Long exhale",
                            detail: "Breathe in for 4 and out for 8, five times. It slows everything down.",
                            systemImage: "wind")
        ],
        .posture: [
            BreakSuggestion(kind: .posture, title: "Reset your posture",
                            detail: "Feet flat, shoulders down and back, top of the screen at eye level.",
                            systemImage: "figure.stand")
        ]
    ]
}
