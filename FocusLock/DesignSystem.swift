import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Colors
//
// A Mac window, not a painted page: one soft grey-green canvas behind every
// page, never paper white, with moss as the single accent. Nothing sits in a
// box: sections lie on the canvas and hairlines divide them. After dark the
// canvas goes charcoal. Every colour resolves against the appearance it is drawn in, so
// the Settings choice, the system setting, and each overlay window all follow
// along.

enum FLColor {
    static let accent = dynamic(light: "#618C69", dark: "#7FAE88")
    static let accentDeep = dynamic(light: "#3B6148", dark: "#8DBB97")
    static let accentSoft = dynamic(light: "#E3ECE1", dark: "#26332A")
    /// Words and glyphs on a moss fill: white by day, near-black on the
    /// lighter moss after dark.
    static let onAccent = dynamic(light: "#FFFFFF", dark: "#122016")

    /// The window itself, the same on every page. A soft grey with moss in
    /// it, never paper white: the window is looked at for hours.
    static let canvas = dynamic(light: "#E5E7E1", dark: "#1C1D1C")
    /// Pop-overs, hover cards and the selected segment: one step towards
    /// you, still well short of white.
    static let surface = dynamic(light: "#EFF1EB", dark: "#272927")

    static let ink = dynamic(light: "#1D211E", dark: "#F2F2EF")
    /// Secondary text. Ink thinned rather than a fixed grey, so it holds
    /// 4.5:1 on the canvas and on a card alike.
    static let inkSoft = dynamic(light: "#1D211E", dark: "#F2F2EF", alpha: (0.68, 0.62), increasedContrast: (0.86, 0.86))
    /// Dividers and card edges.
    static let hairline = dynamic(light: "#1D211E", dark: "#FFFFFF", alpha: (0.1, 0.1), increasedContrast: (0.4, 0.4))

    /// Text fields: white on a white card, as AppKit's own are, with a
    /// hairline edge doing the separating. After dark, a lift off the card.
    static let field = dynamic(light: "#F7F8F4", dark: "#FFFFFF", alpha: (1, 0.07))
    /// The edge of a field or pop-up: firmer than a hairline, because it
    /// marks something you can type in or click.
    static let fieldEdge = dynamic(light: "#1D211E", dark: "#FFFFFF", alpha: (0.17, 0.14), increasedContrast: (0.5, 0.5))
    static let clay = dynamic(light: "#B87355", dark: "#D4906F")
    /// Breaks. A cool slate, so a break never reads as more focus.
    static let rest = dynamic(light: "#56788B", dark: "#8EB1C4")
    /// A card during a break: the surface with a breath of slate in it.
    static let restSurface = dynamic(light: "#E8EEF0", dark: "#232A2E")

    /// Clay, amber and slate as text and glyphs. The fill values above read
    /// as colour but fall under 4.5:1 as words, so light mode writes in a
    /// deeper shade of each; dark mode already clears it.
    static let clayInk = dynamic(light: "#8A4A30", dark: "#D4906F")
    static let warningInk = dynamic(light: "#76531E", dark: "#D2A862")
    static let restInk = dynamic(light: "#3E5E70", dark: "#8EB1C4")

    static let success = accentDeep
    static let warning = dynamic(light: "#B8874A", dark: "#D2A862")
    static let destructive = clay

    /// A shade pressed into whatever is behind it: tracks, wells, hovered
    /// rows.
    static let sunken = dynamic(light: "#1D211E", dark: "#FFFFFF", alpha: (0.055, 0.07))

    /// The selected tab or segment: a raised white chip on a sunken track,
    /// as in a stock segmented control.
    static let tabSelected = dynamic(light: "#F7F8F4", dark: "#4A4D4A")
    static let tabSelectedInk = dynamic(light: "#1D211E", dark: "#F2F2EF")

