import AppKit
import FocusLockCore
import SwiftUI

/// A break suggestion you can do along with, rather than read about: a
/// breathing circle, a 20-second ring for your eyes, paced moves and reps, a
/// checklist, a glass to fill, a countdown for a walk.
struct BreakGuideView: View {
    let suggestion: BreakSuggestion
    /// In Settings: shows what the guide looks like, records nothing.
    var isPreview = false
    /// When the break ends, for the walk's countdown.
    var breakEndsAt: Date?
    var isDone = false
    /// "You stretched 4 times this week", once there is something to count.
    var tally: String?
    var onDone: () -> Void = {}
    var onAnother: (() -> Void)?

    /// Whether the guide's own Start has been pressed. Until then "Did it"
    /// would be a claim about something that hasn't happened.
    @State private var hasStarted = false

    /// Guides with nothing to start: you just do them.
    private var isUntimed: Bool {
        [.water, .walk, .posture].contains(suggestion.kind)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: suggestion.systemImage)
                    .font(.system(size: 20))
                    .foregroundStyle(Color.flRestInk)
                    .frame(width: 28)
                Text(suggestion.title)
                    .font(FLTypography.title)
                    .foregroundStyle(Color.flInk)
            }

            Text(suggestion.detail)
                .font(FLTypography.body)
                .foregroundStyle(Color.flInkSoft)
                .fixedSize(horizontal: false, vertical: true)

            guide
                .id(suggestion.kind)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.guideDidStart) { hasStarted = true }
                .onChange(of: suggestion.kind) { _, _ in hasStarted = false }

            if !isPreview {
                footer
            }
        }
    }

    @ViewBuilder
    private var guide: some View {
        switch suggestion.kind {
        case .breathe:
            BreathingGuide(onFinish: finished)
        case .eyes:
            EyesGuide(onFinish: finished)
        case .stretch:
            StretchGuide(onFinish: finished)
        case .posture:
            PostureGuide(onFinish: finished)
        case .water:
            WaterGuide(isFull: isDone)
        case .walk:
            WalkGuide(endsAt: isPreview ? nil : breakEndsAt)
        case .pushups:
            RepsGuide(reps: 10, secondsPerRep: 3, systemImage: suggestion.kind.systemImage, onFinish: finished)
        case .squats:
            RepsGuide(reps: 15, secondsPerRep: 3, systemImage: suggestion.kind.systemImage, onFinish: finished)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            // One thing to do first (the guide's own Start); "Did it" once
            // there is something to have done, and a quiet way to swap.
            HStack(spacing: 10) {
                if isDone || hasStarted || isUntimed {
                    Button {
                        onDone()
                    } label: {
                        Label(isDone ? "Done" : (suggestion.kind == .water ? "Done" : "Did it"),
                              systemImage: isDone ? "checkmark.circle.fill" : "checkmark")
                    }
                    .buttonStyle(FLActionButtonStyle(variant: .secondary, minHeight: 32, tint: .flRestInk))
                    .disabled(isDone)
                }

                if let onAnother, !isDone {
                    Button("Something else", action: onAnother)
                        .buttonStyle(FLActionButtonStyle(variant: .quiet, minHeight: 32))
                }
            }

            if let tally {
                Text(tally)
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flRestInk)
                    .transition(.opacity)
            }
        }
        .animation(FLAnimation.standard, value: isDone)
    }

    /// A guide that ran to its end counts as done.
    private func finished() {
        guard !isPreview else { return }
        onDone()
    }

    /// The line under the buttons, for a kind and its counts.
    static func tally(for kind: BreakSuggestionKind, today: Int, week: Int) -> String? {
        if kind == .water {
            guard today > 0 else { return nil }
            return today == 1 ? "1 glass today" : "\(today) glasses today"
        }
        guard week > 0 else { return nil }
        let times = week == 1 ? "once" : "\(week) times"
        switch kind {
        case .eyes: return "You rested your eyes \(times) this week"
        case .stretch: return "You stretched \(times) this week"
        case .walk: return week == 1 ? "1 walk this week" : "\(week) walks this week"
        case .breathe: return "You took a breathing break \(times) this week"
        case .posture: return "You checked your posture \(times) this week"
        case .pushups: return "You did push-ups \(times) this week"
        case .squats: return "You did squats \(times) this week"
        case .water: return nil
        }
    }
}

