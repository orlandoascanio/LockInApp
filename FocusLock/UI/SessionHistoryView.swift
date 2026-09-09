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
            header

            if controller.history.isEmpty {
                FLEmptyState(
                    systemImage: "clock",
                    title: "No sessions yet",
                    detail: "Finish a focus block and it will be recorded here."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack {
                    Picker("Category", selection: $selectedCategory) {
                        Text("All categories").tag("")
                        ForEach(categories, id: \.self) {
                            Text($0).tag($0)
                        }
                    }.frame(maxWidth: 300)
                    Spacer()
                }.padding(.horizontal, 26).padding(.bottom, 16)
                summaryRow
                FLRule()
                columnHeaders
                rows
            }

            if let message = controller.exportMessage {
                FLRule()
                Text(message)
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flInkSoft)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 10)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("History")
                    .font(FLTypography.display)
                    .foregroundStyle(Color.flInk)

                Text(countLine)
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flInkSoft)
            }

            Spacer()

            ExportView()
        }
        .padding(.horizontal, 26)
        .padding(.top, 28)
        .padding(.bottom, 20)
    }

    private var countLine: String {
        let count = filteredHistory.count
        let noun = "\(count) session\(count == 1 ? "" : "s")"
        return selectedCategory.isEmpty ? "\(noun) recorded" : "\(noun) in \(selectedCategory)"
    }

    private var summaryRow: some View {
        HStack(spacing: FLSpacing.xl) {
            summaryItem(formatted(minutes: stats.focusMinutesToday), "focused today")
            summaryItem("\(stats.sessionsCompletedToday)", "sessions today")
            summaryItem(formatted(minutes: stats.focusMinutesThisWeek), "this week")
            if selectedCategory.isEmpty {
                summaryItem("\(controller.streak)", "day streak")
            }
            Spacer()
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 22)
    }

    private func summaryItem(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 26, design: .serif))
                .monospacedDigit()
                .foregroundStyle(Color.flInk)

            Text(label)
                .font(FLTypography.caption)
                .foregroundStyle(Color.flInkSoft)
        }
    }

    private var columnHeaders: some View {
        HStack(spacing: HistoryTableLayout.columnSpacing) {
            FLMicroLabel(text: "When")
                .frame(maxWidth: .infinity, alignment: .leading)

            FLMicroLabel(text: "Focus")
                .frame(width: HistoryTableLayout.focusWidth, alignment: .leading)

            FLMicroLabel(text: "Outcome")
                .frame(width: HistoryTableLayout.outcomeWidth, alignment: .leading)

            FLMicroLabel(text: "Guarded")
                .frame(width: HistoryTableLayout.guardedWidth, alignment: .trailing)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 11)
        .background(Color.flCanvasWarm.opacity(0.46))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.flHairline.opacity(0.72))
                .frame(height: 1)
        }
    }

    private var rows: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredHistory) { entry in
                    HistoryRow(entry: entry, peakMinutes: peakMinutes)
                    Rectangle()
                        .fill(Color.flHairline.opacity(0.5))
                        .frame(height: 1)
                        .padding(.horizontal, 26)
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
                    Text(checkIn.outcome.title).font(.caption).foregroundStyle(Color.flAccentDeep)
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
                        .fill(Color.flHairline.opacity(0.48))

                    Capsule()
                        .fill(tint)
                        .frame(width: barWidth)
                }
                .frame(width: 44, height: 6)

                Text("\(entry.focusMinutes)m")
                    .font(.system(size: 12.5, design: .serif))
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
                    .font(.system(size: 12.5, design: .serif))
                    .monospacedDigit()
                    .foregroundStyle(Color.flInk)
            }
            .frame(width: HistoryTableLayout.guardedWidth, alignment: .trailing)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 12)
        .frame(minHeight: 46)
        .background(isHovered ? Color.flCanvasWarm.opacity(0.38) : .clear)
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