    /// - Parameter increasedContrast: alphas to use instead when Increase
    ///   Contrast is on, for the translucent neutrals whose faintness is a
    ///   choice rather than a need.
    static func dynamic(
        light: String,
        dark: String,
        alpha: (light: CGFloat, dark: CGFloat) = (1, 1),
        increasedContrast: (light: CGFloat, dark: CGFloat)? = nil
    ) -> NSColor {
        let lightColor = NSColor(hex: light).withAlphaComponent(alpha.light)
        let darkColor = NSColor(hex: dark).withAlphaComponent(alpha.dark)
        let strong = increasedContrast ?? alpha
        let lightStrong = NSColor(hex: light).withAlphaComponent(strong.light)
        let darkStrong = NSColor(hex: dark).withAlphaComponent(strong.dark)
        return NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [
                .aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua,
            ])
            let isDark = match == .darkAqua || match == .accessibilityHighContrastDarkAqua
            let isStrong = match == .accessibilityHighContrastAqua || match == .accessibilityHighContrastDarkAqua
                || NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
            switch (isDark, isStrong) {
            case (false, false): return lightColor
            case (true, false): return darkColor
            case (false, true): return lightStrong
            case (true, true): return darkStrong
            }
        }
    }
}

extension Color {
    static let flAccent = Color(nsColor: FLColor.accent)
    static let flAccentDeep = Color(nsColor: FLColor.accentDeep)
    static let flAccentSoft = Color(nsColor: FLColor.accentSoft)
    static let flOnAccent = Color(nsColor: FLColor.onAccent)
    static let flCanvas = Color(nsColor: FLColor.canvas)
    static let flSurface = Color(nsColor: FLColor.surface)
    static let flInk = Color(nsColor: FLColor.ink)
    static let flInkSoft = Color(nsColor: FLColor.inkSoft)
    static let flHairline = Color(nsColor: FLColor.hairline)
    static let flField = Color(nsColor: FLColor.field)
    static let flFieldEdge = Color(nsColor: FLColor.fieldEdge)
    static let flClay = Color(nsColor: FLColor.clay)
    static let flRest = Color(nsColor: FLColor.rest)
    static let flRestSurface = Color(nsColor: FLColor.restSurface)
    static let flDestructive = Color(nsColor: FLColor.destructive)
    static let flWarning = Color(nsColor: FLColor.warning)
    static let flClayInk = Color(nsColor: FLColor.clayInk)
    static let flWarningInk = Color(nsColor: FLColor.warningInk)
    static let flRestInk = Color(nsColor: FLColor.restInk)
    static let flSunken = Color(nsColor: FLColor.sunken)
    static let flTabSelected = Color(nsColor: FLColor.tabSelected)
    static let flTabSelectedInk = Color(nsColor: FLColor.tabSelectedInk)
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
    static let sm: CGFloat = 5
    static let md: CGFloat = 7
    static let lg: CGFloat = 10
    static let xl: CGFloat = 14
    /// Cards: large and continuous, like a macOS window's own corners.
    static let card: CGFloat = 16
}

// MARK: - Spacing

enum FLSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

/// Page geometry shared by every page of the main window.
enum FLLayout {
    /// From the window edge to a page's content.
    static let pageInset: CGFloat = 28
    /// Above and below the content of a band, between its hairlines.
    static let bandPadding: CGFloat = 22
    /// Between two columns of a band, either side of their hairline.
    static let columnGap: CGFloat = 24
}

// MARK: - Typography
//
// SF Pro throughout, as on the rest of the Mac. Hierarchy comes from weight
// and size together: bold page titles, semibold headings, regular body, and
// secondary text in the thinned ink rather than smaller still. Anything
// that counts uses tabular digits, so numbers never jitter as they change.

enum FLTypography {
    /// The countdown. Bold, so the time reads from across the room.
    static func timer(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold).monospacedDigit()
    }

    static let timerLarge = timer(88)
    static let timerOverlay = timer(64)
    static let timerHUD = timer(30)
    /// Page titles.
    static let largeTitle = Font.system(size: 26, weight: .bold)
    /// Sheet titles and empty states.
    static let display = Font.system(size: 20, weight: .bold)
    /// Card headings.
    static let title = Font.system(size: 15, weight: .semibold)
    /// The number a stat tile is about.
    static let figure = Font.system(size: 24, weight: .bold).monospacedDigit()
    static let headline = Font.system(size: 13, weight: .semibold)
    static let body = Font.system(size: 13)
    /// Descriptions under a row's title.
    static let callout = Font.system(size: 12)
    static let caption = Font.system(size: 11.5)
    /// Table column headings and chart axes.
    static let micro = Font.system(size: 11, weight: .medium)
}

