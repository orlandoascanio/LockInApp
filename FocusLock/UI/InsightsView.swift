import FocusLockCore
import SwiftUI

/// How focus goes for you, from your own blocks: what pulls you away, when it
/// holds, which blocks you finish, what came of your goals, and — if you
/// asked for it — where the time went. Analytics is how much; this is how.
struct InsightsView: View {
    @EnvironmentObject private var controller: MenuBarController
    @State private var range: InsightsRange = .ninetyDays
    @State private var confirmingClear = false

    private var insights: FocusInsights {
        FocusInsights.make(
            history: controller.history,
            reaches: controller.reaches,
            focusTime: controller.focusTimeRecords,
            range: range.dates()
        )
    }

    var body: some View {
        let insights = insights
        VStack(alignment: .leading, spacing: 0) {
            StatsHeader {
                FLSegmentedControl(
                    options: InsightsRange.allCases,
                    selection: $range,
                    title: \.title,
                    accessibilityLabel: "Insights time range"
                )
            }

            if controller.history.isEmpty {
                FLEmptyState(
                    systemImage: "sparkle.magnifyingglass",
                    title: "Nothing to notice yet",
                    detail: "Finish a few focus blocks and Quietwhile will start to see how focus goes for you."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if insights.isEmpty {
                VStack(spacing: FLSpacing.md) {
                    FLEmptyState(
                        systemImage: "calendar",
                        title: "No blocks in this range",
                        detail: "Choose a longer range to bring earlier blocks in."
                    )
                    Button("Show all time") { range = .allTime }
                        .buttonStyle(FLActionButtonStyle(variant: .secondary, minHeight: 34))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        FLRule()
                        headline(insights).flBand()
                        FLRule()
                        pulls(insights).flBand()
                        FLRule()
                        HStack(alignment: .top, spacing: FLLayout.columnGap) {
                            dayparts(insights)
                            FLColumnRule()
                            lengths(insights)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .flBand()
                        FLRule()
                        goals(insights).flBand()
                        FLRule()
                        whereFocusWent(insights).flBand()
                        FLRule()
                        footer.flBand(vertical: 14)
                    }
                }
                .flScrollEdges(top: 0)
            }
        }
    }

    // MARK: Headline

    private func headline(_ insights: FocusInsights) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("In \(insights.blocks) block\(insights.blocks == 1 ? "" : "s")")
                .font(FLTypography.micro)
                .foregroundStyle(Color.flInkSoft)
            if insights.headline.isEmpty {
                Text("A few more blocks and patterns will start to show. Nothing here is guessed from too little.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.flInkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(insights.headline, id: \.self) { line in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.flAccentDeep)
                        Text(line)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.flInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: What pulls you away

    private func pulls(_ insights: FocusInsights) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("What pulls you away", detail: pullsDetail(insights))

            if insights.pulls.isEmpty {
                Text(controller.config.blockedApps.isEmpty && controller.config.blockedSites.isEmpty
                     ? "Guard an app or a website on the Blocked page, and every time you reach for one during focus shows up here."
                     : "Nothing guarded was reached for. That's the whole point.")
                    .font(FLTypography.body)
                    .foregroundStyle(Color.flInkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                let peak = max(insights.pulls.first?.reaches ?? 1, 1)
                VStack(spacing: 10) {
                    ForEach(insights.pulls.prefix(6)) { pull in
                        pullRow(pull, peak: peak)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pullsDetail(_ insights: FocusInsights) -> String {
        let clean = "\(insights.cleanBlocks) of \(insights.completedBlocks) finished blocks clean"
        guard insights.cleanStreak > 1 else { return clean }
        return clean + " · the last \(insights.cleanStreak) in a row"
    }

    private func pullRow(_ pull: FocusInsights.Pull, peak: Int) -> some View {
        HStack(spacing: 12) {
            Group {
                if pull.kind == .app {
                    FLAppIcon(bundleId: pull.key, size: 22)
                } else {
                    Image(systemName: "globe")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.flInkSoft)
                        .frame(width: 22, height: 22)
                }
            }

            Text(pull.name)
                .font(FLTypography.body)
                .foregroundStyle(Color.flInk)
                .lineLimit(1)
                .frame(width: 150, alignment: .leading)

            bar(Double(pull.reaches) / Double(peak), tint: .flClay)

            Text(pullSummary(pull))
                .font(FLTypography.caption)
                .monospacedDigit()
                .foregroundStyle(Color.flInkSoft)
                .frame(width: 210, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private func pullSummary(_ pull: FocusInsights.Pull) -> String {
        var parts = ["\(pull.reaches) reach\(pull.reaches == 1 ? "" : "es")"]
        if pull.blocks > 0 { parts.append("\(pull.blocks) block\(pull.blocks == 1 ? "" : "s")") }
        if let minute = pull.typicalMinute { parts.append("~\(minute) min in") }
        return parts.joined(separator: " · ")
    }

    // MARK: When focus holds

    private func dayparts(_ insights: FocusInsights) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("When focus holds", detail: "Blocks finished, by when they started")
            VStack(spacing: 10) {
                ForEach(insights.dayparts.filter { $0.blocks > 0 }) { part in
                    rateRow(
                        title: part.daypart.title,
                        subtitle: part.daypart.hours,
                        rate: part.completionRate,
                        trailing: "\(part.blocks) · \(String(format: "%.1f", part.reachesPerBlock)) reaches",
                        isBest: insights.bestDaypart?.daypart == part.daypart
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Block length

    private func lengths(_ insights: FocusInsights) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Blocks you finish", detail: "By the length you set")
            VStack(spacing: 10) {
                ForEach(insights.lengths.filter { $0.blocks > 0 }) { band in
                    rateRow(
                        title: band.band.title,
                        subtitle: nil,
                        rate: band.completionRate,
                        trailing: "\(band.completed) of \(band.blocks)",
                        isBest: insights.sweetSpot?.band == band.band
                    )
                }
            }
            if let strict = insights.strict {
                Text("Strict: \(FocusInsights.percent(strict.strictCompletionRate)) finished over \(strict.strictBlocks) blocks. Without: \(FocusInsights.percent(strict.relaxedCompletionRate)).")
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flInkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func rateRow(title: String, subtitle: String?, rate: Double, trailing: String, isBest: Bool) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: isBest ? .semibold : .regular))
                    .foregroundStyle(Color.flInk)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.flInkSoft)
                }
            }
            .frame(width: 92, alignment: .leading)

            bar(rate, tint: isBest ? .flAccentDeep : .flAccent.opacity(0.6))

            Text(FocusInsights.percent(rate))
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Color.flInk)
                .frame(width: 36, alignment: .trailing)

            Text(trailing)
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundStyle(Color.flInkSoft)
                .frame(width: 92, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Goals

    private func goals(_ insights: FocusInsights) -> some View {
        let goals = insights.goals
        return VStack(alignment: .leading, spacing: 14) {
            sectionTitle(
                "What came of your goals",
                detail: "\(goals.checkedIn) check-in\(goals.checkedIn == 1 ? "" : "s") across \(goals.blocksWithGoal) block\(goals.blocksWithGoal == 1 ? "" : "s") with a goal"
            )

            if goals.checkedIn == 0 {
                Text("Set a goal before a block and answer the check-in after it, and this fills in: what got done, and where you get stuck.")
                    .font(FLTypography.body)
                    .foregroundStyle(Color.flInkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                GeometryReader { geometry in
                    HStack(spacing: 2) {
                        segment(goals.done, of: goals.checkedIn, width: geometry.size.width, tint: .flAccentDeep)
                        segment(goals.progress, of: goals.checkedIn, width: geometry.size.width, tint: .flWarning)
                        segment(goals.stuck, of: goals.checkedIn, width: geometry.size.width, tint: .flClay)
                    }
                }
                .frame(height: 10)
                .clipShape(Capsule())

                HStack(spacing: 22) {
                    legend("Done", goals.done, tint: .flAccentDeep)
                    legend("Made progress", goals.progress, tint: .flWarning)
                    legend("Got stuck", goals.stuck, tint: .flClay)
                    Spacer()
                }

                let notes = [
                    goals.doneMostIn.map { "\($0) goals get done most often." },
                    goals.stuckMostIn.map { "\($0) is where you get stuck most." }
                ].compactMap { $0 }
                if !notes.isEmpty {
                    Text(notes.joined(separator: " "))
                        .font(FLTypography.caption)
                        .foregroundStyle(Color.flInkSoft)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func segment(_ count: Int, of total: Int, width: CGFloat, tint: Color) -> some View {
        Rectangle()
            .fill(tint)
            .frame(width: total == 0 ? 0 : max(count > 0 ? 3 : 0, width * CGFloat(count) / CGFloat(total)))
    }

    private func legend(_ title: String, _ count: Int, tint: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(tint).frame(width: 7, height: 7)
            Text("\(title) · \(count)")
                .font(FLTypography.caption)
                .monospacedDigit()
                .foregroundStyle(Color.flInk)
        }
    }

    // MARK: Where focus went

    private func whereFocusWent(_ insights: FocusInsights) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Where focus went", detail: whereDetail(insights))

            if !controller.config.trackFocusTime {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quietwhile can notice which app is in front during your focus blocks — and which website, in browsers you've already let it read for guarding. Only the totals are kept, on this Mac. Never page addresses, titles, or anything outside focus.")
                        .font(FLTypography.body)
                        .foregroundStyle(Color.flInkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 620, alignment: .leading)
                    Button("Start noticing") {
                        controller.updateTrackFocusTime(enabled: true)
                    }
                    .buttonStyle(FLActionButtonStyle(variant: .secondary, minHeight: 32))
                }
            } else if let went = insights.whereFocusWent {
                HStack(alignment: .top, spacing: 28) {
                    shareList(title: "Apps", shares: Array(went.apps.prefix(6)), isApp: true)
                    if !went.sites.isEmpty {
                        shareList(title: "Websites", shares: Array(went.sites.prefix(6)), isApp: false)
                    }
                }
                if !went.topAppByCategory.isEmpty {
                    Text(went.topAppByCategory.sorted { $0.key < $1.key }
                        .map { "\($0.key) happens mostly in \($0.value)." }
                        .joined(separator: " "))
                        .font(FLTypography.caption)
                        .foregroundStyle(Color.flInkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("On. Finish a block and where its time went shows up here.")
                    .font(FLTypography.body)
                    .foregroundStyle(Color.flInkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func whereDetail(_ insights: FocusInsights) -> String {
        guard controller.config.trackFocusTime else { return "Off" }
        guard let went = insights.whereFocusWent else { return "On, nothing counted yet" }
        let minutes = Int(went.trackedSeconds / 60)
        return "\(minutes / 60)h \(minutes % 60)m noticed over \(went.trackedBlocks) block\(went.trackedBlocks == 1 ? "" : "s")"
    }

    private func shareList(title: String, shares: [FocusInsights.TimeShare], isApp: Bool) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(FLTypography.headline)
                .foregroundStyle(Color.flInk)
            ForEach(shares) { share in
                HStack(spacing: 10) {
                    if isApp {
                        FLAppIcon(bundleId: share.key, size: 18)
                    } else {
                        Image(systemName: "globe").font(.system(size: 11)).foregroundStyle(Color.flInkSoft).frame(width: 18)
                    }
                    Text(share.name)
                        .font(FLTypography.body)
                        .foregroundStyle(Color.flInk)
                        .lineLimit(1)
                        .frame(width: 120, alignment: .leading)
                    bar(share.share, tint: isApp ? .flAccent : .flRest)
                    Text(FocusInsights.percent(share.share))
                        .font(.system(size: 11.5, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(Color.flInkSoft)
                        .frame(width: 36, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 14) {
            Label("Everything here is worked out on this Mac from your own blocks. Nothing is sent anywhere.", systemImage: "lock")
                .font(FLTypography.caption)
                .foregroundStyle(Color.flInkSoft)
            Spacer()
            if controller.config.trackFocusTime {
                Button("Stop noticing") { controller.updateTrackFocusTime(enabled: false) }
                    .buttonStyle(FLLinkButtonStyle(tint: .flInkSoft))
            }
            Button("Clear reaches and focus time…") { confirmingClear = true }
                .buttonStyle(FLLinkButtonStyle(tint: .flClayInk))
                .confirmationDialog("Clear reaches and focus time?", isPresented: $confirmingClear) {
                    Button("Clear", role: .destructive) { controller.clearInsightsData() }
                } message: {
                    Text("Your session history stays. What was reached for, and where focus time went, start over.")
                }
        }
        .padding(.horizontal, 4)
    }

    // MARK: Pieces

    private func sectionTitle(_ title: String, detail: String) -> some View {
        FLSectionHeader(title: title, subtitle: detail)
    }

    private func bar(_ fraction: Double, tint: Color) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.flSunken)
                Capsule()
                    .fill(tint)
                    .frame(width: fraction <= 0 ? 0 : max(3, geometry.size.width * min(1, fraction)))
            }
        }
        .frame(height: 7)
    }
}

enum InsightsRange: String, CaseIterable, Identifiable {
    case thirtyDays
    case ninetyDays
    case year
    case allTime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .thirtyDays: return "30 days"
        case .ninetyDays: return "90 days"
        case .year: return "Year"
        case .allTime: return "All time"
        }
    }

    func dates(now: Date = Date(), calendar: Calendar = .current) -> Range<Date> {
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let days: Int
        switch self {
        case .thirtyDays: days = 30
        case .ninetyDays: days = 90
        case .year: days = 365
        case .allTime: return Date.distantPast..<end
        }
        let start = calendar.date(byAdding: .day, value: -days, to: end) ?? .distantPast
        return start..<end
    }
}
