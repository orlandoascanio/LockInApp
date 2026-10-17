import Charts
import FocusLockCore
import SwiftUI

struct AnalyticsView: View {
    @EnvironmentObject private var controller: MenuBarController
    @State private var period: SessionAnalyticsPeriod = .thirtyDays
    @State private var customStart = Calendar.current.date(byAdding: .day, value: -13, to: Date()) ?? Date()
    @State private var customEnd = Date()

    private var analytics: SessionAnalyticsSnapshot {
        SessionAnalytics.snapshot(
            history: controller.history,
            period: period,
            referenceDate: period == .custom ? customEnd : Date(),
            customStart: customStart
        )
    }

    /// Nothing before the first session can hold anything, and nothing after
    /// today.
    private var earliestDay: Date {
        controller.history.map(\.startedAt).min().map { Calendar.current.startOfDay(for: $0) } ?? Date()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StatsHeader {
                VStack(alignment: .trailing, spacing: 10) {
                    FLSegmentedControl(
                        options: SessionAnalyticsPeriod.allCases,
                        selection: $period,
                        title: \.title,
                        accessibilityLabel: "Analytics time range"
                    )

                    if period == .custom {
                        customRangePicker
                    }
                }
            }

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

    private var customRangePicker: some View {
        HStack(spacing: 8) {
            DatePicker(
                "From",
                selection: Binding(
                    get: { customStart },
                    set: { customStart = min($0, customEnd) }
                ),
                in: min(earliestDay, customEnd)...Date(),
                displayedComponents: .date
            )
            Text("to")
                .font(FLTypography.caption)
                .foregroundStyle(Color.flInkSoft)
            DatePicker(
                "To",
                selection: Binding(
                    get: { customEnd },
                    set: { customEnd = max($0, customStart) }
                ),
                in: customStart...Date(),
                displayedComponents: .date
            )
        }
        .labelsHidden()
        .datePickerStyle(.compact)
        .font(FLTypography.caption)
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
            // Bands on the page divided by hairlines, as on Focus.
            VStack(spacing: 0) {
                FLRule()
                metrics.flBand(vertical: 18)
                FLRule()
                focusTrend.flBand()
                FLRule()

                HStack(alignment: .top, spacing: FLLayout.columnGap) {
                    weekdayPattern
                    FLColumnRule()
                    outcomes
                }
                .fixedSize(horizontal: false, vertical: true)
                .flBand()

                FLRule()

                Label(
                    "Focused time includes completed sessions. Cancelled and abandoned attempts remain in Outcomes.",
                    systemImage: "info.circle"
                )
                .font(FLTypography.caption)
                .foregroundStyle(Color.flInkSoft)
                .flBand(vertical: 14)
            }
        }
        .flScrollEdges(top: 0)
    }

