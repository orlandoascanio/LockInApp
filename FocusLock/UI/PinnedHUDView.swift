import AppKit
import FocusLockCore
import SwiftUI

/// What the HUD is telling you at a glance, which sets its colour.
enum HUDTone: Equatable {
    case focus
    case rest
    /// The last minute of either phase.
    case finalMinute

    var tint: Color {
        switch self {
        case .focus: return .flAccentDeep
        case .rest: return .flRest
        case .finalMinute: return .flWarning
        }
    }

    /// Words and digits: the deeper shade of each, which stays readable as
    /// text where the fill colour would not.
    var digits: Color {
        switch self {
        case .focus: return .flInk
        case .rest: return .flRestInk
        case .finalMinute: return .flWarningInk
        }
    }
}

/// Live content for the floating HUD. Kept separate from the controller so the
/// window can be built once and simply re-fed as the session ticks.
final class PinnedHUDModel: ObservableObject {
    @Published var countdown: String = "--:--"
    @Published var phaseLabel: String = ""
    @Published var goal: String?
    @Published var progress: Double = 0
    @Published var canEnd: Bool = true
    @Published var tone: HUDTone = .focus
    @Published var isExpanded = false
    @Published var showsControls = false
    /// Bumped to play the pulse once.
    @Published var pulseCount = 0
}

/// The always-on-top HUD. At rest it is a small pill with the ring and the
/// time; expanded it adds the phase and the goal, and the controls while the
/// pointer is over it. The controller sizes the window to match.
struct PinnedHUDView: View {
    static let compactSize = CGSize(width: 128, height: 32)
    static let expandedSize = CGSize(width: 380, height: 52)

    @ObservedObject var model: PinnedHUDModel

    let onEnd: () -> Void
    let menu: () -> NSMenu

    @State private var pulse = 0.0

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: model.isExpanded ? FLRadius.xl : Self.compactSize.height / 2, style: .continuous)

        Group {
            if model.isExpanded {
                expanded
            } else {
                compact
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Everything but the buttons lets clicks through to this, so the HUD
        // drags from anywhere else and right-clicks open its menu.
        .background(WindowDragHandle(menu: menu))
        .background(shape.fill(Color.flCanvas))
        .overlay(shape.fill(model.tone.tint.opacity(0.18 * pulse)).allowsHitTesting(false))
        .overlay(
            shape
                .strokeBorder(Color.flHairline.opacity(0.9), lineWidth: 1)
                .allowsHitTesting(false)
        )
        .overlay(
            shape
                .strokeBorder(model.tone.tint, lineWidth: 2)
                .opacity(pulse)
                .allowsHitTesting(false)
        )
        .clipShape(shape)
        .animation(FLAnimation.standard, value: model.tone)
        .onChange(of: model.pulseCount) {
            withAnimation(.easeOut(duration: 0.15)) {
                pulse = 1
            }
            // A separate update, or SwiftUI only ever sees the final 0.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeOut(duration: 1.1)) {
                    pulse = 0
                }
            }
        }
    }

    private var compact: some View {
        HStack(spacing: 8) {
            ring(size: 15)

            Text(model.countdown)
                .font(FLTypography.timer(18))
                .monospacedDigit()
                .foregroundStyle(model.tone.digits)
                .scaleEffect(1 + 0.12 * pulse)
                .accessibilityLabel("\(model.countdown) remaining")
        }
        .allowsHitTesting(false)
    }

    private var expanded: some View {
        HStack(spacing: 12) {
            ring(size: 20)
                .allowsHitTesting(false)

            Text(model.countdown)
                .font(FLTypography.timer(24))
                .monospacedDigit()
                .foregroundStyle(model.tone.digits)
                .scaleEffect(1 + 0.12 * pulse)
                .accessibilityLabel("\(model.countdown) remaining")
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 2) {
                FLMicroLabel(text: model.phaseLabel, tint: model.tone == .focus ? model.tone.tint : model.tone.digits)
                    .fixedSize()

                if let goal = model.goal {
                    Text(goal)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color.flInk.opacity(0.75))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .allowsHitTesting(false)

            Spacer(minLength: 8)

            if model.showsControls {
                if model.canEnd {
                    Button("End session", action: onEnd)
                        .buttonStyle(FLLinkButtonStyle(tint: .flClayInk))
                        .fixedSize()
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.flInkSoft)
                        .help("Strict block — it can't be ended early")
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func ring(size: CGFloat) -> some View {
        FLProgressRing(progress: model.progress, size: size, tint: model.tone.tint, trackTint: model.tone.tint)
    }
}

/// Drags the window from wherever it sits, and opens its menu on a right-click.
/// The HUD needs it because `isMovableByWindowBackground` never applies to
/// SwiftUI content: a hosting view doesn't count as window background.
private struct WindowDragHandle: NSViewRepresentable {
    let menu: () -> NSMenu

    func makeNSView(context: Context) -> DragView {
        DragView()
    }

    func updateNSView(_ view: DragView, context: Context) {
        view.makeMenu = menu
    }

    final class DragView: NSView {
        var makeMenu: (() -> NSMenu)?

        override var mouseDownCanMoveWindow: Bool { true }

        // The HUD is never the key window, so the first click has to count.
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) {
            // Hands the drag to the window server and returns straight away;
            // the controller snaps the HUD once it has settled.
            window?.performDrag(with: event)
        }

        override func menu(for event: NSEvent) -> NSMenu? {
            makeMenu?()
        }
    }
}
