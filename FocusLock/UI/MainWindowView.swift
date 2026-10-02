import FocusLockCore
import SwiftUI

enum MainPage: String, CaseIterable, Identifiable {
    case focus
    case blockedApps
    case schedules
    case history
    case analytics
    case integrations
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus:
            return "Focus"
        case .blockedApps:
            return "Blocked"
        case .schedules:
            return "Schedules"
        case .history:
            return "History"
        case .analytics:
            return "Analytics"
        case .integrations:
            return "Integrations"
        case .settings:
            return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .focus:
            return "timer"
        case .blockedApps:
            return "shield"
        case .schedules:
            return "calendar.badge.clock"
        case .history:
            return "clock.arrow.circlepath"
        case .analytics:
            return "chart.bar.xaxis"
        case .integrations:
            return "link"
        case .settings:
            return "gearshape"
        }
    }
}

struct MainWindowView: View {
    @EnvironmentObject private var controller: MenuBarController

    var body: some View {
        Group {
            if controller.isOnboarding {
                OnboardingView()
                    .transition(.opacity)
            } else {
                mainLayout
                    .transition(.opacity)
            }
        }
        .animation(FLAnimation.standard, value: controller.isOnboarding)
        .frame(minWidth: 860, minHeight: 600)
        .background(Color.flCanvas)
    }

    private var mainLayout: some View {
        HStack(spacing: 0) {
            sidebar

            Rectangle()
                .fill(Color.flHairline.opacity(0.8))
                .frame(width: 1)

            Group {
                switch controller.page {
                case .focus:
                    FocusPageView()
                case .blockedApps:
                    BlockedAppsView()
                case .schedules:
                    SchedulesView()
                case .history:
                    SessionHistoryView()
                case .analytics:
                    AnalyticsView()
                case .integrations:
                    IntegrationsView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.flCanvas)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(AppIdentity.name)
                    .font(FLTypography.title)
                    .foregroundStyle(Color.flInk)

                FLMicroLabel(text: sidebarSubtitle, tint: controller.isSessionActive ? .flAccentDeep : .flInkSoft)
            }
            .padding(.horizontal, 20)
            .padding(.top, 44)
            .padding(.bottom, 28)

            ForEach(MainPage.allCases) { page in
                navItem(page)
            }

            Spacer(minLength: FLSpacing.lg)

            streakBlock
        }
        .frame(width: 208)
        .background(FLSidebarBackground())
    }

    private var sidebarSubtitle: String {
        switch controller.snapshot.phase {
        case .focus:
            return controller.snapshot.isStrict ? "Strict" : "Guarding"
        case .break:
            return "On a break"
        case .breakEnded:
            return "Break done"
        default:
            return "Focus"
        }
    }

    private func navItem(_ page: MainPage) -> some View {
        let isSelected = controller.page == page
        let badge = page == .blockedApps
            ? controller.config.blockedApps.count + controller.config.blockedSites.count
            : page == .schedules ? controller.config.schedules.filter(\.isEnabled).count : 0
        let needsAnswer = page == .blockedApps && controller.browserPermissionProblem != nil

        return Button {
            controller.page = page
        } label: {
            HStack(spacing: 10) {
                Image(systemName: page.systemImage)
                    .font(.system(size: 12.5))
                    .frame(width: 16)

                Text(page.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))

                Spacer(minLength: 0)

                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 10, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(needsAnswer ? Color.flCanvas
                                         : isSelected ? Color.flCanvas.opacity(0.9) : Color.flInkSoft)
                        .padding(.horizontal, needsAnswer ? 6 : 0)
                        .padding(.vertical, needsAnswer ? 2 : 0)
                        .background(needsAnswer ? Color.flAccentDeep : .clear,
                                    in: Capsule())
                }
            }
            .foregroundStyle(isSelected ? Color.flCanvas : Color.flInk.opacity(0.75))
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: FLRadius.md, style: .continuous)
                    .fill(isSelected ? Color.flAccentDeep : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.bottom, 2)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var streakBlock: some View {
        VStack(alignment: .leading, spacing: 9) {
            FLMicroLabel(text: streakTitle)

            HStack(spacing: 4) {
                ForEach(Array(controller.weeklyRhythm.enumerated()), id: \.offset) { _, day in
                    Rectangle()
                        .fill(day.minutes > 0 ? Color.flAccentDeep : Color.flHairline.opacity(0.7))
                        .frame(height: 20)
                }
            }

            Text(streakDetail)
                .font(.system(size: 10.5))
                .foregroundStyle(Color.flInkSoft.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 22)
    }

    private var streakTitle: String {
        let streak = controller.streak
        guard streak > 0 else {
            return "No streak yet"
        }
        return "\(streak) day streak"
    }

    private var streakDetail: String {
        let minutesToday = controller.sessionStats.focusMinutesToday

        if minutesToday > 0 {
            return "\(minutesToday) min focused today"
        }

        return controller.streak > 0
            ? "One session today keeps it alive"
            : "Finish a session to start one"
    }
}

