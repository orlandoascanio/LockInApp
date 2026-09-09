import Foundation

/// A kind of session, as a starting point: what you call it, how long the
/// blocks run, and what the audience window says this room is for.
public struct StreamPreset: Identifiable, Equatable {
    public var id: String { name }

    public let name: String
    public let category: String
    public let focusMinutes: Int
    public let breakMinutes: Int
    public let blocks: Int
    public let invitation: String

    public init(name: String, category: String, focusMinutes: Int, breakMinutes: Int, blocks: Int, invitation: String) {
        self.name = name
        self.category = category
        self.focusMinutes = focusMinutes
        self.breakMinutes = breakMinutes
        self.blocks = blocks
        self.invitation = invitation
    }

    /// Presets are a starting point, never a lock: everything they set stays
    /// editable afterwards, and your goal is left alone.
    public func apply(to config: inout AppConfig) {
        config.focusMinutes = AppConfig.normalizedFocusMinutes(focusMinutes)
        config.breakMinutes = min(60, max(0, breakMinutes))
        config.stream.addCategory(category)
        config.stream.plannedBlocks = min(12, max(1, blocks))
        config.stream.invitation = invitation
    }

    public func matches(_ config: AppConfig) -> Bool {
        config.focusMinutes == AppConfig.normalizedFocusMinutes(focusMinutes)
            && config.breakMinutes == breakMinutes
            && config.stream.category.lowercased() == category.lowercased()
            && config.stream.plannedBlocks == blocks
    }

    public static let bringYourOwnTask = StreamPreset(
        name: "Bring your own task",
        category: "Study",
        focusMinutes: 50,
        breakMinutes: 10,
        blocks: 4,
        invitation: "Bring your own task · Everyone is welcome"
    )

    public static let all: [StreamPreset] = [
        bringYourOwnTask,
        StreamPreset(
            name: "Read with me",
            category: "Reading",
            focusMinutes: 25,
            breakMinutes: 5,
            blocks: 4,
            invitation: "Bring your own book · Read at your own pace"
        ),
        StreamPreset(
            name: "Build with me",
            category: "Coding",
            focusMinutes: 50,
            breakMinutes: 10,
            blocks: 3,
            invitation: "Bring your own project · Ship one small thing"
        ),
        StreamPreset(
            name: "Language practice",
            category: "Language",
            focusMinutes: 25,
            breakMinutes: 5,
            blocks: 4,
            invitation: "Bring your own language · Out loud or quietly, both count"
        ),
        StreamPreset(
            name: "Deep work",
            category: "Work",
            focusMinutes: 90,
            breakMinutes: 15,
            blocks: 2,
            invitation: "Bring your own hard thing · One long block, no rush"
        )
    ]
}