// MARK: - Animation

enum FLAnimation {
    static let quick = Animation.easeOut(duration: 0.16)
    static let standard = Animation.easeOut(duration: 0.22)
    static let entrance = Animation.easeOut(duration: 0.28)
    /// Things that move between places, like the selected tab: critically
    /// damped, so they arrive without bouncing.
    static let move = Animation.spring(response: 0.32, dampingFraction: 1)
}

// MARK: - Bands
//
// A page is a stack of bands lying on the canvas, divided by full-width
// hairlines. No boxes: the hairline and the air around it are the structure.

extension View {
    /// A band of a page: inset from the window's sides, with air above and
    /// below. Put an `FLRule` between bands.
    func flBand(vertical: CGFloat = FLLayout.bandPadding) -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, FLLayout.pageInset)
            .padding(.vertical, vertical)
    }
}

/// The hairline between two columns of a band.
struct FLColumnRule: View {
    var body: some View {
        Rectangle()
            .fill(Color.flHairline)
            .frame(width: 1)
    }
}

extension View {
    /// Fades a scroll view's content out at its edges instead of cutting it,
    /// so what passes under the header reads as scrolled, not sliced. Give
    /// the content at least this much padding at each end.
    func flScrollEdges(top: CGFloat = 10, bottom: CGFloat = 22) -> some View {
        mask(
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: top)
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: bottom)
            }
        )
    }
}

/// A page's title, what the page holds, and the page's own action on the
/// right.
struct FLPageHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: FLSpacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(FLTypography.largeTitle)
                    .foregroundStyle(Color.flInk)
                    .accessibilityAddTraits(.isHeader)

                if let subtitle {
                    Text(subtitle)
                        .font(FLTypography.callout)
                        .foregroundStyle(Color.flInkSoft)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: FLSpacing.md)

            trailing()
        }
        .padding(.horizontal, FLLayout.pageInset)
        .padding(.top, 14)
        .padding(.bottom, 18)
    }
}

extension FLPageHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// A group of settings: a heading, then its rows lying on the canvas with
/// hairlines between them, and a footnote under the last. Put an
/// `FLRowDivider` between rows.
struct FLGroup<Content: View>: View {
    var title: String?
    var footer: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title {
                Text(title)
                    .font(FLTypography.title)
                    .foregroundStyle(Color.flInk)
                    .padding(.bottom, 2)
                    .accessibilityAddTraits(.isHeader)
            }

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let footer {
                Text(footer)
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flInkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The hairline between two rows of a group or a table.
struct FLRowDivider: View {
    var inset: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(Color.flHairline)
            .frame(height: 1)
            .padding(.horizontal, inset)
    }
}

/// One setting: what it is and what it does on the left, its control on the
/// right.
struct FLSettingRow<Control: View>: View {
    let title: String
    var detail: String?
    @ViewBuilder var control: () -> Control

