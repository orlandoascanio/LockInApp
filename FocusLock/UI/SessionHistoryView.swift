import FocusLockCore
import SwiftUI

struct SessionHistoryView: View {
    @EnvironmentObject private var controller: MenuBarController
    @State private var selectedCategory = ""

    private var stats: SessionStats {
        selectedCategory.isEmpty ? controller.sessionStats : SessionStats.make(from: filteredHistory)
    }

    /// Entries with no category — including everything recorded before
    /// categories existed — collect under one name rather than an empty label.
    private func categoryName(for entry: SessionHistoryEntry) -> String {
        let name = entry.task?.category ?? ""
        return name.isEmpty ? "Uncategorized" : name
    }

    private var categories: [String] {
        Array(Set(controller.history.map(categoryName))).sorted()
    }

    private var filteredHistory: [SessionHistoryEntry] {
        guard !selectedCategory.isEmpty else {
            return controller.history
        }
        return controller.history.filter { categoryName(for: $0) == selectedCategory }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StatsHeader {
                ExportView()
            }

            if controller.history.isEmpty {
                FLEmptyState(
                    systemImage: "clock",
                    title: "No sessions yet",
                    detail: "Finish a focus block and it will be recorded here."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    FLRule()
                    summaryRow
                        .flBand(vertical: 18)
                    FLRule()

                    HStack(spacing: 10) {
                        FLMenuPicker(
                            options: [""] + categories,
                            selection: selectedCategory,
                            title: { $0.isEmpty ? "All categories" : $0 },
                            onSelect: { selectedCategory = $0 },
                            width: 200,
                            accessibilityLabel: "Category"
                        )
                        Spacer()
                        Text(countLine)
                            .font(FLTypography.callout)
                            .foregroundStyle(Color.flInkSoft)
                    }
                    .padding(.horizontal, FLLayout.pageInset)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                    columnHeaders
                    rows
                }
            }

            if let message = controller.exportMessage {
                Text(message)
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flInkSoft)
                    .padding(.horizontal, FLLayout.pageInset)
                    .padding(.bottom, 12)
            }
        }
    }

    private var countLine: String {
        let count = filteredHistory.count
        let noun = "\(count) session\(count == 1 ? "" : "s")"
        return selectedCategory.isEmpty ? "\(noun) recorded" : "\(noun) in \(selectedCategory)"
    }

    private var summaryRow: some View {
        HStack(spacing: 20) {
            // Nothing yet today: lead with the last day there was something,
            // so coming back opens on what you did rather than four zeros.
            if let last = resumeDay {
                let day = Self.weekday(last.date)
                summaryItem(formatted(minutes: last.minutes), "focused \(day)")
                FLColumnRule()
                summaryItem("\(last.sessions)", last.sessions == 1 ? "session \(day)" : "sessions \(day)")
            } else {
                summaryItem(formatted(minutes: stats.focusMinutesToday), "focused today")
                FLColumnRule()
                summaryItem("\(stats.sessionsCompletedToday)", "sessions today")
            }
            FLColumnRule()
            if selectedCategory.isEmpty {
                summaryItem(formatted(minutes: controller.recentSummary.totalMinutes), "last 7 days")
                if controller.streak > 0 {
                    FLColumnRule()
                    summaryItem("\(controller.streak)", "day streak")
                }
            } else {
                summaryItem(formatted(minutes: stats.focusMinutesThisWeek), "this week")
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// The last day with focus, when today has none and no category is
    /// narrowing the view.
    private var resumeDay: DailyFocus? {
        guard selectedCategory.isEmpty, stats.focusMinutesToday == 0,
              let last = controller.lastActiveDay, !last.isToday else { return nil }
        return last
    }

    /// "Fri" within the week, "Sep 28" before it.
    private static func weekday(_ date: Date) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: Date())
        ).day ?? 0
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate(days < 7 ? "EEE" : "MMM d")
        return formatter.string(from: date)
    }

    private func summaryItem(_ value: String, _ label: String) -> some View {
        FLFigure(label: label.prefix(1).uppercased() + label.dropFirst(), value: value)
    }

    private var columnHeaders: some View {
        HStack(spacing: HistoryTableLayout.columnSpacing) {
            FLColumnLabel(text: "When")
                .frame(maxWidth: .infinity, alignment: .leading)

            FLColumnLabel(text: "Focus")
                .frame(width: HistoryTableLayout.focusWidth, alignment: .leading)

            FLColumnLabel(text: "Outcome")
                .frame(width: HistoryTableLayout.outcomeWidth, alignment: .leading)

            FLColumnLabel(text: "Guarded")
                .frame(width: HistoryTableLayout.guardedWidth, alignment: .trailing)
        }
        .padding(.horizontal, FLLayout.pageInset)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            FLRule().padding(.horizontal, FLLayout.pageInset)
        }
    }

    private var rows: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredHistory) { entry in
                    HistoryRow(entry: entry, peakMinutes: peakMinutes)
                    if entry.id != filteredHistory.last?.id {
                        FLRowDivider(inset: FLLayout.pageInset)
                    }
                }
            }
        }
    }

    private var peakMinutes: Int {
        max(filteredHistory.map(\.focusMinutes).max() ?? 1, 1)
    }

    private func formatted(minutes: Int) -> String {
        guard minutes >= 60 else {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }
}

