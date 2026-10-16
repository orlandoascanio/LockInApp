import SwiftUI

/// One thing the island has to say: a block finished, a minute is left, a
/// break is over. Built by the controller, drawn by `NotchIslandView`.
struct NotchMoment: Equatable, Identifiable {
    enum Tone: Equatable {
        case focus
        case rest
        case finalMinute
        case done

        /// The island is always black, so these are the dark-mode pigments.
        var color: Color {
            switch self {
            case .focus: return Color(red: 0x7F / 255, green: 0xAE / 255, blue: 0x88 / 255)
            case .rest: return Color(red: 0x8E / 255, green: 0xB1 / 255, blue: 0xC4 / 255)
            case .finalMinute: return Color(red: 0xD2 / 255, green: 0xA8 / 255, blue: 0x62 / 255)
            case .done: return Color(red: 0xE9 / 255, green: 0xE5 / 255, blue: 0xD9 / 255)
            }
        }
    }

    struct Action: Equatable, Identifiable {
        enum Role: Equatable {
            case primary
            case secondary
            case quiet
        }

        let id: String
        let title: String
        var role: Role = .secondary
    }

    /// How far into the set of blocks before the long break this run is.
    struct SetProgress: Equatable {
        /// 1 through `total`.
        var position: Int
        var total: Int
        /// Whether `position` is filled in yet: true once that block is done.
        var positionDone: Bool
    }

    enum Kind: Equatable {
        case focusDone
        case finalMinute
        case breakOver
        case runDone
        case extended
    }

    let id = UUID()
    var kind: Kind
    var tone: Tone
    var symbol: String
    var eyebrow: String
    var title: String
    var detail: String?
    /// Drives the live countdown beside the notch.
    var countsDownTo: Date?
    var set: SetProgress?
    var actions: [Action] = []
    /// Stays open until one of its actions is chosen.
    var holdsUntilAnswered = false
    var lifetime: TimeInterval = 7

    static func == (lhs: NotchMoment, rhs: NotchMoment) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
final class NotchIslandModel: ObservableObject {
    @Published var moment: NotchMoment?
    @Published var isOpen = false
    /// The physical notch, or a slim tab hanging from the menu bar on a
    /// display without one. The island grows out of it and folds back into it.
    @Published var notch = CGSize(width: 150, height: 0)
    @Published var hasNotch = false
}

struct NotchIslandView: View {
    @ObservedObject var model: NotchIslandModel
    let onAction: (String) -> Void
    let onDismiss: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let open = model.isOpen && model.moment != nil
            let size = open ? proxy.size : model.notch

            ZStack(alignment: .top) {
                NotchShape(topFlare: open ? 10 : 6, bottomRadius: open ? 26 : min(10, model.notch.height / 2))
                    .fill(Color.black)
                    .frame(width: size.width, height: size.height)
                    .contentShape(NotchShape(topFlare: 10, bottomRadius: 26))
                    .onTapGesture(perform: onDismiss)

                if open, let moment = model.moment {
                    NotchIslandContent(
                        moment: moment,
                        notch: model.notch,
                        hasNotch: model.hasNotch,
                        onAction: onAction
                    )
                    .frame(width: proxy.size.width)
                    .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .top)))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: model.isOpen)
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: model.moment)
    }
}

/// What sits inside the open island. Measured on its own by the controller
/// to size the window, so it must not depend on the window's size.
struct NotchIslandContent: View {
    let moment: NotchMoment
    let notch: CGSize
    let hasNotch: Bool
    let onAction: (String) -> Void

    static let width: CGFloat = 430
    private static let sidePadding: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            wings

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .center) {
                    Text(moment.eyebrow.uppercased())
                        .font(.system(size: 9.5, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(moment.tone.color)
                    Spacer(minLength: 8)
                    if let set = moment.set {
                        SetBeads(progress: set, tint: moment.tone.color)
                    }
                }

                Text(moment.title)
                    .font(.system(size: 21, weight: .regular, design: .serif))
                    .foregroundStyle(Color.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let detail = moment.detail {
                    Text(detail)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color.white.opacity(0.62))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !moment.actions.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(moment.actions) { action in
                            Button(action.title) { onAction(action.id) }
                                .buttonStyle(IslandButtonStyle(role: action.role, tint: moment.tone.color))
                        }
                    }
                    .padding(.top, 9)
                }
            }
            .padding(.horizontal, Self.sidePadding)
            .padding(.top, 6)
            .padding(.bottom, 18)
        }
        .frame(width: Self.width, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(moment.eyebrow). \(moment.title)")
    }

    /// The strip beside the notch: what happened on the left, the time on the
    /// right. On a display without a notch it is just the top row.
    private var wings: some View {
        HStack(spacing: 0) {
            Image(systemName: moment.symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(moment.tone.color)
                .frame(width: 18)

            Spacer(minLength: hasNotch ? notch.width : 8)

            if let end = moment.countsDownTo {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(Self.countdown(to: end, now: context.date))
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .foregroundStyle(moment.tone.color)
                }
            } else {
                Color.clear.frame(width: 18, height: 1)
            }
        }
        .padding(.horizontal, Self.sidePadding)
        .frame(height: max(hasNotch ? notch.height : 0, 30))
    }

    static func countdown(to end: Date, now: Date) -> String {
        let seconds = max(0, Int(end.timeIntervalSince(now).rounded(.up)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

/// The blocks of a set, with the one that earns the long break drawn as a
/// ring: you can see how close the real rest is.
private struct SetBeads: View {
    let progress: NotchMoment.SetProgress
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            ForEach(1...max(1, progress.total), id: \.self) { index in
                let done = index < progress.position || (index == progress.position && progress.positionDone)
                let isLast = index == progress.total
                ZStack {
                    if isLast {
                        Circle().strokeBorder(tint.opacity(done ? 1 : 0.45), lineWidth: 1.5)
                            .frame(width: 10, height: 10)
                    }
                    Circle()
                        .fill(done ? tint : Color.white.opacity(0.18))
                        .frame(width: isLast ? 5 : 6, height: isLast ? 5 : 6)
                }
                .frame(width: 10, height: 10)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Block \(progress.position) of \(progress.total) before the long break")
    }
}

private struct IslandButtonStyle: ButtonStyle {
    let role: NotchMoment.Action.Role
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: role == .quiet ? .regular : .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, role == .quiet ? 6 : 13)
            .frame(height: 28)
            .background(Capsule().fill(background))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Capsule())
    }

    private var foreground: Color {
        switch role {
        case .primary: return .black
        case .secondary: return .white
        case .quiet: return .white.opacity(0.55)
        }
    }

    private var background: Color {
        switch role {
        case .primary: return tint
        case .secondary: return .white.opacity(0.13)
        case .quiet: return .clear
        }
    }
}

/// The notch's own outline, grown: the top edge flares outwards into the
/// menu bar the way the hardware notch does, and the bottom is rounded.
struct NotchShape: Shape {
    var topFlare: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topFlare, bottomRadius) }
        set {
            topFlare = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let flare = min(topFlare, rect.width / 4, rect.height / 2)
        let radius = min(bottomRadius, rect.width / 4, max(0, rect.height - flare))
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + flare, y: rect.minY + flare),
            control: CGPoint(x: rect.minX + flare, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX + flare, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + flare + radius, y: rect.maxY),
            control: CGPoint(x: rect.minX + flare, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - flare - radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - flare, y: rect.maxY - radius),
            control: CGPoint(x: rect.maxX - flare, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - flare, y: rect.minY + flare))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - flare, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}