    var body: some View {
        HStack(alignment: .center, spacing: FLSpacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(FLTypography.body)
                    .foregroundStyle(Color.flInk)
                    .fixedSize(horizontal: false, vertical: true)

                if let detail {
                    Text(detail)
                        .font(FLTypography.callout)
                        .foregroundStyle(Color.flInkSoft)
                        .lineSpacing(1.5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            control()
        }
        .padding(.vertical, 11)
        .frame(minHeight: 44)
    }
}

/// A setting that is on or off, with a stock switch in the accent.
struct FLToggleRow: View {
    let title: String
    var detail: String?
    @Binding var isOn: Bool

    var body: some View {
        FLSettingRow(title: title, detail: detail) {
            FLSwitch(isOn: $isOn, label: title)
        }
    }
}

/// The stock switch, at the size System Settings uses, tinted moss.
struct FLSwitch: View {
    @Binding var isOn: Bool
    let label: String

    var body: some View {
        Toggle(label, isOn: $isOn)
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(Color.flAccentDeep)
            .labelsHidden()
    }
}

/// A heading inside a card: sentence case and semibold, the way macOS
/// labels a group.
struct FLSectionLabel: View {
    let text: String
    var tint: Color = .flInk

    var body: some View {
        Text(text)
            .font(FLTypography.title)
            .foregroundStyle(tint)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A heading over a column of a table.
struct FLColumnLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(FLTypography.micro)
            .foregroundStyle(Color.flInkSoft)
    }
}

/// A section's heading with a figure or detail on the right.
struct FLSectionHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: FLSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                FLSectionLabel(text: title)
                if let subtitle {
                    Text(subtitle)
                        .font(FLTypography.callout)
                        .foregroundStyle(Color.flInkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: FLSpacing.sm)
            trailing()
        }
    }
}

extension FLSectionHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// One number and what it counts, set as type. A row of them is divided by
/// `FLColumnRule`s, not boxed.
struct FLFigure: View {
    let label: String
    let value: String
    var detail: String?
    var valueTint: Color = .flInk

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(FLTypography.micro)
                .foregroundStyle(Color.flInkSoft)
                .lineLimit(1)

            Text(value)
                .font(FLTypography.figure)
                .foregroundStyle(valueTint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let detail {
                Text(detail)
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flInkSoft)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Something that needs an answer: a tinted panel with its glyph, the words,
/// and the one action that settles it.
struct FLCallout<Actions: View>: View {
    enum Tone {
        case info
        case warning
        case problem

        var tint: Color {
            switch self {
            case .info: return .flAccentDeep
            case .warning: return .flWarningInk
            case .problem: return .flClayInk
            }
        }

        var fill: Color {
            switch self {
            case .info: return Color.flAccentSoft.opacity(0.7)
            case .warning: return Color.flWarning.opacity(0.13)
            case .problem: return Color.flClay.opacity(0.11)
            }
        }
    }

    let tone: Tone
    let systemImage: String
    let title: String
    var detail: String?
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        HStack(alignment: detail == nil ? .center : .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(tone.tint)
                .frame(width: 16)
                .accessibilityHidden(true)

            if let detail {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(FLTypography.headline)
                        .foregroundStyle(Color.flInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detail)
                        .font(FLTypography.callout)
                        .foregroundStyle(Color.flInkSoft)
                        .lineSpacing(1.5)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: FLSpacing.md) {
                        actions()
                    }
                    .padding(.top, 4)
                }
                Spacer(minLength: 0)
            } else {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Color.flInk)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: FLSpacing.sm)
                actions()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tone.fill, in: RoundedRectangle(cornerRadius: FLRadius.lg, style: .continuous))
    }
}

// MARK: - Shared components

