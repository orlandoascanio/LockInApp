import FocusLockCore
import SwiftUI

/// Audience-only surface. Capture this window instead of the host's workspace.
struct StreamAudienceView: View {
    @EnvironmentObject private var controller: MenuBarController

    var body: some View {
        StreamAudienceCanvas(settings: controller.config.stream,
                             snapshot: controller.snapshot,
                             task: controller.streamTask,
                             roster: controller.roster,
                             countdown: controller.displayCountdown,
                             recap: controller.streamRecap)
    }
}

/// The broadcast is a projection of session state, with no timer or host actions
/// of its own. Keeping it separate also lets previews exercise the real layout.
struct StreamAudienceCanvas: View {
    let settings: StreamSettings
    let snapshot: TimerSnapshot
    let task: SessionTask
    let roster: AudienceRoster
    let countdown: String
    let recap: StreamRecap
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var animated: Bool { settings.motion != .off && !reduceMotion }
    private var ambient: Bool { settings.motion == .ambient && !reduceMotion }
    private var dark: Bool { settings.darkAppearance }
    private var resting: Bool { snapshot.phase == .break || snapshot.phase == .breakEnded }
    private var ink: Color { dark ? Color(red: 0.95, green: 0.93, blue: 0.86) : Color(red: 0.17, green: 0.23, blue: 0.20) }
    private var accent: Color {
        if resting { return dark ? Color(red: 0.86, green: 0.77, blue: 0.55) : Color(red: 0.47, green: 0.35, blue: 0.18) }
        return dark ? Color(red: 0.73, green: 0.81, blue: 0.57) : Color(red: 0.29, green: 0.40, blue: 0.25)
    }
    private var background: Color {
        if resting { return dark ? Color(red: 0.15, green: 0.16, blue: 0.12) : Color(red: 0.97, green: 0.93, blue: 0.84) }
        return dark ? Color.flStreamDark : Color.flStreamLight
    }
    private var copy: StreamPresentation { StreamPresentation(phase: snapshot.phase) }
    private var phaseAnimation: Animation? { animated ? .easeInOut(duration: 0.7) : nil }
    private var fade: AnyTransition { animated ? .opacity : .identity }
    private var blockLabel: String? {
        guard snapshot.phase != .idle else { return nil }
        let current = snapshot.currentCycle
        return current > settings.plannedBlocks ? "Block \(current)" : "Block \(current) of \(settings.plannedBlocks)"
    }
    private var returnLine: String? {
        guard snapshot.phase == .break, let endsAt = snapshot.phaseEndsAt else { return nil }
        return "Back at \(endsAt.formatted(date: .omitted, time: .shortened))"
    }
    private var showsCommands: Bool { settings.showCommands && !finished }
    private var tickerLine: String {
        guard snapshot.phase == .focus else {
            return showsCommands ? AudiencePrompts.welcome : AudiencePrompts.primary
        }
        let elapsed = Double(snapshot.focusMinutes * 60) - snapshot.remainingSeconds
        return AudiencePrompts.line(remaining: snapshot.remainingSeconds, elapsed: elapsed,
                                    hasCompany: !roster.isEmpty,
                                    commandsShown: showsCommands) ?? ""
    }
    private var finished: Bool {
        (snapshot.phase == .completed || snapshot.phase == .cancelled) && !recap.isEmpty
    }
    private var progress: Double {
        switch snapshot.phase {
        case .focus, .break, .paused:
            let total = Double((snapshot.phase == .break ? snapshot.breakMinutes : snapshot.focusMinutes) * 60)
            return total > 0 ? min(1, max(0, 1 - snapshot.remainingSeconds / total)) : 0
        case .breakEnded, .completed: return 1
        default: return 0
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 640
            let clockSize: CGFloat = geometry.size.height < 480 ? 64 : (compact ? 90 : 116)
            let hasRoster = settings.showRoster && !roster.isEmpty
            let sidebar = hasRoster && geometry.size.width >= 820

            HStack(spacing: 0) {
                mainColumn(compact: compact, clockSize: clockSize, audienceStrip: hasRoster && !sidebar)
                if sidebar {
                    Rectangle().fill(accent.opacity(0.22)).frame(width: 1)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        rosterColumn(height: geometry.size.height, compact: compact, at: context.date)
                    }
                    .frame(width: 310)
                    .transition(fade)
                }
            }
            .foregroundStyle(ink)
            .background {
                StreamAtmosphere(base: background, accent: accent, dark: dark,
                                 ambient: ambient, glow: settings.motion != .off,
                                 animation: phaseAnimation)
            }
            .animation(phaseAnimation, value: snapshot.phase)
            .animation(animated ? .easeInOut(duration: 0.45) : nil, value: sidebar)
            .clipped()
            // Stop in-flight child animations too when the host disables motion.
            .transaction { if !animated { $0.animation = nil; $0.disablesAnimations = true } }
        }
    }

    private func rosterColumn(height: CGFloat, compact: Bool, at date: Date) -> some View {
        // Budget for a name, two task lines, spacing, and padding in every row.
        let rowHeight: CGFloat = compact ? 62 : 76
        let size = max(1, min(16, Int((height - 140) / rowHeight)))
        let page = roster.page(size: size, at: date)
        return VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                Text("WORKING ALONGSIDE · \(roster.peopleCount)")
                Spacer(minLength: 4)
                // The score outranks the page number for the space on this
                // line: one says how the room is doing, the other says which
                // slice of it you happen to be looking at.
                if !roster.tally.isEmpty { StreamTallyBadge(tally: roster.tally, accent: accent) }
            }
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(accent)

            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(page.tasks) { entry in
                        StreamAudienceRow(task: entry, date: date, ink: ink, accent: accent,
                                          compact: compact, animated: animated)
                            .transition(animated ? .opacity.combined(with: .offset(y: 6)) : .identity)
                    }
                }
                .id(page.index)
                .transition(fade)
            }
            .animation(animated ? .easeInOut(duration: 0.45) : nil, value: page.index)
            .animation(animated ? .easeOut(duration: 0.35) : nil, value: page.tasks.map(\.id))

            Spacer(minLength: 0)
            if page.rotates {
                HStack(spacing: 8) {
                    Text("Everyone gets a turn on the wall")
                        .font(.system(size: 12))
                    Spacer(minLength: 4)
                    Text("\(page.index + 1)/\(page.count)")
                        .font(.system(size: 11, design: .monospaced))
                        .monospacedDigit()
                }
                .foregroundStyle(ink.opacity(0.6))
            }
        }
        .padding(compact ? 18 : 26)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func audienceStrip(at date: Date) -> some View {
        let page = roster.page(size: 1, at: date)
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("ALONGSIDE").font(.system(size: 9, weight: .semibold, design: .monospaced))
                HStack(spacing: 5) {
                    Text("\(roster.peopleCount) here").font(.system(size: 13, weight: .medium))
                    if !roster.tally.isEmpty {
                        Text("✓ \(roster.tally.label)")
                            .font(.system(size: 11, design: .monospaced)).monospacedDigit()
                            .opacity(0.75)
                    }
                }
            }
            .foregroundStyle(accent)
            Rectangle().fill(accent.opacity(0.25)).frame(width: 1, height: 28)
            ZStack(alignment: .leading) {
                if let entry = page.tasks.first {
                    StreamAudienceRow(task: entry, date: date, ink: ink, accent: accent,
                                      compact: true, animated: animated, singleLine: true)
                        .id(entry.id)
                        .transition(fade)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(animated ? .easeInOut(duration: 0.45) : nil, value: page.tasks.map(\.id))
        }
        .frame(height: 44)
        .accessibilityElement(children: .contain)
    }

    private func mainColumn(compact: Bool, clockSize: CGFloat, audienceStrip showsStrip: Bool) -> some View {
        VStack(spacing: compact ? 10 : 22) {
            HStack(spacing: 10) {
                Label("LOCKIN / TOGETHER", systemImage: "circle.grid.2x2")
                Spacer(minLength: 8)
                if let blockLabel {
                    Text(blockLabel).lineLimit(1)
                    if !compact { Text("·").opacity(0.5) }
                }
                if !compact {
                    Text(task.category.isEmpty ? "Your own task" : task.category).lineLimit(1)
                }
            }
            .font(.system(size: compact ? 10 : 12, weight: .medium, design: .monospaced))
            .foregroundStyle(accent)

            Spacer(minLength: 0)

            VStack(spacing: compact ? 6 : 14) {
                ZStack {
                    Text(copy.title)
                        .font(.system(size: compact ? 23 : 32, design: .serif))
                        .id(copy.title)
                        .transition(fade)
                }
                .animation(phaseAnimation, value: copy.title)
                if !compact && snapshot.phase != .idle {
                    Text(settings.invitation)
                        .font(.system(size: 15))
                        .foregroundStyle(ink.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }

                ZStack {
                    if finished {
                        StreamRecapCard(recap: recap, ink: ink, compact: compact, animated: animated)
                            .transition(fade)
                    } else {
                        VStack(spacing: compact ? 8 : 14) {
                            StreamCountdown(text: countdown, size: clockSize, animated: animated)
                            StreamPhaseProgress(progress: progress, accent: accent, animated: animated)
                                // A new phase starts at its own position; never rewind the old bar.
                                .id("\(snapshot.phase.rawValue)-\(snapshot.currentCycle)")
                                .frame(maxWidth: compact ? 220 : 360)
                            if let returnLine {
                                Text(returnLine)
                                    .font(.system(size: compact ? 13 : 16, weight: .medium))
                                    .foregroundStyle(accent)
                            }
                        }
                        .transition(fade)
                    }
                }
                .animation(phaseAnimation, value: finished)

                if !finished && settings.showGoal && !task.goal.isEmpty {
                    VStack(spacing: compact ? 3 : 6) {
                        Text("MY GOAL")
                            .font(.system(size: compact ? 9 : 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(accent)
                        Text(task.goal)
                            .font(.system(size: compact ? 18 : 26, design: .serif))
                            .multilineTextAlignment(.center)
                            .lineLimit(compact ? 1 : 3)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(.top, compact ? 2 : 8)
                }
            }

            Spacer(minLength: 0)

            if showsStrip {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    audienceStrip(at: context.date)
                }
            }

            VStack(spacing: compact ? 8 : 14) {
                // Above the rule, with the timer rather than the wall: someone
                // who has just arrived needs this before they are on the wall,
                // and the wall is the first thing a host turns off.
                if showsCommands {
                    StreamCommandLegend(ink: ink, accent: accent, compact: compact)
                        .transition(fade)
                }
                Rectangle().fill(accent.opacity(0.3)).frame(height: 1)
                if !compact {
                    ZStack {
                        Text(copy.prompt)
                            .id(copy.prompt)
                            .transition(fade)
                    }
                    .font(.system(size: 17))
                    .multilineTextAlignment(.center)
                    .animation(phaseAnimation, value: copy.prompt)
                }
                // A fixed two-line slot prevents invitations from moving the timer.
                ZStack {
                    Text(tickerLine)
                        .id(tickerLine)
                        .transition(fade)
                }
                .font(.system(size: compact ? 12 : 15, weight: .medium, design: .monospaced))
                .foregroundStyle(accent)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: compact ? 30 : 40)
                .animation(animated ? .easeInOut(duration: 0.45) : nil, value: tickerLine)
                if !compact {
                    Text("Different tasks. A little company. One shared timer.")
                        .font(.system(size: 12))
                        .foregroundStyle(ink.opacity(0.6))
                }
            }
        }
        .padding(compact ? 18 : 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct StreamAtmosphere: View {
    let base: Color
    let accent: Color
    let dark: Bool
    let ambient: Bool
    let glow: Bool
    let animation: Animation?
    @State private var visible = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !ambient || !visible)) { context in
            let angle = ambient ? context.date.timeIntervalSinceReferenceDate * .pi * 2 / 36 : 0
            GeometryReader { geometry in
                ZStack {
                    base
                    if glow {
                        Ellipse()
                            .fill(RadialGradient(colors: [accent.opacity(dark ? 0.13 : 0.08), .clear],
                                                 center: .center, startRadius: 0,
                                                 endRadius: geometry.size.width * 0.4))
                            .frame(width: geometry.size.width * 0.95, height: geometry.size.height * 1.2)
                            .position(x: geometry.size.width * (0.46 + 0.07 * sin(angle)),
                                      y: geometry.size.height * (0.35 + 0.06 * cos(angle)))
                        Ellipse()
                            .fill(RadialGradient(colors: [accent.opacity(dark ? 0.07 : 0.04), .clear],
                                                 center: .center, startRadius: 0,
                                                 endRadius: geometry.size.width * 0.3))
                            .frame(width: geometry.size.width * 0.65, height: geometry.size.height)
                            .position(x: geometry.size.width * (0.83 - 0.05 * sin(angle)),
                                      y: geometry.size.height * 0.8)
                    }
                }
            }
        }
        .animation(animation, value: base)
        .animation(animation, value: accent)
        .onAppear { visible = true }
        .onDisappear { visible = false }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct StreamCountdown: View {
    let text: String
    let size: CGFloat
    let animated: Bool

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, character in
                ZStack {
                    Text("0").hidden()
                    Text(String(character)).id(character)
                        .transition(animated ? .opacity : .identity)
                }
            }
        }
        .font(.system(size: size, weight: .light, design: .monospaced))
        .monospacedDigit()
        .animation(animated ? .easeInOut(duration: 0.18) : nil, value: text)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(text) remaining")
    }
}

