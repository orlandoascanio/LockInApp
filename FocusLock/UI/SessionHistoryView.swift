import FocusLockCore
import SwiftUI

struct SessionHistoryView: View {
    @EnvironmentObject private var controller: MenuBarController

    private var stats: SessionStats {
        controller.sessionStats
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
                summaryRow
                FLRule()
                columnHeaders
                Rectangle().fill(Color.flHairline).frame(height: 1).padding(.horizontal, 26)
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

                Text("\(controller.history.count) session\(controller.history.count == 1 ? "" : "s") recorded")
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

    private var summaryRow: some View {
        HStack(spacing: FLSpacing.xl) {
            summaryItem(formatted(minutes: stats.focusMinutesToday), "focused today")
            summaryItem("\(stats.sessionsCompletedToday)", "sessions today")
            summaryItem(formatted(minutes: stats.focusMinutesThisWeek), "this week")
            summaryItem("\(controller.streak)", controller.streak == 1 ? "day streak" : "day streak")
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
        HStack(spacing: 0) {
            FLMicroLabel(text: "When").frame(width: 190, alignment: .leading)
            FLMicroLabel(text: "Focus").frame(width: 90, alignment: .leading)
            FLMicroLabel(text: "Outcome").frame(width: 130, alignment: .leading)
            Spacer(minLength: 0)
            FLMicroLabel(text: "Guarded")
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 10)
    }

    private var rows: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(controller.history) { entry in
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
        max(controller.history.map(\.focusMinutes).max() ?? 1, 1)
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

private struct HistoryRow: View {
    let entry: SessionHistoryEntry
    let peakMinutes: Int

    var body: some View {
        HStack(spacing: 0) {
            Text(Self.stamp(for: entry.startedAt))
                .font(.system(size: 12.5))
                .foregroundStyle(Color.flInkSoft)
                .frame(width: 190, alignment: .leading)

            // The bar makes long and short blocks comparable at a glance,
            // without a second chart.
            HStack(spacing: 8) {
                Rectangle()
                    .fill(tint)
                    .frame(width: barWidth, height: 8)

                Text("\(entry.focusMinutes)m")
                    .font(.system(size: 12.5, design: .serif))
                    .monospacedDigit()
                    .foregroundStyle(Color.flInk)
            }
            .frame(width: 90, alignment: .leading)

            Text(entry.status.displayName)
                .font(.system(size: 12.5))
                .foregroundStyle(tint)
                .frame(width: 130, alignment: .leading)

            Spacer(minLength: 0)

            Text("\(entry.blockedAppsCount)")
                .font(.system(size: 12.5, design: .serif))
                .monospacedDigit()
                .foregroundStyle(Color.flInkSoft)
        }
        .padding(.horizontal, 26)
        .frame(height: 46)
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
