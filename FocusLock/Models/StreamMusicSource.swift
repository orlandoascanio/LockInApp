import Foundation

/// A place to get music that is meant to be played over a broadcast.
///
/// LockIn never plays or rebroadcasts audio — these are links, and opening one
/// is the whole of what the app does with them. They exist because the honest
/// advice ("most commercial music is not cleared for streaming") is useless on
/// its own: a host who has just been told not to use Spotify still needs
/// somewhere to go, and the alternative to naming somewhere is a muted VOD.
///
/// What each one asks of you differs and changes without notice, so every entry
/// carries its own condition and none of them is described as safe. LockIn is
/// not clearing anything; the terms on the day are the ones that count.
public struct StreamMusicSource: Identifiable, Equatable {
    public var id: String { name }

    public let name: String

    /// What it actually sounds like, because "royalty-free" describes a licence
    /// rather than a room, and these streams are chosen for the room.
    public let sound: String

    /// What it costs and what it asks of you in return — the part that decides
    /// whether it suits you, and the part most lists leave out.
    public let terms: String

    public let link: String

    public init(name: String, sound: String, terms: String, link: String) {
        self.name = name
        self.sound = sound
        self.terms = terms
        self.link = link
    }

    public var url: URL? { URL(string: link) }

    /// Ordered for a co-working room: the lofi people actually put on these
    /// streams first, the wider catalogues after.
    public static let all: [StreamMusicSource] = [
        StreamMusicSource(
            name: "StreamBeats",
            sound: "Lofi, synthwave, jazz, chillhop",
            terms: "Free, no credit asked. Registered with Content ID and Audible Magic, so the platforms know it.",
            link: "https://streambeats.com"
        ),
        StreamMusicSource(
            name: "Chillhop",
            sound: "Lofi and jazzhop — the sound of the rooms this feature is for",
            terms: "Free through their creators programme: sign up, connect your channel, and credit them on a panel.",
            link: "https://chillhop.com/creators/"
        ),
        StreamMusicSource(
            name: "Pretzel",
            sound: "Stations rather than playlists, built for streaming",
            terms: "Free with a credit line in your chat; the paid tier drops it and opens the full catalogue.",
            link: "https://www.pretzel.rocks"
        ),
        StreamMusicSource(
            name: "NoCopyrightSounds",
            sound: "Electronic, and better suited to a break than a focus block",
            terms: "Free with attribution — check their terms for how they want it worded.",
            link: "https://ncs.io"
        ),
        StreamMusicSource(
            name: "Epidemic Sound",
            sound: "A broad commercial catalogue, most genres",
            terms: "Paid subscription. Covers the VOD as well as the live stream, which the free options often do not.",
            link: "https://www.epidemicsound.com"
        )
    ]
}