/// Full-width hairline, for the few dividers that run edge to edge.
struct FLRule: View {
    var body: some View {
        Rectangle()
            .fill(Color.flHairline)
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
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.flSunken))
            .overlay(
                Capsule().strokeBorder(borderTint ?? .clear, lineWidth: 1)
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
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(Color.flInkSoft.opacity(0.55))
                .padding(.bottom, 4)

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.flInk)

            Text(detail)
                .font(FLTypography.callout)
                .foregroundStyle(Color.flInkSoft)
                .lineSpacing(1.5)
                .frame(maxWidth: 320)
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
    /// Recolours a secondary button, as slate does for a break's own actions.
    var tint: Color?
    /// Stretches the capsule to the width it is offered.
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        StyledLabel(style: self, configuration: configuration)
    }

    /// A view, so it can read whether the button is enabled: a disabled
    /// button must not look pressable, least of all the page's one filled
    /// one.
    private struct StyledLabel: View {
        let style: FLActionButtonStyle
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.colorScheme) private var colorScheme

        var body: some View {
            let pressed = configuration.isPressed && isEnabled
            let isChromeless = style.variant == .quiet || style.variant == .destructiveQuiet
            configuration.label
                .font(.system(size: style.minHeight >= 40 ? 14 : 13, weight: style.variant == .quiet ? .medium : .semibold))
                .foregroundStyle(isEnabled ? style.foreground : Color.flInkSoft.opacity(0.6))
                .lineLimit(1)
                .padding(.horizontal, isChromeless ? FLSpacing.sm + 2 : (style.minHeight >= 40 ? 22 : 16))
                .frame(maxWidth: style.fullWidth ? .infinity : nil)
                .frame(minHeight: style.minHeight)
                .background {
                    if !isChromeless {
                        Capsule()
                            .fill(isEnabled ? style.background(isPressed: pressed) : Color.flSunken)
                            .shadow(
                                color: .black.opacity(isEnabled && colorScheme != .dark ? (style.variant == .primary ? 0.16 : 0.05) : 0),
                                radius: style.variant == .primary ? 5 : 2,
                                y: style.variant == .primary ? 2 : 1
                            )
                    } else if pressed {
                        Capsule().fill(Color.flSunken)
                    }
                }
                .overlay {
                    if !isChromeless && style.variant != .primary {
                        Capsule().strokeBorder(Color.flHairline, lineWidth: 1)
                    }
                }
                .contentShape(Capsule())
                .scaleEffect(pressed && !isChromeless ? 0.98 : 1)
                .animation(.easeOut(duration: 0.1), value: pressed)
                .animation(FLAnimation.quick, value: isEnabled)
        }
    }

    fileprivate var foreground: Color {
        switch variant {
        case .primary:
            return .flOnAccent
        case .secondary:
            return tint ?? .flInk
        case .destructive, .destructiveQuiet:
            return .flClayInk
        case .quiet:
            return tint ?? .flInkSoft
        }
    }

    fileprivate func background(isPressed: Bool) -> Color {
        switch variant {
        case .primary:
            return isPressed ? .flAccent : .flAccentDeep
        case .secondary, .destructive:
            return isPressed ? Color.flTabSelected.opacity(0.7) : .flTabSelected
        case .quiet, .destructiveQuiet:
            return .clear
        }
    }
}

/// A text button: the label in the accent with no chrome, the way macOS sets
/// "Learn More…" or "Open Settings". Never underlined; it is a button.
struct FLLinkButtonStyle: ButtonStyle {
    var tint: Color = .flAccentDeep

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(tint)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.55 : 1)
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
                // Not installed (or renamed): the system's plain app icon,
                // which reads as "an app" rather than as something broken.
                Image(nsImage: Self.genericIcon)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .opacity(0.7)
            }
        }
        .frame(width: size, height: size)
        .opacity(isDimmed ? 0.4 : 1)
        .accessibilityHidden(true)
    }

    private static var cache: [String: NSImage] = [:]
    private static let genericIcon = NSWorkspace.shared.icon(for: .applicationBundle)

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
                    .padding(2)
                    .background(
                        // Cuts a gap around each icon whatever colour the page
                        // behind it is.
                        RoundedRectangle(cornerRadius: FLRadius.md + 2, style: .continuous)
                            .blendMode(.destinationOut)
                    )
                    .padding(-2)
            }

            if apps.count > 4 {
                Text("+\(apps.count - 4)")
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(Color.flInkSoft)
                    .frame(width: size, height: size)
                    .background(Circle().fill(Color.flHairline))
                    .padding(2)
                    .background(Circle().blendMode(.destinationOut))
                    .padding(-2)
            }
        }
        .compositingGroup()
    }
}

/// Weekly rhythm chart: bars on a shared baseline, today emphasised.
struct FLWeeklyRhythm: View {
    let days: [DailyFocusColumn]
    /// Each bar is measured against this, drawn as a dotted line.
    let goalMinutes: Int
    var height: CGFloat = 96

    struct DailyFocusColumn: Identifiable {
        let id: Date
        /// "Mon".
        let label: String
        /// "Monday", for the hover card.
        let dayName: String
        let minutes: Int
        let sessions: Int
        /// Every category that day with its minutes, the most time first.
        let categories: [(name: String, minutes: Int)]
        let isToday: Bool
        let isFuture: Bool
    }

