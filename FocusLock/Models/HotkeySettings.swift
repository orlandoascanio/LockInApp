import Foundation

/// A system-wide key combination, stored as a virtual key code plus Carbon
/// modifier flags — the form `RegisterEventHotKey` takes.
public struct KeyCombo: Codable, Equatable, Hashable {
    public var keyCode: UInt32
    public var modifiers: UInt32

    // Carbon's modifier masks, spelled out so the model does not need Carbon.
    public static let command: UInt32 = 0x0100
    public static let shift: UInt32 = 0x0200
    public static let option: UInt32 = 0x0800
    public static let control: UInt32 = 0x1000

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// A global shortcut without Command, Option, or Control would swallow
    /// ordinary typing everywhere else on the Mac.
    public var isUsable: Bool {
        modifiers & (Self.command | Self.option | Self.control) != 0
    }

    public var modifierSymbols: String {
        var symbols = ""
        if modifiers & Self.control != 0 { symbols += "⌃" }
        if modifiers & Self.option != 0 { symbols += "⌥" }
        if modifiers & Self.shift != 0 { symbols += "⇧" }
        if modifiers & Self.command != 0 { symbols += "⌘" }
        return symbols
    }
}

public enum HotkeyAction: String, Codable, CaseIterable, Identifiable {
    case start
    case stop
    case skip

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .start: return "Start focus"
        case .stop: return "Stop session"
        case .skip: return "Skip to next phase"
        }
    }
}

public struct HotkeySettings: Codable, Equatable {
    public var enabled = true
    public var start: KeyCombo? = KeyCombo(keyCode: 1, modifiers: KeyCombo.control | KeyCombo.option | KeyCombo.command)  // ⌃⌥⌘S
    public var stop: KeyCombo? = KeyCombo(keyCode: 14, modifiers: KeyCombo.control | KeyCombo.option | KeyCombo.command)   // ⌃⌥⌘E
    public var skip: KeyCombo? = KeyCombo(keyCode: 45, modifiers: KeyCombo.control | KeyCombo.option | KeyCombo.command)   // ⌃⌥⌘N

    public init() {}

    public subscript(action: HotkeyAction) -> KeyCombo? {
        get {
            switch action {
            case .start: return start
            case .stop: return stop
            case .skip: return skip
            }
        }
        set {
            switch action {
            case .start: start = newValue
            case .stop: stop = newValue
            case .skip: skip = newValue
            }
        }
    }

    /// Assigning a combo already used by another action moves it rather than
    /// leaving two actions fighting over one key.
    public mutating func assign(_ combo: KeyCombo?, to action: HotkeyAction) {
        if let combo {
            for other in HotkeyAction.allCases where other != action && self[other] == combo {
                self[other] = nil
            }
        }
        self[action] = combo
    }

    private enum CodingKeys: String, CodingKey {
        case enabled, start, stop, skip
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = HotkeySettings()
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? fallback.enabled
        // A missing key means "never set" and gets the default; an explicit
        // null means the shortcut was cleared on purpose.
        start = container.contains(.start) ? try container.decodeIfPresent(KeyCombo.self, forKey: .start) : fallback.start
        stop = container.contains(.stop) ? try container.decodeIfPresent(KeyCombo.self, forKey: .stop) : fallback.stop
        skip = container.contains(.skip) ? try container.decodeIfPresent(KeyCombo.self, forKey: .skip) : fallback.skip
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(start, forKey: .start)
        try container.encode(stop, forKey: .stop)
        try container.encode(skip, forKey: .skip)
    }
}
