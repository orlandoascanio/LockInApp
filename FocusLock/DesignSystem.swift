import AppKit
import SwiftUI

// MARK: - Colors

enum FLColor {
    static let focus = NSColor(named: "FocusAccent", bundle: .module) ?? NSColor(hex: "#0ABFA3")
    static let focusPressed = NSColor(hex: "#088975")
    static let focusControl = NSColor(hex: "#076B5E")
    static let focusSubtle = focus.withAlphaComponent(0.10)
    static let focusSurface = focus.withAlphaComponent(0.16)

    static let success = NSColor.systemGreen
    static let warning = NSColor.systemOrange
    static let destructive = NSColor.systemRed

    static let textPrimary = NSColor.labelColor
    static let textSecondary = NSColor.secondaryLabelColor
    static let textTertiary = NSColor.tertiaryLabelColor
    static let separator = NSColor.separatorColor
    static let background = NSColor.windowBackgroundColor
    static let surface = NSColor.controlBackgroundColor
    static let elevatedSurface = NSColor.textBackgroundColor
}

// MARK: - Radius

enum FLRadius {
    static let sm: CGFloat = 6
    static let md: CGFloat = 10
    static let lg: CGFloat = 14
    static let xl: CGFloat = 18
    static let xxl: CGFloat = 22
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

enum FLTypography {
    static let timerLarge = Font.system(size: 58, weight: .bold, design: .rounded)
    static let timerOverlay = Font.system(size: 56, weight: .semibold, design: .rounded)
    static let display = Font.system(size: 34, weight: .semibold, design: .rounded)
    static let title = Font.title2.weight(.semibold)
    static let headline = Font.headline
    static let body = Font.body
    static let caption = Font.caption
    static let stat = Font.title.weight(.semibold)
}

// MARK: - Animation

enum FLAnimation {
    static let quick = Animation.easeOut(duration: 0.2)
    static let standard = Animation.easeOut(duration: 0.25)
    static let entrance = Animation.spring(response: 0.4, dampingFraction: 0.85)
}

// MARK: - Color helpers

extension Color {
    static let flFocus = Color(nsColor: FLColor.focus)
    static let flFocusPressed = Color(nsColor: FLColor.focusPressed)
    static let flFocusControl = Color(nsColor: FLColor.focusControl)
    static let flFocusSubtle = Color(nsColor: FLColor.focusSubtle)
    static let flFocusSurface = Color(nsColor: FLColor.focusSurface)
    static let flSuccess = Color(nsColor: FLColor.success)
    static let flWarning = Color(nsColor: FLColor.warning)
    static let flDestructive = Color(nsColor: FLColor.destructive)
    static let flTextPrimary = Color(nsColor: FLColor.textPrimary)
    static let flTextSecondary = Color(nsColor: FLColor.textSecondary)
    static let flTextTertiary = Color(nsColor: FLColor.textTertiary)
    static let flSeparator = Color(nsColor: FLColor.separator)
    static let flBackground = Color(nsColor: FLColor.background)
    static let flSurface = Color(nsColor: FLColor.surface)
    static let flElevatedSurface = Color(nsColor: FLColor.elevatedSurface)
}

extension NSColor {
    convenience init(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let number = UInt64(value, radix: 16)!

        self.init(
            red: CGFloat((number >> 16) & 0xFF) / 255,
            green: CGFloat((number >> 8) & 0xFF) / 255,
            blue: CGFloat(number & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Shared components

struct FLSectionHeader: View {
    let title: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: FLSpacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.flFocus)
                    .symbolRenderingMode(.hierarchical)
            }

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.flTextPrimary)
        }
    }
}

struct FLStatusPill: View {
    let label: String
    var accent: Bool = false
    var systemImage: String?