    private static let barWidth: CGFloat = 30
    /// Room above the tallest bar for its value.
    private static let valueRoom: CGFloat = 18
    /// Right-hand gutter for the goal label.
    private static let gutter: CGFloat = 40

    @State private var hovered: Date?
    @Environment(\.colorSchemeContrast) private var contrast

    /// The goal, or the best day if that went past it, so every bar fits.
    private var scale: Int {
        max(goalMinutes, days.map(\.minutes).max() ?? 0, 1)
    }

    private var goalOffset: CGFloat {
        height * CGFloat(goalMinutes) / CGFloat(scale)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 0) {
                ZStack(alignment: .bottom) {
                    goalLine
                    HStack(alignment: .bottom, spacing: 0) {
                        ForEach(days) { day in
                            column(day)
                                .frame(maxWidth: .infinity)
                                .zIndex(hovered == day.id ? 1 : 0)
                        }
                    }
                }

                Text(Self.duration(goalMinutes))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Color.flInkSoft)
                    .frame(width: Self.gutter, alignment: .leading)
                    .padding(.leading, 6)
                    .padding(.bottom, goalOffset - 6)
                    .accessibilityLabel("Daily goal \(Self.duration(goalMinutes))")
            }
            .frame(height: height + Self.valueRoom, alignment: .bottom)

            Rectangle()
                .fill(Color.flHairline)
                .frame(height: 1)
                .padding(.trailing, Self.gutter + 6)

            HStack(spacing: 0) {
                ForEach(days) { day in
                    Text(day.label)
                        .font(.system(size: 11, weight: day.isToday ? .semibold : .regular))
                        .foregroundStyle(labelColor(day))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.trailing, Self.gutter + 6)
            .padding(.top, 7)
        }
    }

    private var goalLine: some View {
        Line()
            .stroke(Color.flInkSoft.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
            .frame(height: 1)
            .padding(.bottom, goalOffset)
            .accessibilityHidden(true)
    }

    private func column(_ day: DailyFocusColumn) -> some View {
        VStack(spacing: 4) {
            if !day.isFuture {
                Text(day.minutes > 0 ? Self.duration(day.minutes) : "–")
                    .font(.system(size: 11, weight: day.isToday ? .semibold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(day.isToday ? Color.flInk : Color.flInkSoft)
                    .fixedSize()
                    // The goal line runs behind a value, not through it.
                    .padding(.horizontal, 3)
                    .background(Color.flCanvas, in: Capsule())
            }
            bar(day)
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            if hovered == day.id {
                detailCard(day)
                    .padding(.bottom, barHeight(day) + 26)
                    .transition(.opacity)
            }
        }
        .onHover { inside in
            withAnimation(FLAnimation.quick) {
                hovered = inside ? day.id : (hovered == day.id ? nil : hovered)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(day))
    }

    @ViewBuilder
    private func bar(_ day: DailyFocusColumn) -> some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 5, topTrailingRadius: 5, style: .continuous)
        if day.isFuture {
            // An empty slot up to the goal: still to come, not zero.
            shape
                .stroke(Color.flHairline, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .frame(width: Self.barWidth, height: goalOffset)
        } else if day.minutes > 0 {
            shape
                .fill(day.isToday ? Color.flAccentDeep : Color.flAccent.opacity(contrast == .increased || hovered == day.id ? 1 : 0.5))
                .frame(width: Self.barWidth, height: barHeight(day))
        } else {
            Color.clear.frame(width: Self.barWidth, height: 0)
        }
    }

    private func barHeight(_ day: DailyFocusColumn) -> CGFloat {
        guard !day.isFuture, day.minutes > 0 else { return 0 }
        return max(4, height * CGFloat(day.minutes) / CGFloat(scale))
    }

    private func detailCard(_ day: DailyFocusColumn) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(day.isToday ? "Today" : day.dayName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.flInk)
            Text(detailLine(day))
                .font(.system(size: 11))
                .foregroundStyle(Color.flInkSoft)

            if !day.isFuture, !day.categories.isEmpty {
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 2) {
                    ForEach(day.categories, id: \.name) { category in
                        GridRow {
                            Text(category.name)
                                .foregroundStyle(Color.flInk)
                            Text(Self.duration(category.minutes))
                                .monospacedDigit()
                                .foregroundStyle(Color.flInkSoft)
                                .gridColumnAlignment(.trailing)
                        }
                        .font(.system(size: 11))
                    }
                }
                .padding(.top, 4)
            }
        }
        .fixedSize()
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: FLRadius.md, style: .continuous)
                .fill(Color.flSurface)
                .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: FLRadius.md, style: .continuous)
                .strokeBorder(Color.flHairline, lineWidth: 1)
        )
        .allowsHitTesting(false)
    }

    private func detailLine(_ day: DailyFocusColumn) -> String {
        if day.isFuture { return "Still to come" }
        guard day.sessions > 0 else { return "No focus" }
        let sessions = day.sessions == 1 ? "1 session" : "\(day.sessions) sessions"
        return "\(Self.duration(day.minutes)) · \(sessions)"
    }

    private func accessibilityText(_ day: DailyFocusColumn) -> String {
        let categories = day.categories.map { "\($0.name) \(Self.duration($0.minutes))" }
        return (["\(day.isToday ? "Today" : day.dayName): \(detailLine(day))"] + categories).joined(separator: ", ")
    }

    private func labelColor(_ day: DailyFocusColumn) -> Color {
        if day.isToday { return .flInk }
        return .flInkSoft
    }

    static func duration(_ minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes)m" }
        let remainder = minutes % 60
        return remainder == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(remainder)m"
    }

    /// A horizontal line across the full width, for dashing.
    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            Path { path in
                path.move(to: CGPoint(x: rect.minX, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            }
        }
    }
}

