import AppKit
import SwiftUI

// MARK: - Colors
//
// Sand canvas, moss accent, clay for anything you would regret. The palette is
// fixed rather than derived from the system appearance: LockIn's guard screen
// has to feel like the same paper every time it appears, whatever the OS theme
// is doing behind it.

enum FLColor {
    static let accent = NSColor(hex: "#618C69")
    static let accentDeep = NSColor(hex: "#3B6148")
    static let accentSoft = NSColor(hex: "#D9E0D1")
    static let canvas = NSColor(hex: "#F5F2E8")
    static let canvasWarm = NSColor(hex: "#EDE9D9")
    static let ink = NSColor(hex: "#293129")
    static let inkSoft = NSColor(hex: "#737B6E")
    static let hairline = NSColor(hex: "#CCC7B5")
    static let clay = NSColor(hex: "#B87355")

    static let success = accentDeep
    static let warning = NSColor(hex: "#B8874A")
    static let destructive = clay
}

extension Color {
    static let flAccent = Color(nsColor: FLColor.accent)
    static let flAccentDeep = Color(nsColor: FLColor.accentDeep)
    static let flAccentSoft = Color(nsColor: FLColor.accentSoft)
    static let flCanvas = Color(nsColor: FLColor.canvas)
    static let flCanvasWarm = Color(nsColor: FLColor.canvasWarm)
    static let flInk = Color(nsColor: FLColor.ink)
    static let flInkSoft = Color(nsColor: FLColor.inkSoft)
    static let flHairline = Color(nsColor: FLColor.hairline)
    static let flClay = Color(nsColor: FLColor.clay)
    static let flDestructive = Color(nsColor: FLColor.destructive)
    static let flWarning = Color(nsColor: FLColor.warning)
}

extension NSColor {
    convenience init(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let number = UInt64(value, radix: 16) ?? 0

        self.init(
            srgbRed: CGFloat((number >> 16) & 0xFF) / 255,
            green: CGFloat((number >> 8) & 0xFF) / 255,
            blue: CGFloat(number & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Radius

enum FLRadius {
    static let sm: CGFloat = 4
    static let md: CGFloat = 6
    static let lg: CGFloat = 10
    static let xl: CGFloat = 14
}

// MARK: - Spacing

enum FLSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

// MARK: - Typography
//
// Serif for anything numeric that the eye lands on — the countdown, durations,
// counts. Sans for labels and controls. Micro-caps with wide tracking stand in
// for section headers so the layout needs no boxes to separate its regions.

enum FLTypography {
    static func timer(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }

    static let timerLarge = timer(88)
    static let timerOverlay = timer(64)
    static let timerHUD = timer(30)
    static let display = Font.system(size: 22, weight: .regular, design: .serif)
    static let title = Font.system(size: 19, weight: .regular, design: .serif)
    static let headline = Font.system(size: 13, weight: .semibold)
    static let body = Font.system(size: 13)
    static let caption = Font.system(size: 11.5)
    static let micro = Font.system(size: 9.5, weight: .semibold)
}

// MARK: - Animation

enum FLAnimation {
    static let quick = Animation.easeOut(duration: 0.16)
    static let standard = Animation.easeOut(duration: 0.22)
    static let entrance = Animation.easeOut(duration: 0.28)
}

// MARK: - Shared components

/// Wide-tracked micro-caps label. Replaces boxed section headers.
struct FLMicroLabel: View {
    let text: String
    var tint: Color = .flInkSoft

    var body: some View {
        Text(text.uppercased())
            .font(FLTypography.micro)
            .tracking(1.6)
            .foregroundStyle(tint)
    }
}

/// Full-width hairline. The only separator in the design.
struct FLRule: View {
    var body: some View {
        Rectangle()
            .fill(Color.flHairline.opacity(0.7))
            .frame(height: 1)
    }
}

/// Outlined capsule used for behaviour and status badges.
struct FLBadge: View {
    let text: String
    var tint: Color = .flInkSoft
    var borderTint: Color?

    var body: some View {
        Text(text)
            .font(FLTypography.caption)
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .overlay(
                Capsule().strokeBorder(borderTint ?? Color.flHairline, lineWidth: 1)
            )
    }
}

struct FLEmptyState: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: FLSpacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Color.flInkSoft.opacity(0.6))

            Text(title)
                .font(FLTypography.display)
                .foregroundStyle(Color.flInk)

            Text(detail)
                .font(FLTypography.caption)
                .foregroundStyle(Color.flInkSoft)
                .frame(maxWidth: 300)
        }
        .multilineTextAlignment(.center)
    }
}

/// The one filled button per screen, plus its quieter companions.
struct FLActionButtonStyle: ButtonStyle {
    enum Variant {
        case primary
        case secondary
        case destructive
        case quiet
        case destructiveQuiet
    }

