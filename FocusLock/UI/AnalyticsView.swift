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

            Picker("Time range", selection: $period) {
                ForEach(SessionAnalyticsPeriod.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 238)
            .accessibilityLabel("Analytics time range")
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

                HStack(spacing: 6) {
                    Rectangle()
                        .fill(Color.flInkSoft.opacity(0.55))
                        .frame(width: 18, height: 1)

                    Text("avg \(formatted(minutes: averagePerBucket))/\(bucketName)")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.flInkSoft)
                        .monospacedDigit()
                }
                .accessibilityElement(children: .combine)
            }

            Chart {
                ForEach(analytics.timeline) { point in
                    BarMark(
                        x: .value("Period", point.startDate, unit: chartCalendarComponent),
                        y: .value("Focus minutes", point.minutes)
                    )
                    .foregroundStyle(
                        isCurrent(point)
                            ? Color.flAccentDeep
                            : Color.flAccent.opacity(point.minutes == 0 ? 0.18 : 0.62)
                    )
                    .cornerRadius(3)
                    .accessibilityLabel(chartPointLabel(point))
                    .accessibilityValue("\(point.minutes) focus minutes")
                }

                if averagePerBucket > 0 {
                    RuleMark(y: .value("Average focus", averagePerBucket))
                        .foregroundStyle(Color.flInkSoft.opacity(0.55))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .accessibilityLabel("Average")
                        .accessibilityValue("\(averagePerBucket) focus minutes per \(bucketName)")
                }
            }
            .chartYScale(domain: 0...chartMaximum)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: desiredXAxisCount)) { value in
                    AxisTick(stroke: StrokeStyle(lineWidth: 1))
                        .foregroundStyle(Color.flHairline)
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(axisLabel(for: date))
                                .font(.system(size: 9.5))
                                .foregroundStyle(Color.flInkSoft)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.7))
                        .foregroundStyle(Color.flHairline.opacity(0.5))
                    AxisValueLabel {
                        if let minutes = value.as(Int.self) {
                            Text(shortAxisMinutes(minutes))
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

    private var chartMaximum: Int {
        let peak = max(analytics.timeline.map(\.minutes).max() ?? 0, averagePerBucket)
        if peak <= 30 {
            return 30
        }
        if peak <= 60 {
            return 60
        }
        return Int(ceil(Double(peak) / 30.0) * 30.0)
    }

    private var desiredXAxisCount: Int {
        switch analytics.granularity {
        case .day:
            return period == .sevenDays ? 7 : 6
        case .week:
            return min(8, max(4, analytics.timeline.count))
        case .month:
            return min(8, max(4, analytics.timeline.count))
        }
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

    private func shortAxisMinutes(_ minutes: Int) -> String {
        return "\(minutes)m"
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