/// Small progress ring used in the HUD and menu bar tuck.
struct FLProgressRing: View {
    let progress: Double
    var size: CGFloat = 22
    var lineWidth: CGFloat = 2
    var tint: Color = .flAccentDeep
    var trackTint: Color = .flAccent

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackTint.opacity(0.22), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
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
        .accessibilityLabel(isRunning
            ? "Block \(completed + 1) running, \(completed) done today"
            : "\(completed) block\(completed == 1 ? "" : "s") done today")
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

/// The one text field look in the app.
///
/// A modifier rather than a `TextFieldStyle` because SwiftUI keeps property
/// wrappers alive inside a `ViewModifier`, which is what lets the border react
/// to focus. The ring is the app's accent; left to the system it would be
/// whatever accent colour the Mac happens to be set to.
private struct FLFieldChrome: ViewModifier {
    @FocusState private var isFocusedInternally: Bool

    let width: CGFloat?

    /// Passed in by fields that already own a focus binding of their own —
    /// attaching a second `.focused` to the same field fights the first.
    let externalFocus: Bool?

    private var isFocused: Bool { externalFocus ?? isFocusedInternally }

    func body(content: Content) -> some View {
        applyFocus(to: content.textFieldStyle(.plain))
            .font(FLTypography.body)
            .foregroundStyle(Color.flInk)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(width: width)
            .background(Color.flField, in: RoundedRectangle(cornerRadius: FLRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FLRadius.md, style: .continuous)
                    .strokeBorder(isFocused ? Color.flAccentDeep : Color.flFieldEdge,
                                  lineWidth: isFocused ? 1.5 : 1)
            )
            .animation(.easeOut(duration: 0.12), value: isFocused)
    }

    @ViewBuilder
    private func applyFocus(to content: some View) -> some View {
        if externalFocus == nil {
            content.focused($isFocusedInternally)
        } else {
            content
        }
    }
}

extension View {
    /// Use in place of `.textFieldStyle(.roundedBorder)`.
    func flField(width: CGFloat? = nil, focused: Bool? = nil) -> some View {
        modifier(FLFieldChrome(width: width, externalFocus: focused))
    }
}