private struct StreamPhaseProgress: View {
    let progress: Double
    let accent: Color
    let animated: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(accent.opacity(0.16))
                Capsule().fill(accent.opacity(0.85))
                    .frame(width: geometry.size.width * progress)
            }
            .animation(animated ? .linear(duration: 1) : nil, value: progress)
        }
        .frame(height: 3)
        .accessibilityLabel("Block progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}

private struct StreamAudienceRow: View {
    let task: AudienceTask
    let date: Date
    let ink: Color
    let accent: Color
    let compact: Bool
    let animated: Bool
    var singleLine = false
    @State private var highlighted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(task.name)
                    .font(.system(size: compact ? 12 : 14, weight: .medium))
                    .foregroundStyle(accent).lineLimit(1)
                Text(task.elapsedLabel(at: date))
                    .font(.system(size: compact ? 10 : 12, design: .monospaced))
                    .foregroundStyle(ink.opacity(0.55)).monospacedDigit()
                StreamCheckmark().trim(from: 0, to: task.isDone ? 1 : 0)
                    .stroke(accent, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    .frame(width: 12, height: 10)
                    .animation(animated ? .easeOut(duration: 0.4) : nil, value: task.isDone)
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
            }
            Text(task.text)
                .font(.system(size: compact ? 12 : 14))
                .foregroundStyle(ink.opacity(task.isDone ? 0.55 : 0.85))
                .strikethrough(task.isDone, color: ink.opacity(0.45))
                .lineLimit(singleLine ? 1 : 2)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, singleLine ? 3 : 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(highlighted && animated ? 0.15 : 0), in: RoundedRectangle(cornerRadius: 8))
        .animation(animated ? .easeInOut(duration: 0.35) : nil, value: highlighted)
        .animation(animated ? .easeInOut(duration: 0.35) : nil, value: task.isDone)
        .onChange(of: task.isDone) { done in highlighted = done && animated }
        .onChange(of: animated) { enabled in if !enabled { highlighted = false } }
        .task(id: highlighted) {
            guard highlighted else { return }
            do { try await Task.sleep(nanoseconds: 1_200_000_000) } catch { return }
            highlighted = false
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(task.name), \(task.text), \(task.isDone ? "done" : "working"), \(task.elapsedLabel(at: date))")
    }
}