    var variant: Variant = .secondary
    var minHeight: CGFloat = 40

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13.5, weight: variant == .quiet ? .regular : .semibold))
            .foregroundStyle(foreground(isPressed: configuration.isPressed))
            .lineLimit(1)
            .padding(.horizontal, variant == .quiet ? FLSpacing.sm : 22)
            .frame(minHeight: minHeight)
            .background(background(isPressed: configuration.isPressed), in: Capsule())
            .overlay(Capsule().strokeBorder(border, lineWidth: 1.2))
            .contentShape(Capsule())
            .opacity(configuration.isPressed && variant == .quiet ? 0.6 : 1)
            .animation(FLAnimation.quick, value: configuration.isPressed)
    }

    private func foreground(isPressed: Bool) -> Color {
        switch variant {
        case .primary:
            return .flCanvas
        case .secondary:
            return .flAccentDeep
        case .destructive, .destructiveQuiet:
            return .flClay
        case .quiet:
            return .flInkSoft
        }
    }

    private func background(isPressed: Bool) -> Color {
        switch variant {
        case .primary:
            return isPressed ? .flAccent : .flAccentDeep
        case .secondary:
            return isPressed ? Color.flAccentSoft.opacity(0.5) : .clear
        case .destructive:
            return isPressed ? Color.flClay.opacity(0.12) : .clear
        case .quiet, .destructiveQuiet:
            return .clear
        }
    }

    private var border: Color {
        switch variant {
        case .primary:
            return .clear
        case .secondary:
            return Color.flAccentDeep.opacity(0.35)
        case .destructive:
            return Color.flClay.opacity(0.35)
        case .quiet, .destructiveQuiet:
            return .clear
        }
    }
}

/// Underlined text link — used where a control should not look like a button.
struct FLLinkButtonStyle: ButtonStyle {
    var tint: Color = .flAccentDeep

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13))
            .foregroundStyle(tint)
            .underline()
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// Real macOS app icon for a bundle id, with a neutral placeholder for apps
/// that are not installed (or were renamed) so rows never collapse.
struct FLAppIcon: View {
    let bundleId: String
    var size: CGFloat = 26
    var isDimmed: Bool = false

    var body: some View {
        Group {
            if let icon = Self.icon(for: bundleId) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                RoundedRectangle(cornerRadius: FLRadius.md, style: .continuous)
                    .fill(Color.flHairline.opacity(0.55))
                    .overlay(
                        Image(systemName: "questionmark")
                            .font(.system(size: size * 0.42, weight: .medium))
                            .foregroundStyle(Color.flInkSoft)
                    )
            }
        }
        .frame(width: size, height: size)
        .opacity(isDimmed ? 0.4 : 1)
        .accessibilityHidden(true)
    }

    private static var cache: [String: NSImage] = [:]

    private static func icon(for bundleId: String) -> NSImage? {
        if let cached = cache[bundleId] {
            return cached
        }

        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return nil
        }

        let icon = NSWorkspace.shared.icon(forFile: url.path)
        cache[bundleId] = icon
        return icon
    }
}

/// Overlapping icon stack used to summarise the guarded list in one line.
struct FLAppPile: View {
    let apps: [BlockedAppSummary]
    var size: CGFloat = 24

    struct BlockedAppSummary: Identifiable {
        let id: String
        let bundleId: String
    }

    var body: some View {
        HStack(spacing: -size * 0.29) {
            ForEach(apps.prefix(4)) { app in
                FLAppIcon(bundleId: app.bundleId, size: size)
                    .background(
                        RoundedRectangle(cornerRadius: FLRadius.md, style: .continuous)
                            .fill(Color.flCanvas)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: FLRadius.md, style: .continuous)
                            .strokeBorder(Color.flCanvas, lineWidth: 2)
                    )
            }

            if apps.count > 4 {
                Text("+\(apps.count - 4)")
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(Color.flInkSoft)
                    .frame(width: size, height: size)
                    .background(Circle().fill(Color.flCanvasWarm))
                    .overlay(Circle().strokeBorder(Color.flCanvas, lineWidth: 2))
            }
        }
    }
}

/// Weekly rhythm chart: bars on a shared baseline, today emphasised.
struct FLWeeklyRhythm: View {
    let days: [DailyFocusColumn]
    var height: CGFloat = 62

    struct DailyFocusColumn: Identifiable {
        let id: Date
        let label: String
        let minutes: Int
        let isToday: Bool
    }

    private var peak: Int {
        max(days.map(\.minutes).max() ?? 0, 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(days) { day in
                    Rectangle()
                        .fill(day.isToday ? Color.flAccentDeep : Color.flAccent.opacity(0.5))
                        .frame(height: barHeight(for: day))
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("\(day.label): \(day.minutes) focus minutes")
                }
            }
            .frame(height: height, alignment: .bottom)

            Rectangle().fill(Color.flHairline).frame(height: 1)

            HStack(spacing: 12) {
                ForEach(days) { day in
                    Text(day.label)
                        .font(.system(size: 10, weight: day.isToday ? .semibold : .regular))
                        .foregroundStyle(day.isToday ? Color.flInk : Color.flInkSoft)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 7)
        }
    }

    private func barHeight(for day: DailyFocusColumn) -> CGFloat {
        guard day.minutes > 0 else {
            return 2
        }
        return max(3, height * CGFloat(day.minutes) / CGFloat(peak))
    }
}

/// Small progress ring used in the HUD and menu bar tuck.
struct FLProgressRing: View {
    let progress: Double
    var size: CGFloat = 22
    var lineWidth: CGFloat = 2

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.flAccent.opacity(0.22), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(Color.flAccentDeep, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Session beads: how many blocks are done, which one is running.
struct FLSessionBeads: View {
    let total: Int
    let completed: Int
    var isRunning: Bool

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(1, total), id: \.self) { index in
                Capsule()
                    .fill(fill(for: index))
                    .frame(width: isCurrent(index) ? 26 : 16, height: 3)
            }
        }
        .accessibilityLabel("Session \(min(completed + 1, total)) of \(total)")
    }

    private func isCurrent(_ index: Int) -> Bool {
        isRunning && index == completed
    }

    private func fill(for index: Int) -> Color {
        if index < completed {
            return .flAccentDeep
        }
        if isCurrent(index) {
            return .flAccent
        }
        return .flHairline
    }
}
