import AppKit
import SwiftUI

// Controls drawn the way macOS draws its own, in the app's moss, so no screen
// mixes stock bezels painted in the Mac's accent colour with the palette.

/// Segmented control: a raised white segment on a sunken track, as AppKit
/// draws one, with arrow keys and VoiceOver to match.
struct FLSegmentedControl<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String
    var badge: (Option) -> Bool = { _ in false }
    var accessibilityLabel: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    select(option)
                } label: {
                    HStack(spacing: 6) {
                        Text(title(option))
                        if badge(option) {
                            // Amber: "needs your answer", as on the tab bar.
                            Circle().fill(Color.flWarningInk).frame(width: 6, height: 6)
                        }
                    }
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color.flTabSelectedInk : Color.flInkSoft)
                    .padding(.horizontal, 14)
                    .frame(height: 26)
                    // A selection is a place you are, so it is a raised chip
                    // rather than the page's one moss fill.
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: FLRadius.md, style: .continuous)
                                .fill(Color.flTabSelected)
                                .shadow(color: .black.opacity(0.14), radius: 2, y: 1)
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: FLRadius.md, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: FLRadius.md + 2, style: .continuous).fill(Color.flSunken))
        .fixedSize()
        // Arrow keys step through the choices, as in a stock segmented control.
        .onMoveCommand { direction in
            guard let index = options.firstIndex(of: selection) else { return }
            switch direction {
            case .left where index > 0: select(options[index - 1])
            case .right where index < options.count - 1: select(options[index + 1])
            default: break
            }
        }
        // VoiceOver hears one picker with its choices, not a row of buttons.
        .accessibilityRepresentation {
            Picker(accessibilityLabel, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(title(option)).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private func select(_ option: Option) {
        withAnimation(reduceMotion ? nil : FLAnimation.quick) {
            selection = option
        }
    }
}

/// A pop-up button: the value, the up-down chevron, and a menu of choices,
/// drawn as AppKit draws one but without the Mac's accent colour.
struct FLMenuPicker<Option: Hashable>: View {
    let options: [Option]
    let selection: Option?
    let title: (Option) -> String
    let onSelect: (Option) -> Void
    var placeholder = "Choose…"
    var width: CGFloat?
    var extraItems: AnyView?
    var accessibilityLabel: String

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    onSelect(option)
                } label: {
                    if option == selection {
                        Label(title(option), systemImage: "checkmark")
                    } else {
                        Text(title(option))
                    }
                }
            }
            if let extraItems {
                Divider()
                extraItems
            }
        } label: {
            HStack(spacing: 8) {
                Text(selection.map(title) ?? placeholder)
                    .font(FLTypography.body)
                    .foregroundStyle(selection == nil ? Color.flInkSoft : Color.flInk)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.flInkSoft)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(width: width)
            .background(
                RoundedRectangle(cornerRadius: FLRadius.md, style: .continuous)
                    .fill(Color.flField)
                    .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: FLRadius.md, style: .continuous)
                    .strokeBorder(Color.flFieldEdge, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        // `.borderlessButton` keeps only the label's text and draws its own
        // chrome; the button style with a plain button keeps the whole label.
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize(horizontal: width == nil, vertical: true)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(selection.map(title) ?? placeholder)
    }
}

/// Time of day in quarter hours, as minutes after midnight.
struct FLTimePicker: View {
    let label: String
    @Binding var minute: Int

    private static let options = Array(stride(from: 0, to: 24 * 60, by: 15))

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    static func title(for minute: Int) -> String {
        let date = Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(FLTypography.body)
                .foregroundStyle(Color.flInkSoft)
            FLMenuPicker(
                options: Self.options.contains(minute) ? Self.options : (Self.options + [minute]).sorted(),
                selection: minute,
                title: Self.title(for:),
                onSelect: { minute = $0 },
                width: 108,
                accessibilityLabel: label
            )
        }
    }
}

/// Minus and plus in one capsule, in place of the stock stepper arrows.
struct FLStepperButtons: View {
    let label: String
    let onDecrement: () -> Void
    let onIncrement: () -> Void
    var canDecrement = true
    var canIncrement = true

    var body: some View {
        HStack(spacing: 0) {
            step(systemImage: "minus", enabled: canDecrement, action: onDecrement)
                .accessibilityLabel("Decrease \(label.lowercased())")
            Rectangle().fill(Color.flFieldEdge).frame(width: 1, height: 16)
            step(systemImage: "plus", enabled: canIncrement, action: onIncrement)
                .accessibilityLabel("Increase \(label.lowercased())")
        }
        .background(RoundedRectangle(cornerRadius: FLRadius.md, style: .continuous).fill(Color.flField))
        .overlay(RoundedRectangle(cornerRadius: FLRadius.md, style: .continuous).strokeBorder(Color.flFieldEdge, lineWidth: 1))
    }

    private func step(systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(enabled ? Color.flInk : Color.flInkSoft.opacity(0.5))
                .frame(width: 28, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .buttonRepeatBehavior(.enabled)
    }
}

/// Small push button, for inline actions like Save or Test: a raised white
/// capsule, as a stock push button is.
struct FLInlineButtonStyle: ButtonStyle {
    var tint: Color = .flInk
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(isEnabled ? tint : Color.flInkSoft.opacity(0.55))
            .padding(.horizontal, 12)
            .frame(height: 26)
            .background(
                Capsule()
                    .fill(configuration.isPressed ? Color.flSunken : Color.flTabSelected)
                    .shadow(color: .black.opacity(isEnabled ? 0.06 : 0), radius: 1, y: 1)
            )
            .overlay(Capsule().strokeBorder(Color.flFieldEdge.opacity(0.8), lineWidth: 1))
            .contentShape(Capsule())
            .animation(FLAnimation.quick, value: configuration.isPressed)
    }
}