/// How to join, in the two commands that matter. Every co-working overlay
/// carries one, because chat cannot use a command it has never seen.
private struct StreamCommandLegend: View {
    let ink: Color
    let accent: Color
    let compact: Bool

    var body: some View {
        Group {
            if compact {
                HStack(spacing: 10) {
                    ForEach(Array(AudienceCommand.legend.enumerated()), id: \.element.id) { index, entry in
                        if index > 0 { Text("·").foregroundStyle(accent.opacity(0.5)) }
                        Text(entry.command).foregroundStyle(accent)
                        Text(entry.meaning).foregroundStyle(ink.opacity(0.6))
                    }
                }
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1)
                // Shrink rather than truncate: half a command is worse than a
                // small one, and this line is the whole point of the panel.
                .minimumScaleFactor(0.75)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    Text("JOIN IN FROM CHAT")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(accent)
                    ForEach(AudienceCommand.legend) { entry in
                        HStack(spacing: 8) {
                            Text(entry.command)
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundStyle(accent)
                                // Both commands line up whatever their length.
                                .frame(width: 52, alignment: .leading)
                            Text(entry.meaning)
                                .font(.system(size: 13))
                                .foregroundStyle(ink.opacity(0.72))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(accent.opacity(0.07))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10).stroke(accent.opacity(0.22), lineWidth: 1)
                        }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Join in from chat: "
                            + AudienceCommand.legend.map { "\($0.command), \($0.meaning)" }.joined(separator: ". "))
    }
}