// MARK: - Shared pieces

/// Runs a guide for a fixed length once started, and reports the end once.
private struct GuideClock {
    var startedAt: Date?

    func elapsed(at date: Date) -> TimeInterval {
        startedAt.map { max(0, date.timeIntervalSince($0)) } ?? 0
    }
}

private struct StartButton: View {
    let title: String
    let action: () -> Void
    @Environment(\.guideDidStart) private var guideDidStart

    var body: some View {
        Button {
            action()
            guideDidStart()
        } label: {
            Label(title, systemImage: "play.fill")
        }
        .buttonStyle(FLActionButtonStyle(variant: .secondary, minHeight: 30, tint: .flRestInk))
    }
}

private struct GuideDidStartKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    /// Told when a guide's Start is pressed, so the frame around it can offer
    /// "Did it".
    fileprivate var guideDidStart: () -> Void {
        get { self[GuideDidStartKey.self] }
        set { self[GuideDidStartKey.self] = newValue }
    }
}

/// A quiet chime for the end of a timed guide.
private enum GuideChime {
    static func play() {
        guard let sound = NSSound(named: NSSound.Name("Glass"))?.copy() as? NSSound else { return }
        sound.volume = 0.35
        sound.play()
    }
}

// MARK: - Breathe

/// Box breathing: in 4, hold 4, out 4, hold 4, four rounds.
private struct BreathingGuide: View {
    let onFinish: () -> Void

    private static let side: TimeInterval = 4
    private static let rounds = 4
    private static var total: TimeInterval { side * 4 * Double(rounds) }
    private static let steps = ["Breathe in", "Hold", "Breathe out", "Hold"]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var clock = GuideClock()
    @State private var finished = false

    var body: some View {
        TimelineView(.animation(paused: clock.startedAt == nil || finished)) { context in
            let elapsed = min(clock.elapsed(at: context.date), Self.total)
            HStack(spacing: 22) {
                ZStack {
                    if clock.startedAt == nil {
                        // Before starting: the box drawn as a ring with its
                        // count, not a grey blob waiting for meaning.
                        Circle()
                            .strokeBorder(Color.flRest.opacity(0.55), lineWidth: 2)
                        Text("4·4·4·4")
                            .font(.system(size: 13, design: .serif))
                            .foregroundStyle(Color.flRestInk)
                    } else {
                        Circle()
                            .fill(Color.flRest.opacity(0.18))
                        Circle()
                            .fill(Color.flRest.opacity(0.55))
                            .scaleEffect(reduceMotion ? 0.8 : scale(at: elapsed))
                    }
                    if clock.startedAt != nil, !finished {
                        Text("\(Int(Self.side - elapsed.truncatingRemainder(dividingBy: Self.side)))")
                            .font(FLTypography.timer(22))
                            .monospacedDigit()
                            .foregroundStyle(Color.flInk)
                    }
                }
                .frame(width: 96, height: 96)

                if clock.startedAt == nil {
                    StartButton(title: "Start · 1 min") { clock.startedAt = Date() }
                } else {
                    label(at: elapsed)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: 100)
        .task(id: clock.startedAt) {
            await finishAfter(Self.total)
        }
    }

    @ViewBuilder
    private func label(at elapsed: TimeInterval) -> some View {
        if finished {
            Text("Nicely done.")
                .font(FLTypography.headline)
                .foregroundStyle(Color.flRestInk)
        } else if clock.startedAt != nil {
            let step = Int(elapsed / Self.side) % 4
            let round = min(Int(elapsed / (Self.side * 4)) + 1, Self.rounds)
            VStack(alignment: .leading, spacing: 3) {
                Text(Self.steps[step] + "…")
                    .font(FLTypography.headline)
                    .foregroundStyle(Color.flInk)
                    // The circle is silent; say each step for VoiceOver.
                    .onChange(of: step) { _, newStep in
                        AccessibilityNotification.Announcement(Self.steps[newStep]).post()
                    }
                Text("Round \(round) of \(Self.rounds)")
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flInkSoft)
            }
        }
    }

    /// Grows on the way in, holds, shrinks on the way out, holds.
    private func scale(at elapsed: TimeInterval) -> CGFloat {
        guard clock.startedAt != nil else { return 0.55 }
        let step = Int(elapsed / Self.side) % 4
        let t = elapsed.truncatingRemainder(dividingBy: Self.side) / Self.side
        let eased = CGFloat(0.5 - cos(t * .pi) / 2)
        switch step {
        case 0: return 0.55 + 0.45 * eased
        case 1: return 1
        case 2: return 1 - 0.45 * eased
        default: return 0.55
        }
    }

    /// Cancelled with the view, so a guide swapped away never counts.
    private func finishAfter(_ seconds: TimeInterval) async {
        guard clock.startedAt != nil, !finished else { return }
        try? await Task.sleep(for: .seconds(seconds))
        guard !Task.isCancelled else { return }
        finished = true
        GuideChime.play()
        onFinish()
    }
}

// MARK: - Eyes

/// 20 seconds looking at something far away, with a chime at the end.
private struct EyesGuide: View {
    let onFinish: () -> Void