    var body: some View {
        HStack(spacing: FLSpacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.bold))
            }
            Text(label)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(accent ? Color.flFocus : Color.flTextSecondary)
        .padding(.horizontal, FLSpacing.sm)
        .padding(.vertical, FLSpacing.xs)
        .background(
            (accent ? Color.flFocusSurface : Color.primary.opacity(0.06)),
            in: Capsule()
        )
        .overlay(
            Capsule()
                .strokeBorder(accent ? Color.flFocus.opacity(0.25) : Color.flSeparator.opacity(0.45), lineWidth: 1)
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
                .font(.title)
                .foregroundStyle(Color.flTextTertiary)
                .symbolRenderingMode(.hierarchical)

            Text(title)
                .font(.headline)
                .foregroundStyle(Color.flTextPrimary)

            Text(detail)
                .font(.caption)
                .foregroundStyle(Color.flTextSecondary)
                .frame(maxWidth: 280)
        }
        .multilineTextAlignment(.center)
    }
}

struct FLStatCard: View {
    let value: String
    let label: String
    var systemImage: String?
    var accent: Color = .flFocus

    var body: some View {
        VStack(alignment: .leading, spacing: FLSpacing.md) {
            HStack(alignment: .top) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.headline)
                        .foregroundStyle(accent)
                        .frame(width: 28, height: 28)
                        .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: FLRadius.sm, style: .continuous))
                        .symbolRenderingMode(.hierarchical)
                }

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: FLSpacing.xs) {
                Text(value)
                    .font(FLTypography.stat)
                    .monospacedDigit()
                    .foregroundStyle(Color.flTextPrimary)

                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.flTextSecondary)
                    .lineLimit(2)
            }
        }
        .padding(FLSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.flSurface, in: RoundedRectangle(cornerRadius: FLRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FLRadius.lg, style: .continuous)
                .strokeBorder(Color.flSeparator.opacity(0.55), lineWidth: 1)
        )
    }
}

struct FLSubtleDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.flSeparator.opacity(0.5))
            .frame(height: 1)
    }
}

struct FLIconButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(FLActionButtonStyle(variant: .secondary))
        .controlSize(.regular)
    }
}

struct FLSurface<Content: View>: View {
    var padding: CGFloat = FLSpacing.md
    var radius: CGFloat = FLRadius.lg
    private let content: Content

    init(padding: CGFloat = FLSpacing.md, radius: CGFloat = FLRadius.lg, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.radius = radius
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(Color.flSurface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.flSeparator.opacity(0.55), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}

struct FLActionButtonStyle: ButtonStyle {
    enum Variant {
        case primary
        case secondary
        case destructive
        case quiet
        case destructiveQuiet
    }

    var variant: Variant = .secondary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, isQuiet ? FLSpacing.sm : FLSpacing.md)
            .frame(minHeight: isQuiet ? 36 : 44)
            .background(backgroundColor(isPressed: configuration.isPressed), in: RoundedRectangle(cornerRadius: FLRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FLRadius.md, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: variant == .primary ? 0 : 1)
            )
            .shadow(
                color: variant == .primary ? Color.flFocus.opacity(configuration.isPressed ? 0.10 : 0.22) : Color.clear,
                radius: configuration.isPressed ? 4 : 10,
                x: 0,
                y: configuration.isPressed ? 2 : 6
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(FLAnimation.quick, value: configuration.isPressed)
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary:
            return .white
        case .destructive:
            return .flDestructive
        case .destructiveQuiet:
            return .flDestructive
        case .secondary, .quiet:
            return .flTextPrimary
        }
    }

    private var borderColor: Color {
        switch variant {
        case .primary:
            return .clear
        case .destructive:
            return Color.flDestructive.opacity(0.35)
        case .destructiveQuiet:
            return Color.flDestructive.opacity(0.18)
        case .secondary, .quiet:
            return Color.flSeparator.opacity(0.6)
        }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        switch variant {
        case .primary:
            return isPressed ? .flFocusPressed : .flFocusControl
        case .destructive:
            return Color.flDestructive.opacity(isPressed ? 0.16 : 0.10)
        case .destructiveQuiet:
            return Color.flDestructive.opacity(isPressed ? 0.12 : 0.06)
        case .secondary:
            return Color.primary.opacity(isPressed ? 0.10 : 0.055)
        case .quiet:
            return Color.primary.opacity(isPressed ? 0.08 : 0.025)
        }
    }

    private var isQuiet: Bool {
        variant == .quiet || variant == .destructiveQuiet
    }
}