/// Done over posted, for the stream rather than the page.
private struct StreamTallyBadge: View {
    let tally: AudienceTally
    let accent: Color

    var body: some View {
        HStack(spacing: 4) {
            StreamCheckmark()
                .stroke(accent, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                .frame(width: 10, height: 9)
            Text(tally.label).monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(tally.completed) of \(tally.total) tasks done")
    }
}

private struct StreamCheckmark: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX + rect.width * 0.1, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.width * 0.4, y: rect.height * 0.85))
            path.addLine(to: CGPoint(x: rect.width * 0.95, y: rect.height * 0.12))
        }
    }
}

private struct StreamRecapCard: View {
    let recap: StreamRecap
    let ink: Color
    let compact: Bool
    let animated: Bool
    @State private var revealed = false

    var body: some View {
        VStack(spacing: compact ? 8 : 12) {
            Text(recap.headline)
                .font(.system(size: compact ? 28 : 42, weight: .light, design: .serif))
                .monospacedDigit().multilineTextAlignment(.center)
                .lineLimit(2).minimumScaleFactor(0.6)
            ForEach(Array(recap.detailLines.enumerated()), id: \.element) { index, detail in
                Text(detail)
                    .font(.system(size: compact ? 13 : 16))
                    .foregroundStyle(ink.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .opacity(!animated || revealed ? 1 : 0)
                    .offset(y: !animated || revealed ? 0 : 5)
                    .animation(animated ? .easeOut(duration: 0.45).delay(0.15 * Double(index + 1)) : nil,
                               value: revealed)
            }
        }
        .padding(.vertical, compact ? 6 : 12)
        .onAppear { revealed = true }
    }
}
