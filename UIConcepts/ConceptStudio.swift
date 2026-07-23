import SwiftUI

// =====================================================================
// CONCEPT B — "STUDIO"
// A real app window, not a popover. Persistent sidebar, dashboard-first.
// Optimised for people who want to *see* their focus data, not just run
// a timer. Cool indigo/violet on light slate; dense but airy.
// Architecture: 960 × 640 window, sidebar + scrolling content region.
// =====================================================================

enum StudioPalette {
    static let accent = Color(red: 0.33, green: 0.36, blue: 0.86)      // #545CDB
    static let violet = Color(red: 0.55, green: 0.38, blue: 0.92)      // #8C61EB
    static let accentSoft = Color(red: 0.90, green: 0.91, blue: 0.99)  // #E6E8FD
    static let canvas = Color(red: 0.94, green: 0.95, blue: 0.98)      // #F0F2FA
    static let surface = Color.white
    static let sidebar = Color(red: 0.15, green: 0.16, blue: 0.30)     // #26294D (deep indigo, not black)
    static let ink = Color(red: 0.16, green: 0.17, blue: 0.28)         // #292C48
    static let inkSoft = Color(red: 0.44, green: 0.46, blue: 0.58)     // #707594
    static let hairline = Color(red: 0.87, green: 0.88, blue: 0.94)
    static let mint = Color(red: 0.20, green: 0.72, blue: 0.58)        // #33B894
    static let coral = Color(red: 0.95, green: 0.45, blue: 0.45)
}

struct StudioShowcase: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 40) {
            SectionTitle(
                index: "02",
                title: "Studio — the focus command centre",
                body_: "Promotes LockIn from a menu-bar utility to a real window. A persistent sidebar gives every area a permanent address, so Settings and History stop being modal detours. The dashboard answers \"how is my day going\" before you even start a session: live timer, today's blocks, weekly rhythm and the interruptions you resisted.",
                accent: StudioPalette.accent
            )

            ScreenCard("Dashboard", note: "960 × 640 · sidebar navigation + live session") {
                StudioWindow(page: .dashboard)
            }

            ScreenCard("Blocked apps", note: "Same shell, different pane — no modal windows") {
                StudioWindow(page: .apps)
            }

            ScreenCard("Guard screen", note: "Structured, informative — tells you what you'd be trading away") {
                StudioGuard()
            }
        }
    }
}

enum StudioPage { case dashboard, apps }