    private static let length: TimeInterval = 20

    @State private var clock = GuideClock()
    @State private var finished = false

    var body: some View {
        HStack(spacing: 18) {
            TimelineView(.animation(paused: clock.startedAt == nil || finished)) { context in
                let elapsed = min(clock.elapsed(at: context.date), Self.length)
                ZStack {
                    FLProgressRing(progress: finished ? 1 : elapsed / Self.length, size: 72, lineWidth: 4)
                    if finished {
                        Image(systemName: "checkmark")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color.flRestInk)
                    } else {
                        Text(clock.startedAt == nil ? "20" : "\(Int(ceil(Self.length - elapsed)))")
                            .font(FLTypography.timer(24))
                            .monospacedDigit()
                            .foregroundStyle(Color.flInk)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                if finished {
                    Text("Blink slowly a few times.")
                        .font(FLTypography.headline)
                        .foregroundStyle(Color.flRestInk)
                } else if clock.startedAt != nil {
                    Text("Look at something far away…")
                        .font(FLTypography.headline)
                        .foregroundStyle(Color.flInk)
                    Text("About 20 feet (6 m). A window is perfect.")
                        .font(FLTypography.caption)
                        .foregroundStyle(Color.flInkSoft)
                } else {
                    StartButton(title: "Start · 20 sec") { clock.startedAt = Date() }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(height: 80)
        .task(id: clock.startedAt) {
            await finishAfter(Self.length)
        }
    }

    /// Cancelled with the view, so a guide swapped away never counts.
    private func finishAfter(_ seconds: TimeInterval) async {
        guard clock.startedAt != nil, !finished else { return }
        try? await Task.sleep(for: .seconds(seconds))
        guard !Task.isCancelled else { return }
        finished = true
        GuideChime.play()
        onFinish()
    }
}

// MARK: - Stretch

/// Three moves, 20 seconds each, with the figure for each one.
private struct StretchGuide: View {
    let onFinish: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Move {
        let title: String
        let hint: String
        let systemImage: String
    }

    private static let moves = [
        Move(title: "Reach up", hint: "Stand and stretch for the ceiling.", systemImage: "figure.arms.open"),
        Move(title: "Neck tilt", hint: "Ear towards one shoulder, then the other.", systemImage: "figure.mind.and.body"),
        Move(title: "Shoulder rolls", hint: "Slow circles backwards.", systemImage: "figure.cooldown")
    ]
    private static let perMove: TimeInterval = 20

    @State private var clock = GuideClock()
    @State private var finished = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let elapsed = clock.elapsed(at: context.date)
            let index = finished ? Self.moves.count - 1 : min(Int(elapsed / Self.perMove), Self.moves.count - 1)
            let move = Self.moves[index]
            let running = clock.startedAt != nil && !finished

            HStack(spacing: 18) {
                Image(systemName: move.systemImage)
                    .font(.system(size: 40))
                    .foregroundStyle(Color.flRestInk)
                    .symbolEffect(.pulse, options: .repeating, isActive: running && !reduceMotion)
                    .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 6) {
                    if clock.startedAt == nil {
                        StartButton(title: "Start · 1 min") { clock.startedAt = Date() }
                    } else if finished {
                        Text("All three done.")
                            .font(FLTypography.headline)
                            .foregroundStyle(Color.flRestInk)
                    } else {
                        HStack(spacing: 8) {
                            Text(move.title)
                                .font(FLTypography.headline)
                                .foregroundStyle(Color.flInk)
                            Text("\(Int(ceil(Self.perMove - elapsed.truncatingRemainder(dividingBy: Self.perMove))))s")
                                .font(FLTypography.caption)
                                .monospacedDigit()
                                .foregroundStyle(Color.flInkSoft)
                        }
                        Text(move.hint)
                            .font(FLTypography.caption)
                            .foregroundStyle(Color.flInkSoft)
                    }

                    HStack(spacing: 5) {
                        ForEach(Self.moves.indices, id: \.self) { dot in
                            Capsule()
                                .fill(dotColor(dot, current: index))
                                .frame(width: dot == index && running ? 18 : 8, height: 4)
                        }
                    }
                    .animation(FLAnimation.standard, value: index)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: 72)
        .task(id: clock.startedAt) {
            await finishAfter(Self.perMove * Double(Self.moves.count))
        }
    }

    private func dotColor(_ dot: Int, current: Int) -> Color {
        if finished || dot < current { return .flRestInk }
        if dot == current && clock.startedAt != nil { return .flRest }
        return .flHairline
    }

    /// Cancelled with the view, so a guide swapped away never counts.
    private func finishAfter(_ seconds: TimeInterval) async {
        guard clock.startedAt != nil, !finished else { return }
        try? await Task.sleep(for: .seconds(seconds))
        guard !Task.isCancelled else { return }
        finished = true
        GuideChime.play()
        onFinish()
    }
}

// MARK: - Push-ups and squats

/// Paced reps: the figure dips once per rep and the count goes up with it.
private struct RepsGuide: View {
    let reps: Int
    let secondsPerRep: TimeInterval
    let systemImage: String
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var clock = GuideClock()
    @State private var finished = false

    private var total: TimeInterval { secondsPerRep * Double(reps) }

    var body: some View {
        TimelineView(.animation(paused: clock.startedAt == nil || finished)) { context in
            let elapsed = min(clock.elapsed(at: context.date), total)
            let rep = finished ? reps : min(Int(elapsed / secondsPerRep) + 1, reps)
            // Down for the first half of each rep, up for the second.
            let phase = elapsed.truncatingRemainder(dividingBy: secondsPerRep) / secondsPerRep
            let dip = CGFloat(sin(phase * .pi))

            HStack(spacing: 18) {
                Image(systemName: systemImage)
                    .font(.system(size: 40))
                    .foregroundStyle(Color.flRestInk)
                    .offset(y: reduceMotion || clock.startedAt == nil || finished ? 0 : dip * 8)
                    .scaleEffect(y: reduceMotion || clock.startedAt == nil || finished ? 1 : 1 - dip * 0.12, anchor: .bottom)
                    .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 6) {
                    if clock.startedAt == nil {
                        StartButton(title: "Start · \(reps) reps") { clock.startedAt = Date() }
                    } else if finished {
                        Text("\(reps) done. Strong.")
                            .font(FLTypography.headline)
                            .foregroundStyle(Color.flRestInk)
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(rep)")
                                .font(FLTypography.timer(28))
                                .monospacedDigit()
                                .foregroundStyle(Color.flInk)
                            Text("/ \(reps)")
                                .font(FLTypography.caption)
                                .foregroundStyle(Color.flInkSoft)
                        }
                        Text(phase < 0.5 ? "Down…" : "Up…")
                            .font(FLTypography.caption)
                            .foregroundStyle(Color.flInkSoft)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: 72)
        .task(id: clock.startedAt) {
            await finishAfter(total)
        }
    }

    /// Cancelled with the view, so a guide swapped away never counts.
    private func finishAfter(_ seconds: TimeInterval) async {
        guard clock.startedAt != nil, !finished else { return }
        try? await Task.sleep(for: .seconds(seconds))
        guard !Task.isCancelled else { return }
        finished = true
        GuideChime.play()
        onFinish()
    }
}

// MARK: - Posture

/// A three-line checklist. Ticking the last one counts as done.
private struct PostureGuide: View {
    let onFinish: () -> Void

    private static let items = ["Feet flat on the floor", "Shoulders down and back", "Top of the screen at eye level"]
    @State private var ticked: Set<Int> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Self.items.indices, id: \.self) { index in
                Button {
                    withAnimation(FLAnimation.quick) {
                        if ticked.contains(index) {
                            ticked.remove(index)
                        } else {
                            ticked.insert(index)
                            if ticked.count == Self.items.count { onFinish() }
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: ticked.contains(index) ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 16))
                            .foregroundStyle(ticked.contains(index) ? Color.flRestInk : Color.flInkSoft)
                        Text(Self.items[index])
                            .font(FLTypography.body)
                            .foregroundStyle(Color.flInk)
                            .strikethrough(ticked.contains(index), color: Color.flInkSoft)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Water

/// A glass that fills when the water is drunk.
private struct WaterGuide: View {
    let isFull: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 18) {
            GlassShape()
                .fill(Color.flRest.opacity(0.12))
                .overlay(alignment: .bottom) {
                    GeometryReader { proxy in
                        Rectangle()
                            .fill(Color.flRest.opacity(0.75))
                            .frame(height: proxy.size.height * (isFull ? 0.82 : 0.1))
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                    .mask(GlassShape())
                }
                .overlay(GlassShape().stroke(Color.flRest, lineWidth: 2))
                .frame(width: 44, height: 60)
                .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.9, dampingFraction: 0.75), value: isFull)

            Text(isFull ? "Glass down. Your head will thank you." : "Have a full glass, then tap Done.")
                .font(FLTypography.headline)
                .foregroundStyle(isFull ? Color.flRestInk : Color.flInk)
            Spacer(minLength: 0)
        }
        .frame(height: 64)
    }

    private struct GlassShape: Shape {
        func path(in rect: CGRect) -> Path {
            let inset = rect.width * 0.14
            return Path { path in
                path.move(to: CGPoint(x: rect.minX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.minX + inset, y: rect.maxY))
                path.closeSubpath()
            }
        }
    }
}

// MARK: - Walk

/// A walking figure and the time until the break ends.
private struct WalkGuide: View {
    let endsAt: Date?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation) { context in
            let stride = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 18) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.flRestInk)
                    .offset(y: reduceMotion ? 0 : CGFloat(abs(sin(stride * 3.2))) * -4)
                    .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Back in \(remaining(at: context.date))")
                        .font(FLTypography.timer(24))
                        .monospacedDigit()
                        .foregroundStyle(Color.flInk)
                    Text("Your phone can stay here.")
                        .font(FLTypography.caption)
                        .foregroundStyle(Color.flInkSoft)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: 64)
    }

    private func remaining(at date: Date) -> String {
        guard let endsAt else { return "5:00" }
        let seconds = max(0, Int(endsAt.timeIntervalSince(date).rounded(.up)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
