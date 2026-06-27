import FocusLockCore
import SwiftUI

struct SessionHistoryView: View {
    @EnvironmentObject private var controller: MenuBarController

    private var stats: SessionStats {
        controller.stats()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FLSpacing.lg) {
            header

            statsGrid

            FLSurface {
                ExportView()
            }

            FLSurface {
                historyList
            }
        }
        .padding(FLSpacing.lg)
        .background(Color.flBackground)
        .frame(minWidth: 720, minHeight: 540)
    }

    private var header: some View {
        HStack(spacing: FLSpacing.md) {
            Image(systemName: "chart.bar.xaxis")
                .font(.title2)
                .foregroundStyle(Color.flFocus)
                .frame(width: 44, height: 44)
                .background(Color.flFocusSurface, in: RoundedRectangle(cornerRadius: FLRadius.lg, style: .continuous))
                .symbolRenderingMode(.hierarchical)

            VStack(alignment: .leading, spacing: FLSpacing.xs) {
                Text("Session History")
                    .font(FLTypography.title)
                    .foregroundStyle(Color.flTextPrimary)

                Text("Track sessions and export the data.")
                    .font(.callout)
                    .foregroundStyle(Color.flTextSecondary)
            }

            Spacer()
        }
    }

    private var statsGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: FLSpacing.sm, verticalSpacing: FLSpacing.sm) {
            GridRow {
                FLStatCard(value: "\(stats.focusMinutesToday)m", label: "Today's focus minutes", systemImage: "target")
                FLStatCard(value: "\(stats.sessionsCompletedToday)", label: "Completed sessions today", systemImage: "checkmark.circle.fill", accent: .flSuccess)
                FLStatCard(value: "\(stats.sessionsCompletedThisWeek)", label: "Completed sessions this week", systemImage: "calendar")
                FLStatCard(value: "\(stats.totalSessions)", label: "Total sessions", systemImage: "infinity")
            }
        }
    }

    private var historyList: some View {
        VStack(alignment: .leading, spacing: FLSpacing.md) {
            FLSectionHeader(title: "Sessions", systemImage: "list.bullet.rectangle")

            if controller.history.isEmpty {
                FLEmptyState(
                    systemImage: "clock",
                    title: "No sessions yet",
                    detail: "Start a focus session to track your progress."
                )
                .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                VStack(spacing: FLSpacing.xs) {
                    historyHeader

                    ScrollView {
                        VStack(spacing: FLSpacing.xs) {
                            ForEach(controller.history) { entry in
                                HistoryRow(entry: entry)
                            }
                        }
                    }
                    .frame(minHeight: 260)
                }
            }
        }
    }

    private var historyHeader: some View {
        Grid(alignment: .leading, horizontalSpacing: FLSpacing.sm) {
            GridRow {
                Text("Date").frame(width: 112, alignment: .leading)
                Text("Start").frame(width: 72, alignment: .leading)
                Text("End").frame(width: 72, alignment: .leading)
                Text("Duration").frame(width: 84, alignment: .leading)
                Text("Status").frame(width: 96, alignment: .leading)
                Text("Apps").frame(width: 56, alignment: .leading)
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.flTextTertiary)
        .padding(.horizontal, FLSpacing.sm)
    }
}

private struct HistoryRow: View {
    var entry: SessionHistoryEntry

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: FLSpacing.sm) {
            GridRow {
                Text(Self.dateFormatter.string(from: entry.startedAt))
                    .frame(width: 112, alignment: .leading)
                Text(Self.timeFormatter.string(from: entry.startedAt))
                    .frame(width: 72, alignment: .leading)
                    .monospacedDigit()
                Text(Self.timeFormatter.string(from: entry.endedAt))
                    .frame(width: 72, alignment: .leading)
                    .monospacedDigit()
                Text("\(entry.durationMinutes)m")
                    .frame(width: 84, alignment: .leading)
                    .monospacedDigit()
                Text(entry.status.displayName)
                    .foregroundStyle(entry.status == .completed ? Color.flSuccess : Color.flWarning)
                    .frame(width: 96, alignment: .leading)
                Text("\(entry.blockedAppsCount)")
                    .frame(width: 56, alignment: .leading)
                    .monospacedDigit()
            }
        }
        .font(.callout)
        .padding(.horizontal, FLSpacing.sm)
        .padding(.vertical, FLSpacing.sm)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: FLRadius.sm, style: .continuous))
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