// MARK: - Focus page

struct FocusPageView: View {
    @EnvironmentObject private var controller: MenuBarController

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero

                if showsBreakPanel {
                    FLRule()
                    BreakPanel()
                }

                if let recap = controller.lastRecap, !controller.isSessionActive,
                   controller.snapshot.phase != .breakEnded {
                    FLRule()
                    RecapCard(recap: recap)
                }

                FLRule()

                presetTabs

                if controller.preset == .custom {
                    FLRule()
                    customDurations
                }

                FLRule()

                guardedSummary

                FLRule()

                weeklyRhythm

                FLRule()

                TodayBlocks()
            }
        }
        .sheet(isPresented: $showingEscape) {
            StrictEscapeSheet()
                .environmentObject(controller)
        }
    }

    @State private var showingEscape = false

    private var showsBreakPanel: Bool {
        switch controller.snapshot.phase {
        case .break, .breakEnded:
            return true
        case .completed:
            return controller.checkInEntry != nil
        default:
            return false
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 0) {
            FocusDial(
                phaseLabel: phaseLabel,
                countdown: controller.displayCountdown,
                progress: controller.isSessionActive ? controller.phaseProgress : 0,
                isBreak: controller.snapshot.phase == .break,
                isActive: controller.isSessionActive
            )

            FLSessionBeads(
                total: beadTotal,
                completed: controller.sessionStats.sessionsCompletedToday,
                isRunning: controller.isSessionActive
            )
            .padding(.top, 16)

            controls
                .padding(.top, 24)

            FocusGoalBar()
                .padding(.top, 16)

            Text(scheduleLine)
                .font(FLTypography.caption)
                .foregroundStyle(Color.flInkSoft)
                .padding(.top, 12)

            if let message = controller.focusMessage {
                Text(message)
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flClay)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
                    .padding(.top, 8)
            }
        }
        .padding(.top, 34)
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity)
    }

    private var beadTotal: Int {
        let completed = controller.sessionStats.sessionsCompletedToday
        return max(4, completed + (controller.isSessionActive ? 1 : 0))
    }

    private var phaseLabel: String {
        switch controller.snapshot.phase {
        case .focus:
            let strict = controller.snapshot.isStrict ? " · Strict" : ""
            return "Focus · \(controller.snapshot.focusMinutes) / \(controller.snapshot.breakMinutes)\(strict)"
        case .break:
            return "Break · block \(controller.snapshot.currentCycle) done"
        case .breakEnded:
            return "Break ended"
        default:
            let strict = controller.config.strict.enabled ? " · Strict" : ""
            return "Ready · \(controller.config.focusMinutes) / \(controller.config.breakMinutes)\(strict)"
        }
    }

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: 10) {
            switch controller.snapshot.phase {
            case .focus where controller.isStrictLocked:
                Label("Strict until \(endLabel)", systemImage: "lock.fill")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Color.flAccentDeep)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 44)
                    .overlay(Capsule().strokeBorder(Color.flAccentDeep.opacity(0.35), lineWidth: 1.2))

                Button("Emergency exit…") {
                    showingEscape = true
                }
                .buttonStyle(FLActionButtonStyle(variant: .quiet, minHeight: 44))

            case .focus:
                Button("End session") {
                    controller.requestStopSession()
                }
                .buttonStyle(FLActionButtonStyle(variant: .primary, minHeight: 44))

                Button("Skip to break") {
                    controller.requestSkipPhase()
                }
                .buttonStyle(FLActionButtonStyle(variant: .secondary, minHeight: 44))

            case .break:
                Button("Start next block") {
                    controller.requestSkipPhase()
                }
                .buttonStyle(FLActionButtonStyle(variant: .primary, minHeight: 44))

                Button("End session") {
                    controller.requestStopSession()
                }
                .buttonStyle(FLActionButtonStyle(variant: .secondary, minHeight: 44))

            case .breakEnded:
                Button("Start focus") {
                    controller.startFocus()
                }
                .buttonStyle(FLActionButtonStyle(variant: .primary, minHeight: 44))
                .keyboardShortcut(.defaultAction)

                Button("End cycle") {
                    controller.requestStopSession()
                }
                .buttonStyle(FLActionButtonStyle(variant: .secondary, minHeight: 44))

            default:
                Button("Start focus") {
                    controller.startFocus()
                }
                .buttonStyle(FLActionButtonStyle(variant: .primary, minHeight: 44))
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var endLabel: String {
        controller.snapshot.phaseEndsAt.map(Self.time) ?? "the end"
    }

    private var scheduleLine: String {
        switch controller.snapshot.phase {
        case .focus:
            guard let endsAt = controller.snapshot.phaseEndsAt else {
                return "Guarding \(guardedCountLabel)"
            }
            if controller.config.breakMinutes > 0 {
                return "\(controller.config.breakMinutes) min break at \(Self.time(endsAt))"
            }
            return "Ends at \(Self.time(endsAt))"

        case .break:
            guard let endsAt = controller.snapshot.phaseEndsAt else {
                return "Guard paused during the break"
            }
            return "Focus resumes at \(Self.time(endsAt))"

        case .breakEnded:
            return controller.autoResumeStatusLine ?? "Ready for the next block"

        default:
            if let occurrence = controller.activeScheduleOccurrence {
                return "\(occurrence.schedule.name) runs until \(Self.time(occurrence.end)) — stopped for today"
            }
            let ends = Date().addingTimeInterval(TimeInterval(controller.config.focusMinutes * 60))
            if controller.config.breakMinutes > 0 {
                return "Ends at \(Self.time(ends)) · break follows automatically"
            }
            return "Ends at \(Self.time(ends))"
        }
    }

    private var guardedCountText: String {
        let apps = controller.activeBlockedApps.count
        let sites = controller.activeBlockedSites.count
        var parts: [String] = []
        if apps > 0 { parts.append("\(apps) app\(apps == 1 ? "" : "s")") }
        if sites > 0 { parts.append("\(sites) site\(sites == 1 ? "" : "s")") }
        return parts.isEmpty ? "Nothing active" : parts.joined(separator: " · ") + " guarded"
    }

    private var guardedCountLabel: String {
        let count = controller.activeBlockedApps.count
        return "\(count) app\(count == 1 ? "" : "s")"
    }

    private static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    // MARK: Presets

    private var presetTabs: some View {
        HStack(spacing: 0) {
            ForEach(FocusPreset.allCases) { preset in
                presetTab(preset)
            }
        }
        .frame(height: 46)
    }

    private func presetTab(_ preset: FocusPreset) -> some View {
        let isSelected = controller.preset == preset

        return Button {
            controller.selectPreset(preset)
        } label: {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Text(preset.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.flInk : Color.flInkSoft)
                Spacer(minLength: 0)
                Rectangle()
                    .fill(isSelected ? Color.flAccentDeep : .clear)
                    .frame(height: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("\(preset.title) preset")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var customDurations: some View {
        HStack(spacing: FLSpacing.xl) {
            FLDurationField(
                label: "Focus",
                minutes: Binding(
                    get: { controller.config.focusMinutes },
                    set: { controller.updateFocusMinutes($0) }
                ),
                range: AppConfig.focusMinutesRange
            )

            FLDurationField(
                label: "Break",
                minutes: Binding(
                    get: { controller.config.breakMinutes },
                    set: { controller.updateBreakMinutes($0) }
                ),
                range: 0...60
            )

            Spacer()
        }
        .padding(.horizontal, 26)
        .frame(height: 56)
    }

    // MARK: Guarded summary

    private var guardedSummary: some View {
        HStack(spacing: 12) {
            if controller.config.blockedApps.isEmpty && controller.config.blockedSites.isEmpty {
                Text("Nothing guarded yet")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.flInkSoft)
            } else {
                FLAppPile(apps: controller.activeBlockedApps.map {
                    FLAppPile.BlockedAppSummary(id: $0.bundleId, bundleId: $0.bundleId)
                })

                Text(guardedCountText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.flInk)

                FLBadge(text: controller.config.blockerMode.displayName)
            }

            Spacer(minLength: FLSpacing.sm)

            Button {
                controller.page = .blockedApps
            } label: {
                HStack(spacing: 5) {
                    Text(controller.config.blockedApps.isEmpty && controller.config.blockedSites.isEmpty ? "Add apps or sites" : "Manage")
                        .font(.system(size: 12, weight: .medium))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(Color.flAccentDeep)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 26)
        .frame(height: 62)
    }

    // MARK: Weekly rhythm

    private var weeklyRhythm: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                FLMicroLabel(text: "This week")
                Spacer()
                Text(weekSummary)
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flInkSoft)
            }

            FLWeeklyRhythm(days: controller.weeklyRhythm.map {
                FLWeeklyRhythm.DailyFocusColumn(
                    id: $0.date,
                    label: $0.label,
                    minutes: $0.minutes,
                    isToday: $0.isToday
                )
            }, height: 88)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 20)
    }

    private var weekSummary: String {
        let stats = controller.sessionStats
        let sessions = stats.sessionsCompletedToday
        return "Today \(formatted(minutes: stats.focusMinutesToday)) · \(sessions) session\(sessions == 1 ? "" : "s")"
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
