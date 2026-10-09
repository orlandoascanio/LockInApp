import Charts
import FocusLockCore
import SwiftUI

struct AnalyticsView: View {
    @EnvironmentObject private var controller: MenuBarController
    @State private var period: SessionAnalyticsPeriod = .thirtyDays

    private var analytics: SessionAnalyticsSnapshot {
        SessionAnalytics.snapshot(history: controller.history, period: period)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if controller.history.isEmpty {
                FLEmptyState(
                    systemImage: "chart.bar.xaxis",
                    title: "No patterns yet",
                    detail: "Complete a few focus sessions and your trends will appear here."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if analytics.outcomes.total == 0 {
                periodEmptyState
            } else {
                dashboard
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: FLSpacing.lg) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Analytics")
                    .font(FLTypography.display)
                    .foregroundStyle(Color.flInk)

                Text("A clear view of how your focus is changing.")
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flInkSoft)
            }

            Spacer(minLength: FLSpacing.md)

            FLSegmentedControl(
                options: SessionAnalyticsPeriod.allCases,
                selection: $period,
                title: \.title,
                accessibilityLabel: "Analytics time range"
            )
        }
        .padding(.horizontal, 26)
        .padding(.top, 28)
        .padding(.bottom, 20)
    }

    private var periodEmptyState: some View {
        VStack(spacing: FLSpacing.md) {
            FLEmptyState(
                systemImage: "calendar",
                title: "No sessions in this range",
                detail: "Choose a longer range to bring earlier sessions into view."
            )

            Button("View all time") {
                period = .allTime
            }
            .buttonStyle(FLActionButtonStyle(variant: .secondary, minHeight: 34))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var dashboard: some View {
        ScrollView {
            VStack(spacing: FLSpacing.md) {
                metrics
                focusTrend

                HStack(alignment: .top, spacing: FLSpacing.md) {
                    weekdayPattern
                    outcomes
                }

                Label(
                    "Focused time includes completed sessions. Cancelled and abandoned attempts remain in Outcomes.",
                    systemImage: "info.circle"
                )
                .font(.system(size: 10.5))
                .foregroundStyle(Color.flInkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 2)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 26)
        }
    }

    private var metrics: some View {
        HStack(spacing: 0) {
            metric(
                value: formatted(minutes: analytics.totalFocusMinutes),
                label: "focused",
                detail: period.detail
            )

            metricDivider

            metric(
                value: "\(analytics.completedSessions)",
                label: analytics.completedSessions == 1 ? "session" : "sessions",
                detail: "completed"
            )

            metricDivider

            metric(
                value: formatted(minutes: analytics.averageFocusMinutesPerActiveDay),
                label: "daily average",
                detail: "on active days"
            )

            metricDivider

            metric(
                value: analytics.completionRate.formatted(.percent.precision(.fractionLength(0))),
                label: "completion",
                detail: "\(analytics.outcomes.total) total attempts"
            )
        }
        .padding(.vertical, 17)
        .analyticsPanel()
    }

    private func metric(value: String, label: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 24, design: .serif))
                .monospacedDigit()
                .foregroundStyle(Color.flInk)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(label)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Color.flInk)
                .lineLimit(1)

            Text(detail)
                .font(.system(size: 10))
                .foregroundStyle(Color.flInkSoft)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(Color.flHairline.opacity(0.65))
            .frame(width: 1, height: 54)
    }

    private var focusTrend: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    FLMicroLabel(text: "Focus over time")
                    Text(periodDescription)
                        .font(FLTypography.caption)
                        .foregroundStyle(Color.flInkSoft)
                }

                Spacer()

                if let line = referenceLine {
                    HStack(spacing: 6) {
                        Line()
                            .stroke(Color.flInkSoft.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                            .frame(width: 18, height: 1)

                        Text(line.legend)
                            .font(.system(size: 10.5))
                            .foregroundStyle(Color.flInkSoft)
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            Chart {
                if let line = referenceLine {
                    // Drawn first so the bars sit on top of it.
                    RuleMark(y: .value(line.name, line.minutes))
                        .foregroundStyle(Color.flInkSoft.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                        .accessibilityLabel(line.name)
                        .accessibilityValue(line.legend)
                }

                ForEach(analytics.timeline) { point in
                    BarMark(
                        x: .value("Period", point.startDate, unit: chartCalendarComponent),
                        y: .value("Focus minutes", point.minutes),
                        width: barWidth
                    )
                    .foregroundStyle(isCurrent(point) ? Color.flAccentDeep : Color.flAccent.opacity(0.62))
                    // Rounded on top only, so bars stand on the baseline.
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4, style: .continuous))
                    .annotation(position: .top, spacing: 4) {
                        if showsBarValues, point.minutes > 0 {
                            Text(formatted(minutes: point.minutes))
                                .font(.system(size: 10, weight: isCurrent(point) ? .semibold : .regular))
                                .foregroundStyle(isCurrent(point) ? Color.flInk : Color.flInkSoft)
                                .monospacedDigit()
                        }
                    }
                    .accessibilityLabel(chartPointLabel(point))
                    .accessibilityValue("\(formatted(minutes: point.minutes)) of focus")
                }
            }
            .chartYScale(domain: 0...chartMaximum)
            .chartXAxis {
                AxisMarks(values: xAxisValues) { value in
                    // Centred in its day, week or month: under the bar, not
                    // at the boundary before it.
                    AxisValueLabel(centered: true) {
                        if let date = value.as(Date.self) {
                            Text(axisLabel(for: date))
                                .font(.system(size: 9.5, weight: isCurrentPeriod(date) ? .semibold : .regular))
                                .foregroundStyle(isCurrentPeriod(date) ? Color.flInk : Color.flInkSoft)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: yAxisValues) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.7))
                        .foregroundStyle(Color.flHairline.opacity(0.5))
                    AxisValueLabel {
                        if let minutes = value.as(Int.self) {
                            Text(formatted(minutes: minutes))
                                .font(.system(size: 9.5))
                                .foregroundStyle(Color.flInkSoft)
                                .monospacedDigit()
                        }
                    }
                }
            }
            .frame(height: 184)
            .accessibilityLabel("Focus over time")
            .accessibilityHint("A bar chart of completed focus minutes for \(periodDescription.lowercased()).")

            HStack(spacing: FLSpacing.xl) {
                chartFootnote(
                    label: "Active days",
                    value: "\(analytics.activeDays)"
                )
                chartFootnote(
                    label: "Best day",
                    value: bestDaySummary
                )
                chartFootnote(
                    label: "Longest block",
                    value: formatted(minutes: analytics.longestSessionMinutes)
                )
                Spacer(minLength: 0)
            }
        }
        .padding(18)
        .analyticsPanel()
    }

    private func chartFootnote(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9.5))
                .foregroundStyle(Color.flInkSoft)
            Text(value)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Color.flInk)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private var weekdayPattern: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                FLMicroLabel(text: "Weekly pattern")
                Text("Total focus by weekday")
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flInkSoft)
            }

            VStack(spacing: 8) {
                ForEach(analytics.weekdayFocus) { day in
                    weekdayRow(day)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .analyticsPanel()
    }

    private func weekdayRow(_ day: WeekdayFocusSummary) -> some View {
        HStack(spacing: 9) {
            Text(Self.weekdayFormatter.string(from: day.date))
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Color.flInkSoft)
                .frame(width: 28, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.flHairline.opacity(0.45))

                    Capsule()
                        .fill(Color.flAccent.opacity(0.72))
                        .frame(width: weekdayBarWidth(day.minutes, available: geometry.size.width))
                }
            }
            .frame(height: 6)

            Text(formatted(minutes: day.minutes))
                .font(.system(size: 10.5, design: .serif))
                .monospacedDigit()
                .foregroundStyle(day.minutes > 0 ? Color.flInk : Color.flInkSoft)
                .frame(width: 44, alignment: .trailing)
        }
        .frame(height: 13)
        .accessibilityElement(children: .combine)
    }

    private var outcomes: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                FLMicroLabel(text: "Outcomes")
                Text("\(analytics.outcomes.total) session attempt\(analytics.outcomes.total == 1 ? "" : "s")")
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flInkSoft)
            }

            outcomeRow(
                title: "Completed",
                count: analytics.outcomes.completed,
                tint: .flAccentDeep
            )
            outcomeRow(
                title: "Cancelled",
                count: analytics.outcomes.cancelled,
                tint: .flInkSoft
            )
            outcomeRow(
                title: "Abandoned",
                count: analytics.outcomes.abandoned,
                tint: .flClay
            )

            Rectangle()
                .fill(Color.flHairline.opacity(0.6))
                .frame(height: 1)
                .padding(.top, 2)

            HStack {
                insight(label: "Average block", value: formatted(minutes: analytics.averageSessionMinutes))
                Spacer()
                insight(label: "Focused days", value: "\(analytics.activeDays)")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .analyticsPanel()
    }

    private func outcomeRow(title: String, count: Int, tint: Color) -> some View {
        let fraction = analytics.outcomes.total == 0
            ? 0
            : Double(count) / Double(analytics.outcomes.total)

        return VStack(spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Color.flInk)
                Spacer()
                Text("\(count) · \(fraction.formatted(.percent.precision(.fractionLength(0))))")
                    .font(.system(size: 10.5))
                    .monospacedDigit()
                    .foregroundStyle(Color.flInkSoft)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.flHairline.opacity(0.45))

                    Capsule()
                        .fill(tint)
                        .frame(width: max(count > 0 ? 3 : 0, geometry.size.width * fraction))
                }
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .combine)
    }

    private func insight(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9.5))
                .foregroundStyle(Color.flInkSoft)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Color.flInk)
        }
        .accessibilityElement(children: .combine)
    }

    private var averagePerBucket: Int {
        guard !analytics.timeline.isEmpty else {
            return 0
        }
        return analytics.totalFocusMinutes / analytics.timeline.count
    }

    private var bucketName: String {
        switch analytics.granularity {
        case .day:
            return "day"
        case .week:
            return "week"
        case .month:
            return "month"
        }
    }

    private var chartCalendarComponent: Calendar.Component {
        switch analytics.granularity {
        case .day:
            return .day
        case .week:
            return .weekOfYear
        case .month:
            return .month
        }
    }

    /// The dotted line: the daily goal on a chart of days, as on the Focus
    /// page; the average on a chart of weeks or months, where a daily goal
    /// means nothing.
    private var referenceLine: (name: String, minutes: Int, legend: String)? {
        switch analytics.granularity {
        case .day:
            let goal = controller.config.dailyFocusGoalMinutes
            return ("Daily goal", goal, "\(formatted(minutes: goal)) daily goal")
        case .week, .month:
            guard averagePerBucket > 0 else { return nil }
            return ("Average", averagePerBucket, "avg \(formatted(minutes: averagePerBucket)) a \(bucketName)")
        }
    }

    /// Gridline spacing in minutes: a round step that gives three to five lines.
    private var yAxisStep: Int {
        let top = max(analytics.timeline.map(\.minutes).max() ?? 0, referenceLine?.minutes ?? 0, 1)
        let steps = [15, 30, 60, 120, 180, 240, 360, 480, 600, 720, 1_200, 1_800, 2_400, 3_600, 6_000]
        return steps.first { top <= $0 * 4 } ?? steps.last!
    }

    /// The top of the scale: the best period or the reference line, rounded
    /// up to the next gridline. Never the best period itself, so one good
    /// day doesn't touch the ceiling.
    private var chartMaximum: Int {
        let top = max(analytics.timeline.map(\.minutes).max() ?? 0, referenceLine?.minutes ?? 0, 1)
        return (top / yAxisStep + 1) * yAxisStep
    }

    private var yAxisValues: [Int] {
        Array(stride(from: 0, through: chartMaximum, by: yAxisStep))
    }

    /// Every day for a week; otherwise every few periods, so labels never
    /// crowd.
    private var xAxisValues: AxisMarkValues {
        switch analytics.granularity {
        case .day:
            return .stride(by: .day, count: period == .sevenDays ? 1 : 5)
        case .week:
            return .stride(by: .weekOfYear, count: max(1, analytics.timeline.count / 6))
        case .month:
            return .stride(by: .month, count: max(1, analytics.timeline.count / 6))
        }
    }

    /// Slim bars: a fixed width while there are few of them, a share of
    /// each slot once there are enough that a fixed width wouldn't fit.
    private var barWidth: MarkDimension {
        analytics.timeline.count <= 12 ? .fixed(28) : .ratio(0.6)
    }

    /// Values above the bars only where there is room for them.
    private var showsBarValues: Bool {
        analytics.timeline.count <= 12
    }

    private func isCurrentPeriod(_ date: Date) -> Bool {
        isCurrent(SessionAnalyticsPoint(startDate: date, minutes: 0, completedSessions: 0))
    }

    private var periodDescription: String {
        switch period {
        case .sevenDays:
            return "Last 7 days"
        case .thirtyDays:
            return "Last 30 days"
        case .allTime:
            return "Since \(Self.longDateFormatter.string(from: analytics.startDate))"
        }
    }

    private var bestDaySummary: String {
        guard let bestDay = analytics.bestDay else {
            return "—"
        }
        return "\(Self.bestDayFormatter.string(from: bestDay)) · \(formatted(minutes: analytics.bestDayMinutes))"
    }

    private var weekdayPeak: Int {
        max(analytics.weekdayFocus.map(\.minutes).max() ?? 0, 1)
    }

    private func weekdayBarWidth(_ minutes: Int, available: CGFloat) -> CGFloat {
        guard minutes > 0 else {
            return 0
        }
        return max(3, available * CGFloat(minutes) / CGFloat(weekdayPeak))
    }

    private func isCurrent(_ point: SessionAnalyticsPoint) -> Bool {
        let calendar = Calendar.current
        switch analytics.granularity {
        case .day:
            return calendar.isDateInToday(point.startDate)
        case .week:
            return calendar.isDate(point.startDate, equalTo: Date(), toGranularity: .weekOfYear)
        case .month:
            return calendar.isDate(point.startDate, equalTo: Date(), toGranularity: .month)
        }
    }

    private func chartPointLabel(_ point: SessionAnalyticsPoint) -> String {
        switch analytics.granularity {
        case .day:
            return Self.chartDayFormatter.string(from: point.startDate)
        case .week:
            return "Week of \(Self.shortDateFormatter.string(from: point.startDate))"
        case .month:
            return Self.monthFormatter.string(from: point.startDate)
        }
    }

    private func axisLabel(for date: Date) -> String {
        switch analytics.granularity {
        case .day:
            if period == .sevenDays {
                return Self.chartDayFormatter.string(from: date)
            }
            return Self.shortDateFormatter.string(from: date)
        case .week:
            return Self.shortDateFormatter.string(from: date)
        case .month:
            return Self.monthFormatter.string(from: date)
        }
    }

    private func formatted(minutes: Int) -> String {
        guard minutes >= 60 else {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }

    private static let longDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter
    }()

    private static let chartDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE d")
        return formatter
    }()

    private static let bestDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE, MMM d")
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM yy")
        return formatter
    }()
}

private extension SessionAnalyticsPeriod {
    var title: String {
        switch self {
        case .sevenDays:
            return "7 days"
        case .thirtyDays:
            return "30 days"
        case .allTime:
            return "All time"
        }
    }

    var detail: String {
        switch self {
        case .sevenDays:
            return "last 7 days"
        case .thirtyDays:
            return "last 30 days"
        case .allTime:
            return "all time"
        }
    }
}

private extension View {
    func analyticsPanel() -> some View {
        background(
            RoundedRectangle(cornerRadius: FLRadius.lg, style: .continuous)
                .fill(Color.flCanvasWarm.opacity(0.42))
        )
        .overlay(
            RoundedRectangle(cornerRadius: FLRadius.lg, style: .continuous)
                .strokeBorder(Color.flHairline.opacity(0.7), lineWidth: 1)
        )
    }
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