struct StudioWindow: View {
    let page: StudioPage

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Group {
                switch page {
                case .dashboard: dashboard
                case .apps: appsPane
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(StudioPalette.canvas)
        }
        .frame(width: 960, height: 640)
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(LinearGradient(colors: [StudioPalette.violet, StudioPalette.accent],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 30, height: 30)
                    .overlay(Image(systemName: "lock.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(.white))
                VStack(alignment: .leading, spacing: 0) {
                    Text("LockIn").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                    Text("Focus studio").font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 26)
            .padding(.bottom, 26)

            navItem("square.grid.2x2.fill", "Dashboard", selected: page == .dashboard)
            navItem("shield.lefthalf.filled", "Blocked apps", selected: page == .apps, badge: "5")
            navItem("chart.bar.fill", "Insights", selected: false)
            navItem("clock.arrow.circlepath", "History", selected: false)
            navItem("gearshape.fill", "Settings", selected: false)

            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill").font(.system(size: 11)).foregroundStyle(StudioPalette.violet)
                    Text("4 day streak").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                }
                HStack(spacing: 4) {
                    ForEach(0..<7) { i in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(i < 4 ? StudioPalette.violet : Color.white.opacity(0.14))
                            .frame(height: 22)
                    }
                }
                Text("Keep it alive — 25 min today")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.07)))
            .padding(.horizontal, 14)
            .padding(.bottom, 18)
        }
        .frame(width: 216)
        .background(StudioPalette.sidebar)
    }

    private func navItem(_ icon: String, _ label: String, selected: Bool, badge: String? = nil) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12.5, weight: .medium))
                .frame(width: 17)
            Text(label).font(.system(size: 13, weight: selected ? .semibold : .regular))
            Spacer()
            if let badge {
                Text(badge)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(0.16)))
            }
        }
        .foregroundStyle(selected ? .white : Color.white.opacity(0.62))
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(selected ? StudioPalette.accent : .clear)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 3)
    }

    // MARK: Dashboard

    private var dashboard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Good afternoon, Orlando")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(StudioPalette.ink)
                    Text("Monday 20 July · 2h 40m focused so far")
                        .font(.system(size: 12.5))
                        .foregroundStyle(StudioPalette.inkSoft)
                }
                Spacer()
                HStack(spacing: 2) {
                    segment("Day", selected: true)
                    segment("Week", selected: false)
                    segment("Month", selected: false)
                }
                .padding(2)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(StudioPalette.hairline.opacity(0.7)))
            }

            liveSessionCard

            HStack(spacing: 14) {
                statTile("2h 40m", "Focused today", "clock.fill", StudioPalette.accent, "+35m vs yesterday")
                statTile("4", "Sessions completed", "checkmark.seal.fill", StudioPalette.mint, "1 stopped early")
                statTile("12", "Distractions blocked", "hand.raised.fill", StudioPalette.coral, "Slack led with 6")
            }

            weekCard

            Spacer(minLength: 0)
        }
        .padding(24)
    }

    private func segment(_ label: String, selected: Bool) -> some View {
        Text(label)
            .font(.system(size: 12, weight: selected ? .semibold : .regular))
            .foregroundStyle(selected ? StudioPalette.ink : StudioPalette.inkSoft)
            .padding(.horizontal, 13)
            .frame(height: 26)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(selected ? Color.white : .clear)
                    .shadow(color: .black.opacity(selected ? 0.07 : 0), radius: 3, y: 1)
            )
    }

    private var liveSessionCard: some View {
        HStack(spacing: 26) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    Circle().fill(StudioPalette.mint).frame(width: 7, height: 7)
                    Text("FOCUS SESSION · 25 / 5 PRESET")
                        .font(.system(size: 10.5, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.7))
                }

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(Mock.remaining)
                        .font(.system(size: 54, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text("remaining")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.62))
                }

                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.18)).frame(height: 6)
                    Capsule()
                        .fill(LinearGradient(colors: [.white, StudioPalette.accentSoft], startPoint: .leading, endPoint: .trailing))
                        .frame(width: 300 * Mock.progress, height: 6)
                }
                .frame(width: 300)

                HStack(spacing: 8) {
                    studioButton("pause.fill", "Pause", filled: true)
                    studioButton("forward.end.fill", "Skip to break", filled: false)
                    studioButton("stop.fill", "End", filled: false)
                }
                .padding(.top, 2)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 11) {
                Text("GUARDING NOW")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.55))

                ForEach(Array(Mock.apps.prefix(3).enumerated()), id: \.offset) { _, app in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 24, height: 24)
                            .overlay(Image(systemName: app.1).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(.white))
                        Text(app.0).font(.system(size: 12.5, weight: .medium)).foregroundStyle(.white.opacity(0.92))
                        Spacer()
                        Text("×2").font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.5))
                    }
                }

                Text("+ 2 more guarded")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .frame(width: 196)
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: [StudioPalette.accent, StudioPalette.violet],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .shadow(color: StudioPalette.accent.opacity(0.28), radius: 20, y: 10)
    }

    private func studioButton(_ icon: String, _ label: String, filled: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 10, weight: .bold))
            Text(label).font(.system(size: 12.5, weight: .semibold))
        }
        .foregroundStyle(filled ? StudioPalette.accent : .white)
        .padding(.horizontal, 14)
        .frame(height: 34)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(filled ? Color.white : Color.white.opacity(0.14))
        )
    }

    private func statTile(_ value: String, _ label: String, _ icon: String, _ tint: Color, _ delta: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(tint)
                    .frame(width: 26, height: 26)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(tint.opacity(0.13)))
                Spacer()
            }
            Text(value)
                .font(.system(size: 24, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(StudioPalette.ink)
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(StudioPalette.inkSoft)
            Text(delta).font(.system(size: 11)).foregroundStyle(StudioPalette.inkSoft.opacity(0.75))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(StudioPalette.surface))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(StudioPalette.hairline, lineWidth: 1))
    }

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Weekly rhythm").font(.system(size: 14, weight: .semibold)).foregroundStyle(StudioPalette.ink)
                Spacer()
                Text("Goal 3h / day").font(.system(size: 11.5)).foregroundStyle(StudioPalette.inkSoft)
            }

            HStack(alignment: .bottom, spacing: 14) {
                ForEach(Array(Mock.weekBars.enumerated()), id: \.offset) { i, value in
                    VStack(spacing: 8) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(StudioPalette.hairline.opacity(0.75))
                                .frame(height: 74)
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(i == 4
                                      ? AnyShapeStyle(LinearGradient(colors: [StudioPalette.violet, StudioPalette.accent], startPoint: .top, endPoint: .bottom))
                                      : AnyShapeStyle(StudioPalette.accent.opacity(0.45)))
                                .frame(height: 74 * value)
                        }
                        Text(Mock.weekLabels[i]).font(.system(size: 10.5, weight: .medium)).foregroundStyle(StudioPalette.inkSoft)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(StudioPalette.surface))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(StudioPalette.hairline, lineWidth: 1))
    }

    // MARK: Apps pane

    private var appsPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Blocked apps").font(.system(size: 20, weight: .semibold)).foregroundStyle(StudioPalette.ink)
                    Text("5 guarded · behaviour applies during focus only")
                        .font(.system(size: 12.5)).foregroundStyle(StudioPalette.inkSoft)
                }
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 11, weight: .bold))
                    Text("Add app").font(.system(size: 12.5, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 15)
                .frame(height: 34)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(StudioPalette.accent))
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(StudioPalette.inkSoft)
                Text("Filter applications").font(.system(size: 12.5)).foregroundStyle(StudioPalette.inkSoft.opacity(0.7))
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(StudioPalette.surface))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(StudioPalette.hairline, lineWidth: 1))

            VStack(spacing: 0) {
                HStack {
                    Text("APPLICATION").frame(width: 240, alignment: .leading)
                    Text("BEHAVIOUR").frame(width: 150, alignment: .leading)
                    Text("BLOCKED TODAY").frame(width: 120, alignment: .leading)
                    Spacer()
                    Text("ACTIVE")
                }
                .font(.system(size: 10, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(StudioPalette.inkSoft.opacity(0.8))
                .padding(.horizontal, 16)
                .frame(height: 34)
                .background(StudioPalette.canvas)

                ForEach(Array(Mock.apps.enumerated()), id: \.offset) { i, app in
                    Rectangle().fill(StudioPalette.hairline).frame(height: 1)
                    HStack {
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(app.2)
                                .frame(width: 28, height: 28)
                                .overlay(Image(systemName: app.1).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white))
                            Text(app.0).font(.system(size: 13, weight: .medium)).foregroundStyle(StudioPalette.ink)
                        }
                        .frame(width: 240, alignment: .leading)

                        Text(i == 2 ? "Quit app" : (i == 3 ? "Hide only" : "Guard screen"))
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(StudioPalette.accent)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(StudioPalette.accentSoft))
                            .frame(width: 150, alignment: .leading)

                        Text(["6×", "3×", "2×", "1×", "—"][i])
                            .font(.system(size: 12.5, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(StudioPalette.inkSoft)
                            .frame(width: 120, alignment: .leading)

                        Spacer()

                        Capsule()
                            .fill(i == 4 ? StudioPalette.hairline : StudioPalette.accent)
                            .frame(width: 36, height: 21)
                            .overlay(Circle().fill(.white).frame(width: 16, height: 16).offset(x: i == 4 ? -7 : 7))
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 50)
                    .background(StudioPalette.surface)
                }
            }
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(StudioPalette.surface))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(StudioPalette.hairline, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Spacer(minLength: 0)
        }
        .padding(24)
    }
}

