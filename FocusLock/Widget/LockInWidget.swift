import AppIntents
#if !WIDGET_RENDER_HARNESS
import FocusLockCore
#endif
import SwiftUI
import WidgetKit

#if !WIDGET_RENDER_HARNESS
@main
#endif
struct LockInWidgets: WidgetBundle {
    var body: some Widget {
        LockInStatusWidget()
    }
}

struct LockInStatusWidget: Widget {
    let kind = "LockInStatus"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockInTimelineProvider()) { entry in
            LockInWidgetView(entry: entry)
        }
        .configurationDisplayName("LockIn")
        .description("Time left in your block, today's focus, and your streak.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timeline

struct LockInEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?

    /// Past the end of a phase the app would have moved on; if it has not
    /// written since, it is not running.
    var isAppAway: Bool {
        guard let snapshot else { return true }
        return snapshot.isStale(at: date)
    }
}

struct LockInTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> LockInEntry {
        LockInEntry(date: Date(), snapshot: WidgetSnapshot(
            phase: .focus,
            phaseEndsAt: Date().addingTimeInterval(18 * 60),
            goal: "Finish the chapter",
            focusMinutesToday: 95,
            sessionsToday: 2,
            streak: 4,
            weekMinutes: [50, 100, 75, 0, 95, 0, 0]
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (LockInEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : LockInEntry(date: Date(), snapshot: SharedContainer.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LockInEntry>) -> Void) {
        let now = Date()
        let snapshot = SharedContainer.load()
        var entries = [LockInEntry(date: now, snapshot: snapshot)]

        // One more entry just after the phase ends, so the widget stops
        // counting even if the app's own refresh is late. The app reloads the
        // timeline itself whenever the phase changes.
        if let end = snapshot?.phaseEndsAt, end > now {
            entries.append(LockInEntry(date: end.addingTimeInterval(61), snapshot: snapshot))
        }

        var refresh = now.addingTimeInterval(30 * 60)
        if let start = snapshot?.nextScheduleStart, start > now {
            refresh = min(refresh, start.addingTimeInterval(30))
        }
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }
}

// MARK: - Buttons

/// Runs in the widget's sandbox, so it cannot touch the app directly; it
/// posts a Darwin notification that the running app listens for.
struct WidgetCommandIntent: AppIntent {
    static let title: LocalizedStringResource = "LockIn Command"
    static let isDiscoverable = false

    @Parameter(title: "Command")
    var command: String

    init() {}

    init(_ command: String) {
        self.command = command
    }

    func perform() async throws -> some IntentResult {
        let name = CFNotificationName((SharedContainer.commandNotificationPrefix + command) as CFString)
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), name, nil, nil, true)
        // Give the app a moment to write its new state before the widget redraws.
        try? await Task.sleep(nanoseconds: 700_000_000)
        return .result()
    }
}

// MARK: - Views

private enum Palette {
    static let canvas = Color(red: 0.961, green: 0.949, blue: 0.910)
    static let canvasDark = Color(red: 0.106, green: 0.137, blue: 0.118)
    static let accent = Color(red: 0.231, green: 0.380, blue: 0.282)
    static let accentLight = Color(red: 0.498, green: 0.722, blue: 0.612)
    static let clay = Color(red: 0.722, green: 0.451, blue: 0.333)
}

struct LockInWidgetView: View {
    let entry: LockInEntry
    /// Set only when rendering outside WidgetKit, which otherwise supplies it.
    var familyOverride: WidgetFamily?
    @Environment(\.widgetFamily) private var environmentFamily
    @Environment(\.colorScheme) private var colorScheme

    private var family: WidgetFamily { familyOverride ?? environmentFamily }

    private var accent: Color { colorScheme == .dark ? Palette.accentLight : Palette.accent }

    var body: some View {
        Group {
            if family == .systemMedium {
                HStack(alignment: .top, spacing: 16) {
                    mainColumn
                    Divider()
                    sideColumn
                }
            } else {
                mainColumn
            }
        }
        .containerBackground(for: .widget) {
            colorScheme == .dark ? Palette.canvasDark : Palette.canvas
        }
        .widgetURL(URL(string: "lockin://"))
    }

    private var snapshot: WidgetSnapshot? { entry.snapshot }

    private var isRunning: Bool {
        !entry.isAppAway && (snapshot?.isRunning ?? false) && (snapshot?.phaseEndsAt ?? .distantPast) > entry.date
    }

    private var mainColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                if snapshot?.isStrict == true && isRunning {
                    Image(systemName: "lock.fill")
                }
                Text(phaseLabel.uppercased())
            }
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(accent)

            clock
                .font(.system(size: family == .systemMedium ? 34 : 30, weight: .regular, design: .serif))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            if let goal = snapshot?.goal, !goal.isEmpty {
                Text(goal)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(family == .systemMedium ? 2 : 1)
            }

            Spacer(minLength: 0)

            actionButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var clock: some View {
        if isRunning, let end = snapshot?.phaseEndsAt {
            Text(timerInterval: entry.date...end, countsDown: true)
        } else {
            Text(String(format: "%02d:00", snapshot?.focusMinutes ?? 50))
        }
    }

    private var phaseLabel: String {
        if entry.isAppAway && snapshot?.isRunning == true { return "LockIn closed" }
        guard isRunning, let snapshot else { return "Ready" }
        switch snapshot.phase {
        case .focus: return snapshot.isStrict ? "Strict focus" : "Focus"
        case .break: return "Break"
        default: return "Ready"
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if entry.snapshot == nil || entry.isAppAway {
            Link(destination: URL(string: "lockin://")!) {
                pill("Open LockIn", systemImage: "arrow.up.forward.app")
            }
        } else if isRunning, snapshot?.phase == .break {
            Button(intent: WidgetCommandIntent("skip")) {
                pill("Next block", systemImage: "forward.end.fill")
            }
            .buttonStyle(.plain)
        } else if isRunning, snapshot?.isStrict == true {
            pill("Locked", systemImage: "lock.fill")
                .opacity(0.6)
        } else if isRunning {
            Button(intent: WidgetCommandIntent("stop")) {
                pill("Stop", systemImage: "stop.fill")
            }
            .buttonStyle(.plain)
        } else {
            Button(intent: WidgetCommandIntent("start")) {
                pill("Start", systemImage: "play.fill")
            }
            .buttonStyle(.plain)
        }
    }

    private func pill(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(colorScheme == .dark ? Palette.canvasDark : Palette.canvas)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(accent))
    }

    private var sideColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            stat("Today", value: duration(snapshot?.focusMinutesToday ?? 0))
            stat("Streak", value: "\(snapshot?.streak ?? 0) day\((snapshot?.streak ?? 0) == 1 ? "" : "s")")
            weekBars
            if let name = snapshot?.nextScheduleName, let start = snapshot?.nextScheduleStart, !isRunning {
                Text("\(name) · \(start, format: .dateTime.weekday(.abbreviated).hour().minute())")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 118, alignment: .leading)
    }

    private func stat(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 15, design: .serif))
        }
    }

    private var weekBars: some View {
        let minutes = snapshot?.weekMinutes ?? []
        let peak = max(1, minutes.max() ?? 1)
        return HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(minutes.enumerated()), id: \.offset) { _, value in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(value > 0 ? accent : Color.secondary.opacity(0.25))
                    .frame(width: 10, height: max(3, 26 * CGFloat(value) / CGFloat(peak)))
            }
        }
        .frame(height: 26, alignment: .bottom)
    }

    private func duration(_ minutes: Int) -> String {
        minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
}
