import CoreGraphics
import Foundation

/// How the floating HUD looks and behaves, and where it sits on each display.
public struct HUDSettings: Codable, Equatable {
    public enum Size: String, Codable, CaseIterable, Identifiable {
        /// Just the ring and the time; hovering opens the rest.
        case compact
        /// Always shows the phase and the goal; hovering adds the controls.
        case large

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .compact: return "Compact"
            case .large: return "Large"
            }
        }
    }

    /// The opacities offered for a resting HUD; 1 means it never fades.
    public static let restingOpacityChoices: [Double] = [1, 0.6, 0.35, 0.2]

    public var size: Size
    /// What the HUD fades to a few seconds after it last needed attention.
    public var restingOpacity: Double
    /// Clicks go straight through to whatever is underneath. Holding Option
    /// makes the HUD usable again.
    public var clickThrough: Bool
    /// Where the HUD sits, by display UUID.
    public var placements: [String: HUDPlacement]
    /// The display the HUD was last put on, so it comes back there.
    public var lastDisplay: String?

    public init(
        size: Size = .compact,
        restingOpacity: Double = 0.35,
        clickThrough: Bool = false,
        placements: [String: HUDPlacement] = [:],
        lastDisplay: String? = nil
    ) {
        self.size = size
        self.restingOpacity = Self.normalizedOpacity(restingOpacity)
        self.clickThrough = clickThrough
        self.placements = placements
        self.lastDisplay = lastDisplay
    }

    public func placement(forDisplay display: String?) -> HUDPlacement {
        display.flatMap { placements[$0] } ?? .default
    }

    public static func normalizedOpacity(_ value: Double) -> Double {
        min(1, max(0.1, value))
    }

    private enum CodingKeys: String, CodingKey {
        case size, restingOpacity, clickThrough, placements, lastDisplay
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = HUDSettings()
        size = (try? container.decodeIfPresent(Size.self, forKey: .size)) ?? defaults.size
        restingOpacity = Self.normalizedOpacity(
            (try? container.decodeIfPresent(Double.self, forKey: .restingOpacity)) ?? defaults.restingOpacity
        )
        clickThrough = (try? container.decodeIfPresent(Bool.self, forKey: .clickThrough)) ?? defaults.clickThrough
        placements = (try? container.decodeIfPresent([String: HUDPlacement].self, forKey: .placements)) ?? [:]
        lastDisplay = try? container.decodeIfPresent(String.self, forKey: .lastDisplay)
    }
}

/// Where the HUD sits on one display, as an edge it is anchored to on each
/// axis plus a distance. Anchoring matters because the HUD changes size: one
/// parked in the top-right corner grows to the left, never off the screen.
public struct HUDPlacement: Codable, Equatable {
    public enum Anchor: String, Codable {
        /// Left, or top.
        case start
        case center
        /// Right, or bottom.
        case end
    }

    public var horizontal: Anchor
    public var vertical: Anchor
    /// From the anchored edge inwards; for `center`, the centre's offset
    /// rightwards.
    public var dx: Double
    /// From the anchored edge inwards; for `center`, the centre's offset
    /// upwards.
    public var dy: Double

    /// Gap left between a snapped HUD and the edge it snapped to.
    public static let margin: Double = 12
    /// How close to an edge, or to the middle, a drop has to land to snap.
    public static let snapDistance: Double = 40

    /// Top-right, just under the menu bar.
    public static let `default` = HUDPlacement(horizontal: .end, vertical: .start, dx: margin, dy: margin)

    public init(horizontal: Anchor, vertical: Anchor, dx: Double, dy: Double) {
        self.horizontal = horizontal
        self.vertical = vertical
        self.dx = dx
        self.dy = dy
    }

    /// The frame for a HUD of `size` in `area`, a screen's usable frame in
    /// AppKit coordinates (origin bottom-left). Always kept inside `area`.
    public func frame(size: CGSize, in area: CGRect) -> CGRect {
        let x: Double
        switch horizontal {
        case .start: x = area.minX + dx
        case .center: x = area.midX + dx - size.width / 2
        case .end: x = area.maxX - dx - size.width
        }

        let y: Double
        switch vertical {
        case .start: y = area.maxY - dy - size.height
        case .center: y = area.midY + dy - size.height / 2
        case .end: y = area.minY + dy
        }

        let clampedX = min(max(x, area.minX), area.maxX - size.width)
        let clampedY = min(max(y, area.minY), area.maxY - size.height)
        return CGRect(x: clampedX, y: clampedY, width: size.width, height: size.height)
    }

    /// Where a HUD dropped at `frame` belongs: snapped to an edge or the
    /// middle when it landed close to one, otherwise anchored to whichever
    /// side of the screen it is nearest, so it keeps growing away from it.
    public static func snapped(frame: CGRect, in area: CGRect) -> HUDPlacement {
        let (horizontal, dx) = snap(
            lowGap: frame.minX - area.minX,
            highGap: area.maxX - frame.maxX,
            centerOffset: frame.midX - area.midX,
            relative: (frame.midX - area.minX) / area.width
        )
        // AppKit's y grows upwards, so the top is the high side.
        let (verticalFromBottom, dyFromBottom) = snap(
            lowGap: frame.minY - area.minY,
            highGap: area.maxY - frame.maxY,
            centerOffset: frame.midY - area.midY,
            relative: (frame.midY - area.minY) / area.height
        )
        let vertical: Anchor
        switch verticalFromBottom {
        case .start: vertical = .end
        case .end: vertical = .start
        case .center: vertical = .center
        }
        return HUDPlacement(horizontal: horizontal, vertical: vertical, dx: dx, dy: dyFromBottom)
    }

    /// One axis. `start` here is the low-coordinate side.
    private static func snap(lowGap: Double, highGap: Double, centerOffset: Double, relative: Double) -> (Anchor, Double) {
        if lowGap <= snapDistance { return (.start, margin) }
        if highGap <= snapDistance { return (.end, margin) }
        if abs(centerOffset) <= snapDistance { return (.center, 0) }
        if relative < 1.0 / 3 { return (.start, lowGap) }
        if relative > 2.0 / 3 { return (.end, highGap) }
        return (.center, centerOffset)
    }
}