// MARK: - Guard

struct StudioGuard: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [StudioPalette.accent, StudioPalette.violet],
                           startPoint: .topLeading, endPoint: .bottomTrailing)

            VStack(spacing: 22) {
                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.16))
                        .frame(width: 54, height: 54)
                        .overlay(Image(systemName: "message.fill").font(.system(size: 22, weight: .semibold)).foregroundStyle(.white))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Slack is guarded right now")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("You have opened it 6 times today. It keeps running in the background.")
                            .font(.system(size: 13.5))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    Spacer()
                }

                HStack(spacing: 12) {
                    guardMetric(Mock.remaining, "left in this block", wide: true)
                    guardMetric("2h 40m", "focused today")
                    guardMetric("4", "sessions done")
                }

                HStack(spacing: 10) {
                    HStack(spacing: 7) {
                        Image(systemName: "arrow.uturn.backward").font(.system(size: 11, weight: .bold))
                        Text("Back to focus").font(.system(size: 13.5, weight: .semibold))
                    }
                    .foregroundStyle(StudioPalette.accent)
                    .padding(.horizontal, 20)
                    .frame(height: 42)
                    .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(.white))

                    Text("Allow 5 minutes")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .frame(height: 42)
                        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Color.white.opacity(0.16)))

                    Spacer()

                    Text("End session")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                        .padding(.horizontal, 16)
                        .frame(height: 42)
                        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(.white.opacity(0.25), lineWidth: 1))
                }
            }
            .padding(30)
            .frame(width: 620)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white.opacity(0.10)))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.18), lineWidth: 1))
        }
        .frame(width: 960, height: 470)
    }

    private func guardMetric(_ value: String, _ label: String, wide: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: wide ? 30 : 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 11.5))
                .foregroundStyle(.white.opacity(0.65))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Color.white.opacity(0.10)))
    }
}
