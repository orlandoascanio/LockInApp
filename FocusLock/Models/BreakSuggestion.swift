import Foundation

public enum BreakSuggestionKind: String, Codable, CaseIterable, Identifiable {
    case eyes
    case water
    case stretch
    case walk
    case breathe
    case posture
    case pushups
    case squats

    public var id: String { rawValue }

    /// The six there were before push-ups and squats. Someone who had all of
    /// them on gets the new ones too.
    static let original: Set<BreakSuggestionKind> = [.eyes, .water, .stretch, .walk, .breathe, .posture]

    /// Gets you out of the chair, for the end of a long run of blocks.
    public var isMovement: Bool {
        [.walk, .stretch, .pushups, .squats].contains(self)
    }

    public var systemImage: String {
        switch self {
        case .eyes: return "eye"
        case .water: return "drop"
        case .stretch: return "figure.flexibility"
        case .walk: return "figure.walk"
        case .breathe: return "wind"
        case .posture: return "figure.stand"
        case .pushups: return "figure.core.training"
        case .squats: return "figure.strengthtraining.functional"
        }
    }

    public var title: String {
        switch self {
        case .eyes: return "Rest your eyes"
        case .water: return "Drink water"
        case .stretch: return "Stretch"
        case .walk: return "Walk"
        case .breathe: return "Breathe"
        case .posture: return "Posture"
        case .pushups: return "Push-ups"
        case .squats: return "Squats"
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
        var decoded = names.map { Set($0.compactMap(BreakSuggestionKind.init(rawValue:))) } ?? fallback.kinds
        if decoded.isSuperset(of: BreakSuggestionKind.original) {
            decoded.formUnion(BreakSuggestionKind.allCases)
        }
        kinds = decoded
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

    /// Breaks this long or shorter lean towards something done in your chair.
    public static let shortBreakMinutes = 5
    /// Breaks this long or longer lean towards a walk.
    public static let longBreakMinutes = 10
    /// After this many blocks in a row, breaks lean towards moving.
    public static let longRunBlocks = 3

    /// What a break is like, for choosing what to do with it.
    public struct Context: Equatable {
        /// The block this break follows, counted from the start of the run.
        public var cycle: Int
        public var breakMinutes: Int
        /// Last break's suggestion, so the same one never comes twice running.
        public var previous: BreakSuggestionKind?
        /// Suggestions already passed over this break with "Another one".
        public var passedOver: Set<BreakSuggestionKind>

        public init(
            cycle: Int,
            breakMinutes: Int,
            previous: BreakSuggestionKind? = nil,
            passedOver: Set<BreakSuggestionKind> = []
        ) {
            self.cycle = max(1, cycle)
            self.breakMinutes = breakMinutes
            self.previous = previous
            self.passedOver = passedOver
        }
    }

    /// Picks something to do with a break:
    /// - a long run of blocks asks for moving (a walk or a stretch);
    /// - a long break leans towards a walk;
    /// - a short one towards breathing or resting your eyes;
    /// - last break's suggestion is never repeated, and neither is one passed
    ///   over this break, while anything else is left.
    /// Deterministic for the same context, so it can be recomputed and tested.
    public static func suggestion(for context: Context, settings: BreakSuggestionSettings) -> BreakSuggestion? {
        guard settings.enabled else { return nil }
        let enabled = BreakSuggestionKind.allCases.filter {
            settings.kinds.contains($0) && context.breakMinutes >= $0.minimumBreakMinutes
        }
        guard !enabled.isEmpty else { return nil }

        var candidates = enabled.filter { !context.passedOver.contains($0) }
        if candidates.isEmpty {
            // Everything has been passed over: start again, minus the last one.
            candidates = enabled
        }
        if let previous = context.previous, candidates.count > 1 {
            candidates.removeAll { $0 == previous }
        }

        let preferred = candidates.filter { preferredKinds(for: context).contains($0) }
        let pool = preferred.isEmpty ? candidates : preferred
        let kind = pool[(context.cycle - 1 + context.passedOver.count) % pool.count]
        return suggestion(of: kind, cycle: context.cycle)
    }

    /// The suggestion for a kind, worded for this block, so a kind that comes
    /// up often doesn't always read the same.
    public static func suggestion(of kind: BreakSuggestionKind, cycle: Int) -> BreakSuggestion? {
        guard let variants = catalog[kind], !variants.isEmpty else { return nil }
        return variants[(max(1, cycle) - 1) % variants.count]
    }

    /// Kept for callers that only know the block and the break length.
    public static func suggestion(
        forCycle cycle: Int,
        breakMinutes: Int,
        settings: BreakSuggestionSettings
    ) -> BreakSuggestion? {
        suggestion(for: Context(cycle: cycle, breakMinutes: breakMinutes), settings: settings)
    }

    private static func preferredKinds(for context: Context) -> Set<BreakSuggestionKind> {
        if context.cycle >= longRunBlocks {
            return Set(BreakSuggestionKind.allCases.filter(\.isMovement))
        }
        if context.breakMinutes >= longBreakMinutes {
            return [.walk]
        }
        if context.breakMinutes <= shortBreakMinutes {
            return [.breathe, .eyes]
        }
        return []
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
        ],
        .pushups: [
            BreakSuggestion(kind: .pushups, title: "10 push-ups",
                            detail: "Hands under your shoulders, body in one line. On your knees or against the desk counts.",
                            systemImage: "figure.core.training")
        ],
        .squats: [
            BreakSuggestion(kind: .squats, title: "15 squats",
                            detail: "Feet shoulder-width apart, sit back as if into a chair, stand tall again.",
                            systemImage: "figure.strengthtraining.functional")
        ]
    ]
}
