import AppKit
import SwiftUI

// Controls in the app's own look, so no screen mixes stock AppKit bezels with
// the palette's capsules and fields.

/// Capsule segmented control. Replaces `Picker(.segmented)`, whose selection is
/// painted in the Mac's accent colour rather than the palette's.
struct FLSegmentedControl<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String
    var badge: (Option) -> Bool = { _ in false }
    var accessibilityLabel: String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    withAnimation(FLAnimation.quick) {
                        selection = option
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(title(option))
                        if badge(option) {
                            Circle().fill(Color.flClay).frame(width: 6, height: 6)
                        }
                    }
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.flCanvas : Color.flInkSoft)
                    .padding(.horizontal, 16)
                    .frame(height: 28)
                    .background(Capsule().fill(isSelected ? Color.flAccentDeep : .clear))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.flCanvasWarm))
        .overlay(Capsule().strokeBorder(Color.flHairline, lineWidth: 1))
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// A dropdown that looks like the app's fields: the value, a chevron, and a
/// menu of choices. Replaces the stock pop-up button.
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
            .padding(.vertical, 7)
            .frame(width: width)
            .background(Color.flField, in: RoundedRectangle(cornerRadius: FLRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FLRadius.md, style: .continuous)
                    .strokeBorder(Color.flHairline, lineWidth: 1)
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
            Rectangle().fill(Color.flHairline).frame(width: 1, height: 16)
            step(systemImage: "plus", enabled: canIncrement, action: onIncrement)
                .accessibilityLabel("Increase \(label.lowercased())")
        }
        .background(Capsule().fill(Color.flField))
        .overlay(Capsule().strokeBorder(Color.flHairline, lineWidth: 1))
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

/// Small text button in the palette, for inline actions like Save or Test.
struct FLInlineButtonStyle: ButtonStyle {
    var tint: Color = .flAccentDeep
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(isEnabled ? tint : Color.flInkSoft.opacity(0.55))
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(Capsule().fill(configuration.isPressed ? Color.flAccentSoft : .clear))
            .overlay(Capsule().strokeBorder(isEnabled ? tint.opacity(0.35) : Color.flHairline, lineWidth: 1))
            .contentShape(Capsule())
            .animation(FLAnimation.quick, value: configuration.isPressed)
    }
}

/// The sidebar's native material: desktop colour showing through, as in
/// Finder and Mail, with a wash of the palette so it stays warm rather than
/// turning grey.
struct FLSidebarBackground: View {
    var body: some View {
        ZStack {
            VisualEffect(material: .sidebar, blendingMode: .behindWindow)
            Color.flCanvasWarm.opacity(0.62)
        }
        .ignoresSafeArea()
    }

    private struct VisualEffect: NSViewRepresentable {
        let material: NSVisualEffectView.Material
        let blendingMode: NSVisualEffectView.BlendingMode

        func makeNSView(context: Context) -> NSVisualEffectView {
            let view = NSVisualEffectView()
            view.material = material
            view.blendingMode = blendingMode
            view.state = .followsWindowActiveState
            return view
        }

        func updateNSView(_ view: NSVisualEffectView, context: Context) {
            view.material = material
            view.blendingMode = blendingMode
        }
    }
}
