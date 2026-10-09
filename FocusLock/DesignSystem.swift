import AppKit
import SwiftUI

// MARK: - Colors
//
// Sand canvas, moss accent, clay for anything you would regret — and after
// dark, the same moss on charcoal rather than a white window at midnight.
// Every colour resolves against the appearance it is drawn in, so the Settings
// choice, the system setting, and each overlay window all follow along.

enum FLColor {
    static let accent = dynamic(light: "#618C69", dark: "#7FAE88")
    static let accentDeep = dynamic(light: "#3B6148", dark: "#8DBB97")
    static let accentSoft = dynamic(light: "#D9E0D1", dark: "#27352C")
    static let canvas = dynamic(light: "#F5F2E8", dark: "#1A201C")
    static let canvasWarm = dynamic(light: "#EDE9D9", dark: "#151A17")
    static let ink = dynamic(light: "#293129", dark: "#E9E5D9")
    static let inkSoft = dynamic(light: "#737B6E", dark: "#9AA295")
    static let hairline = dynamic(light: "#CCC7B5", dark: "#343C36")

    /// Fields sit a shade above the canvas rather than being punched out of it
    /// in white. AppKit's stock rounded-border field is pure white, which on a
    /// sand page reads as a hole.
    static let field = dynamic(light: "#FBF9F1", dark: "#222924")
    static let clay = dynamic(light: "#B87355", dark: "#D4906F")
    /// Breaks. A cool slate, so a break never reads as more focus.
    static let rest = dynamic(light: "#56788B", dark: "#8EB1C4")

    static let success = accentDeep
    static let warning = dynamic(light: "#B8874A", dark: "#D2A862")
    static let destructive = clay

    private static func dynamic(light: String, dark: String) -> NSColor {
        let lightColor = NSColor(hex: light)
        let darkColor = NSColor(hex: dark)
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? darkColor : lightColor
        }
    }
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
    static let flField = Color(nsColor: FLColor.field)
    static let flClay = Color(nsColor: FLColor.clay)
    static let flRest = Color(nsColor: FLColor.rest)
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
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Color.flInkSoft.opacity(0.8))
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
                        .font(.system(size: 10.5, weight: day.isToday ? .semibold : .regular))
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
                    .font(.system(size: 10.5, weight: day.isToday ? .semibold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(day.isToday ? Color.flInk : Color.flInkSoft)
                    .fixedSize()
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
                .fill(day.isToday ? Color.flAccentDeep : Color.flAccent.opacity(hovered == day.id ? 0.75 : 0.5))
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
                .fill(Color.flCanvas)
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
        return day.isFuture ? Color.flInkSoft.opacity(0.55) : .flInkSoft
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
                    .strokeBorder(isFocused ? Color.flAccent : Color.flHairline,
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