private enum HistoryTableLayout {
    static let columnSpacing: CGFloat = 16
    static let focusWidth: CGFloat = 116
    static let outcomeWidth: CGFloat = 112
    static let guardedWidth: CGFloat = 74
}

private struct HistoryRow: View {
    let entry: SessionHistoryEntry
    let peakMinutes: Int
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: HistoryTableLayout.columnSpacing) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Self.stamp(for: entry.startedAt)).font(.system(size: 12.5))
                if let task = entry.task {
                    Text(task.goal.isEmpty ? task.category : "\(task.category) · \(task.goal)")
                        .font(.caption).foregroundStyle(Color.flInkSoft).lineLimit(2)
                        .help(task.goal)
                }
                if let checkIn = entry.checkIn {
                    Text(checkIn.outcome.title).font(.caption).foregroundStyle(checkIn.outcome.tint)
                    if !checkIn.note.isEmpty {
                        Text(checkIn.note).font(.caption).foregroundStyle(Color.flInkSoft)
                            .lineLimit(2).help(checkIn.note)
                    }
                }
            }
            .foregroundStyle(Color.flInk)
            .frame(maxWidth: .infinity, alignment: .leading)

            // The bar makes long and short blocks comparable at a glance,
            // without a second chart.
            HStack(spacing: 8) {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.flSunken)

                    Capsule()
                        .fill(tint)
                        .frame(width: barWidth)
                }
                .frame(width: 44, height: 6)

                Text("\(entry.focusMinutes)m")
                    .font(.system(size: 12.5, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Color.flInk)
            }
            .frame(width: HistoryTableLayout.focusWidth, alignment: .leading)

            HStack(spacing: 7) {
                Circle()
                    .fill(tint)
                    .frame(width: 6, height: 6)

                Text(entry.status.displayName)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.flInk)
            }
            .frame(width: HistoryTableLayout.outcomeWidth, alignment: .leading)

            HStack(spacing: 6) {
                Image(systemName: "shield.fill")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.flInkSoft.opacity(0.72))

                Text("\(entry.blockedAppsCount)")
                    .font(.system(size: 12.5, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Color.flInk)
            }
            .frame(width: HistoryTableLayout.guardedWidth, alignment: .trailing)
        }
        .padding(.horizontal, FLLayout.pageInset)
        .padding(.vertical, 11)
        .frame(minHeight: 46)
        .background(isHovered ? Color.flSunken : .clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .combine)
    }

    private var barWidth: CGFloat {
        let ratio = CGFloat(entry.focusMinutes) / CGFloat(peakMinutes)
        return max(4, 44 * ratio)
    }

    private var tint: Color {
        switch entry.status {
        case .completed:
            return .flAccent
        case .cancelled:
            return .flInkSoft
        case .abandoned:
            return .flClay
        }
    }

    private static func stamp(for date: Date) -> String {
        let calendar = Calendar.current
        let time = timeFormatter.string(from: date)

        if calendar.isDateInToday(date) {
            return "Today, \(time)"
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday, \(time)"
        }
        return "\(dateFormatter.string(from: date)), \(time)"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}
