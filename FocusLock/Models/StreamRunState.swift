import Foundation

/// The part of a stream in progress that history cannot reconstruct.
///
/// The recap is derived from history on demand, which is why it survives the
/// wall being cleared — but it needs to know where the run began, and that is
/// not written in any session entry. The wall is not in history at all: nobody
/// else's task belongs in the host's own record. So both are kept here, and a
/// crash or a quit two hours into a stream costs neither.
///
/// It outlives the run on purpose. A host who closes the app after finishing
/// still wants the recap when they go looking for it; only starting the next
/// run replaces this.
public struct StreamRunState: Codable, Equatable {
    public var startedAt: Date
    public var roster: AudienceRoster

    public init(startedAt: Date, roster: AudienceRoster) {
        self.startedAt = startedAt
        self.roster = roster
    }

    private enum CodingKeys: String, CodingKey {
        case startedAt, roster
    }

    /// A file written by a newer build, or half-written by a crash, should cost
    /// at most the parts it got wrong — never the whole wall.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt) ?? Date()
        roster = try container.decodeIfPresent(AudienceRoster.self, forKey: .roster) ?? AudienceRoster()
    }
}