    private var metrics: some View {
        HStack(spacing: 20) {
            FLFigure(
                label: "Focused",
                value: formatted(minutes: analytics.totalFocusMinutes),
                detail: period.detail
            )
            FLColumnRule()
            FLFigure(
                label: analytics.completedSessions == 1 ? "Session" : "Sessions",
                value: "\(analytics.completedSessions)",
                detail: "completed"
            )
            FLColumnRule()
            FLFigure(
                label: "Daily average",
                value: formatted(minutes: dailyAverage),
                detail: "over \(daysInRange) day\(daysInRange == 1 ? "" : "s")"
            )
            FLColumnRule()
            FLFigure(
                label: "Completion",
                value: analytics.completionRate.formatted(.percent.precision(.fractionLength(0))),
                detail: "\(analytics.outcomes.total) total attempts"
            )
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var focusTrend: some View {
        VStack(alignment: .leading, spacing: 18) {
            FLSectionHeader(title: "Focus over time", subtitle: periodDescription) {
                if let line = referenceLine {
                    HStack(spacing: 6) {
                        Line()
                            .stroke(Color.flInkSoft.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                            .frame(width: 18, height: 1)

                        Text(line.legend)
                            .font(FLTypography.caption)
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
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 5, topTrailingRadius: 5, style: .continuous))
                    .annotation(position: .top, spacing: 4) {
                        if showsBarValues, point.minutes > 0 {
                            Text(formatted(minutes: point.minutes))
                                .font(.system(size: 10.5, weight: isCurrent(point) ? .semibold : .regular))
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
                AxisMarks(values: xAxisDates) { value in
                    // Each mark sits at the middle of its own bar's period,
                    // and the label hangs centred under it. Centring in the
                    // span to the next mark put "Oct 7" under Oct 9.
                    AxisValueLabel(anchor: .top) {
                        if let date = value.as(Date.self) {
                            Text(axisLabel(for: date))
                                .font(.system(size: 10.5, weight: isCurrentPeriod(date) ? .semibold : .regular))
                                .foregroundStyle(isCurrentPeriod(date) ? Color.flInk : Color.flInkSoft)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: yAxisValues) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.7))
                        .foregroundStyle(Color.flHairline)
                    AxisValueLabel {
                        if let minutes = value.as(Int.self) {
                            Text(formatted(minutes: minutes))
                                .font(.system(size: 10.5))
                                .foregroundStyle(Color.flInkSoft)
                                .monospacedDigit()
                        }
                    }
                }
            }
            .frame(height: 200)
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
    }

    private func chartFootnote(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(FLTypography.micro)
                .foregroundStyle(Color.flInkSoft)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.flInk)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private var weekdayPattern: some View {
        VStack(alignment: .leading, spacing: 16) {
            FLSectionHeader(title: "Weekly pattern", subtitle: "Total focus by weekday")

            VStack(spacing: 10) {
                ForEach(analytics.weekdayFocus) { day in
                    weekdayRow(day)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func weekdayRow(_ day: WeekdayFocusSummary) -> some View {
        HStack(spacing: 10) {
            Text(Self.weekdayFormatter.string(from: day.date))
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Color.flInkSoft)
                .frame(width: 32, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.flSunken)

                    Capsule()
                        .fill(Color.flAccent.opacity(0.8))
                        .frame(width: weekdayBarWidth(day.minutes, available: geometry.size.width))
                }
            }
            .frame(height: 7)

            Text(formatted(minutes: day.minutes))
                .font(.system(size: 11.5, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(day.minutes > 0 ? Color.flInk : Color.flInkSoft)
                // Wide enough for "124h 30m" once a range runs to months.
                .frame(width: 62, alignment: .trailing)
        }
        .frame(height: 15)
        .accessibilityElement(children: .combine)
    }

    private var outcomes: some View {
        VStack(alignment: .leading, spacing: 16) {
            FLSectionHeader(
                title: "Outcomes",
                subtitle: "\(analytics.outcomes.total) session attempt\(analytics.outcomes.total == 1 ? "" : "s")"
            )

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

            FLRule()
                .padding(.top, 2)

            HStack {
                insight(label: "Average block", value: formatted(minutes: analytics.averageSessionMinutes))
                Spacer()
                insight(label: "Focused days", value: "\(analytics.activeDays)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func outcomeRow(title: String, count: Int, tint: Color) -> some View {
        let fraction = analytics.outcomes.total == 0
            ? 0
            : Double(count) / Double(analytics.outcomes.total)

        return VStack(spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.flInk)
                Spacer()
                Text("\(count) · \(fraction.formatted(.percent.precision(.fractionLength(0))))")
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(Color.flInkSoft)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.flSunken)

                    Capsule()
                        .fill(tint)
                        .frame(width: max(count > 0 ? 3 : 0, geometry.size.width * fraction))
                }
            }
            .frame(height: 7)
        }
        .accessibilityElement(children: .combine)
    }

    private func insight(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(FLTypography.micro)
                .foregroundStyle(Color.flInkSoft)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
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

    /// Calendar days in the range, today included: the same rule the Focus
    /// page's "Avg … a day" uses, so the two never disagree.
    private var daysInRange: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: analytics.startDate),
            to: calendar.startOfDay(for: analytics.endDate)
        ).day ?? 0
        return max(1, days + 1)
    }

    private var dailyAverage: Int {
        analytics.totalFocusMinutes / daysInRange
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
    /// Every nth bar, counted back from the newest so today is always
    /// labelled, each at the middle of its period.
    private var xAxisDates: [Date] {
        let points = analytics.timeline
        let every: Int
        switch analytics.granularity {
        case .day: every = points.count <= 8 ? 1 : 5
        case .week, .month: every = max(1, points.count / 6)
        }
        let calendar = Calendar.current
        return points.enumerated().compactMap { index, point in
            guard (points.count - 1 - index) % every == 0 else { return nil }
            guard let next = calendar.date(byAdding: chartCalendarComponent, value: 1, to: point.startDate) else {
                return point.startDate
            }
            return point.startDate.addingTimeInterval(next.timeIntervalSince(point.startDate) / 2)
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
        case .ninetyDays:
            return "Last 90 days"
        case .year:
            return "Last 12 months"
        case .allTime:
            return "Since \(Self.longDateFormatter.string(from: analytics.startDate))"
        case .custom:
            return "\(Self.longDateFormatter.string(from: analytics.startDate)) – \(Self.longDateFormatter.string(from: analytics.endDate))"
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
            if analytics.timeline.count <= 8 {
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

    /// "Oct 2025": a two-digit year reads as a day of the month.
    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM yyyy")
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
        case .ninetyDays:
            return "90 days"
        case .year:
            return "Year"
        case .allTime:
            return "All time"
        case .custom:
            return "Custom"
        }
    }

    var detail: String {
        switch self {
        case .sevenDays:
            return "last 7 days"
        case .thirtyDays:
            return "last 30 days"
        case .ninetyDays:
            return "last 90 days"
        case .year:
            return "last 12 months"
        case .allTime:
            return "all time"
        case .custom:
            return "in this range"
        }
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
