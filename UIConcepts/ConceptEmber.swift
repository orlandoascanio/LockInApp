import SwiftUI

// =====================================================================
// CONCEPT A — "EMBER"
// Warm, ritual-driven single panel. Radial timer is the hero; every
// other control orbits it. Rounded geometry, cream canvas, coral accent.
// Architecture: one tall 380pt panel (menu-bar popover evolution).
// =====================================================================

enum EmberPalette {
    static let accent = Color(red: 0.94, green: 0.44, blue: 0.29)      // #F0714A
    static let accentDeep = Color(red: 0.79, green: 0.31, blue: 0.18)  // #C94F2E
    static let accentSoft = Color(red: 1.00, green: 0.86, blue: 0.79)  // #FFDBC9
    static let amber = Color(red: 0.96, green: 0.71, blue: 0.29)       // #F5B54A
    static let canvas = Color(red: 0.99, green: 0.95, blue: 0.92)      // #FDF3EA
    static let surface = Color.white
    static let ink = Color(red: 0.27, green: 0.19, blue: 0.16)         // #452F29
    static let inkSoft = Color(red: 0.53, green: 0.42, blue: 0.37)     // #886B5E
    static let hairline = Color(red: 0.89, green: 0.82, blue: 0.77)
}

struct EmberShowcase: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 40) {
            SectionTitle(
                index: "01",
                title: "Ember — the focus ritual",
                body_: "One warm panel, one hero. The countdown lives inside a progress ring so remaining time is readable as a shape before it is read as a number. Everything else is deliberately smaller than the ring: presets are chips, the guarded apps collapse into a face pile, and the primary action is the only filled button on screen.",
                accent: EmberPalette.accentDeep
            )

            HStack(alignment: .top, spacing: 36) {
                ScreenCard("Panel — running", note: "380 × 600 · focus session in progress") {
                    EmberPanel(isRunning: true)
                }
                ScreenCard("Panel — idle", note: "Same layout, pre-session state") {
                    EmberPanel(isRunning: false)
                }
            }

            ScreenCard("Guard screen", note: "Shown full-screen when a guarded app is opened") {
                EmberGuard()
            }

            ScreenCard("Apps & history sheet", note: "Slides up inside the panel — no second window") {
                EmberSheet()
            }
        }
    }
}

// MARK: - Panel

struct EmberPanel: View {
    var isRunning: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            ringBlock
            presets
            appPile
            primary
            nextUpCaption
            footer
        }
        .frame(width: 380, height: 600)
        .background(panelBackground)
    }

    private var panelBackground: some View {
        ZStack {
            EmberPalette.canvas
            RadialGradient(
                colors: [EmberPalette.accentSoft.opacity(isRunning ? 0.85 : 0.4), .clear],
                center: .init(x: 0.5, y: 0.32),
                startRadius: 20,
                endRadius: 300
            )
        }
    }

    private var header: some View {
        HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [EmberPalette.amber, EmberPalette.accentDeep],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: "flame.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text("LockIn")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(EmberPalette.ink)
                Text(isRunning ? "Session 3 of 4" : "Ready when you are")
                    .font(.system(size: 11.5, design: .rounded))
                    .foregroundStyle(EmberPalette.inkSoft)
            }

            Spacer()

            HStack(spacing: 5) {
                Circle()
                    .fill(isRunning ? EmberPalette.accent : EmberPalette.inkSoft.opacity(0.45))
                    .frame(width: 6, height: 6)
                Text(isRunning ? "Guarding" : "Idle")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(isRunning ? EmberPalette.accentDeep : EmberPalette.inkSoft)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(isRunning ? EmberPalette.accentSoft.opacity(0.7) : Color.white.opacity(0.7)))
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 18)
    }

    private var ringBlock: some View {
        ZStack {
            Circle()
                .stroke(EmberPalette.accent.opacity(0.13), lineWidth: 14)

            if isRunning {
                Circle()
                    .trim(from: 0, to: Mock.progress)
                    .stroke(
                        AngularGradient(
                            colors: [EmberPalette.amber, EmberPalette.accent, EmberPalette.accentDeep],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }

            VStack(spacing: 3) {
                Text(isRunning ? Mock.remaining : "25:00")
                    .font(.system(size: 48, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(EmberPalette.ink)
                Text(isRunning ? "focus remaining" : "ready to begin")
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundStyle(EmberPalette.inkSoft)
                    .textCase(.lowercase)
            }
        }
        .frame(width: 202, height: 202)
        .overlay(alignment: .bottom) {
            // four session blocks, read as a row of beads under the ring
            HStack(spacing: 6) {
                ForEach(0..<4) { i in
                    Capsule()
                        .fill(isRunning
                              ? (i < 2 ? EmberPalette.accentDeep
                                 : (i == 2 ? EmberPalette.accent : EmberPalette.accent.opacity(0.22)))
                              : EmberPalette.accent.opacity(0.22))
                        .frame(width: (isRunning && i == 2) ? 22 : 8, height: 5)
                }
            }
            .offset(y: 22)
        }
        .padding(.bottom, 40)
    }

    private var presets: some View {
        HStack(spacing: 7) {
            emberChip("25 / 5", selected: true)
            emberChip("45 / 10", selected: false)
            emberChip("Custom", selected: false)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 16)
    }

    private func emberChip(_ label: String, selected: Bool) -> some View {
        Text(label)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(selected ? .white : EmberPalette.inkSoft)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(
                Capsule().fill(selected ? EmberPalette.accentDeep : Color.white.opacity(0.75))
            )
            .overlay(
                Capsule().strokeBorder(selected ? .clear : EmberPalette.hairline, lineWidth: 1)
            )
    }

    private var appPile: some View {
        HStack(spacing: 12) {
            HStack(spacing: -9) {
                ForEach(Array(Mock.apps.prefix(4).enumerated()), id: \.offset) { _, app in
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(app.2)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: app.1)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(EmberPalette.canvas, lineWidth: 2)
                        )
                }
                Circle()
                    .fill(Color.white)
                    .frame(width: 28, height: 28)
                    .overlay(Text("+1").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(EmberPalette.inkSoft))
                    .overlay(Circle().strokeBorder(EmberPalette.canvas, lineWidth: 2))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("5 apps guarded")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(EmberPalette.ink)
                Text("Guard screen")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(EmberPalette.inkSoft)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(EmberPalette.inkSoft.opacity(0.6))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(EmberPalette.hairline.opacity(0.8), lineWidth: 1)
        )
        .padding(.horizontal, 22)
        .padding(.bottom, 16)
    }

    private var primary: some View {
        HStack(spacing: 10) {
            if isRunning {
                Text("Pause")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(EmberPalette.accentDeep)
                    .frame(width: 96, height: 50)
                    .background(Capsule().fill(Color.white.opacity(0.9)))
                    .overlay(Capsule().strokeBorder(EmberPalette.accentSoft, lineWidth: 1.5))
            }

            HStack(spacing: 8) {
                Image(systemName: isRunning ? "stop.fill" : "play.fill")
                    .font(.system(size: 13, weight: .bold))
                Text(isRunning ? "End session" : "Start focus")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                Capsule().fill(
                    LinearGradient(colors: [EmberPalette.accent, EmberPalette.accentDeep],
                                   startPoint: .leading, endPoint: .trailing)
                )
            )
            .shadow(color: EmberPalette.accentDeep.opacity(0.34), radius: 14, x: 0, y: 7)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 10)
    }

    private var nextUpCaption: some View {
        Text(isRunning ? "5 min break at 3:07 PM · 1 session left after this"
                       : "Ends at 3:02 PM · break follows automatically")
            .font(.system(size: 11.5, design: .rounded))
            .foregroundStyle(EmberPalette.inkSoft.opacity(0.9))
    }

    private var footer: some View {
        HStack(spacing: 0) {
            emberFooterItem("clock.arrow.circlepath", "History")
            Rectangle().fill(EmberPalette.hairline).frame(width: 1, height: 18)
            emberFooterItem("square.grid.2x2", "Apps")
            Rectangle().fill(EmberPalette.hairline).frame(width: 1, height: 18)
            emberFooterItem("gearshape", "Settings")
        }
        .padding(.top, 18)
        .padding(.bottom, 20)
        .padding(.horizontal, 22)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    private func emberFooterItem(_ icon: String, _ label: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
            Text(label)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
        }
        .foregroundStyle(EmberPalette.inkSoft)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Guard

struct EmberGuard: View {
    var body: some View {
        ZStack {
            EmberPalette.canvas
            RadialGradient(colors: [EmberPalette.accentSoft.opacity(0.9), .clear],
                           center: .center, startRadius: 40, endRadius: 460)

            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill").font(.system(size: 10, weight: .bold))
                    Text("Focus mode · 18:42 left")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundStyle(EmberPalette.accentDeep)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.white.opacity(0.8)))
                .padding(.top, 32)

                Spacer()

                ZStack {
                    Circle()
                        .stroke(EmberPalette.accent.opacity(0.15), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: Mock.progress)
                        .stroke(EmberPalette.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Mock.apps[0].2)
                        .frame(width: 64, height: 64)
                        .overlay(
                            Image(systemName: Mock.apps[0].1)
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(.white)
                        )
                }
                .frame(width: 132, height: 132)
                .padding(.bottom, 26)

                Text("Slack can wait.")
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .foregroundStyle(EmberPalette.ink)

                Text("It stays running in the background — calls, mic and screen share\nkeep working. You just don't need to live inside it right now.")
                    .font(.system(size: 14))
                    .foregroundStyle(EmberPalette.inkSoft)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.top, 12)

                Spacer()

                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.uturn.backward").font(.system(size: 12, weight: .bold))
                        Text("Back to focus").font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 26)
                    .frame(height: 46)
                    .background(Capsule().fill(EmberPalette.accentDeep))
                    .shadow(color: EmberPalette.accentDeep.opacity(0.3), radius: 12, y: 6)

                    Text("Allow 5 minutes")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(EmberPalette.inkSoft)
                        .padding(.horizontal, 22)
                        .frame(height: 46)
                        .background(Capsule().fill(Color.white.opacity(0.75)))
                        .overlay(Capsule().strokeBorder(EmberPalette.hairline, lineWidth: 1))

                    Text("End session")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(EmberPalette.inkSoft.opacity(0.85))
                        .padding(.horizontal, 22)
                        .frame(height: 46)
                }
                .padding(.bottom, 36)
            }
        }
        .frame(width: 796, height: 470)
    }
}

// MARK: - Sheet

struct EmberSheet: View {
    var body: some View {
        HStack(spacing: 0) {
            emberList(
                title: "Guarded apps",
                subtitle: "Hidden behind the guard screen during focus",
                rows: Mock.apps.map { ($0.0, $0.1, $0.2, "On") }
            )
            Rectangle().fill(EmberPalette.hairline).frame(width: 1)
            emberHistory
        }
        .frame(width: 796, height: 380)
        .background(EmberPalette.canvas)
    }

    private func emberList(title: String, subtitle: String, rows: [(String, String, Color, String)]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundStyle(EmberPalette.ink)
                Text(subtitle).font(.system(size: 12)).foregroundStyle(EmberPalette.inkSoft)
            }
            .padding(20)

            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 11) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(row.2)
                        .frame(width: 30, height: 30)
                        .overlay(Image(systemName: row.1).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white))

                    Text(row.0)
                        .font(.system(size: 13.5, weight: .medium, design: .rounded))
                        .foregroundStyle(EmberPalette.ink)

                    Spacer()

                    Capsule()
                        .fill(EmberPalette.accentDeep)
                        .frame(width: 38, height: 22)
                        .overlay(
                            Circle().fill(.white).frame(width: 17, height: 17).offset(x: 7.5)
                        )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 9)
            }

            Spacer()

            HStack(spacing: 7) {
                Image(systemName: "plus").font(.system(size: 11, weight: .bold))
                Text("Add app").font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(EmberPalette.accentDeep)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(Capsule().fill(Color.white.opacity(0.8)))
            .overlay(Capsule().strokeBorder(EmberPalette.accentSoft, lineWidth: 1.5))
            .padding(20)
        }
        .frame(width: 398)
    }

    private var emberHistory: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text("This week").font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundStyle(EmberPalette.ink)
                Text("11h 20m focused · 4 day streak").font(.system(size: 12)).foregroundStyle(EmberPalette.inkSoft)
            }
            .padding(20)

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(Mock.weekBars.enumerated()), id: \.offset) { i, value in
                    VStack(spacing: 7) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(i == 4
                                  ? AnyShapeStyle(LinearGradient(colors: [EmberPalette.amber, EmberPalette.accentDeep], startPoint: .top, endPoint: .bottom))
                                  : AnyShapeStyle(EmberPalette.accentSoft))
                            .frame(height: 84 * value)
                        Text(Mock.weekLabels[i])
                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                            .foregroundStyle(EmberPalette.inkSoft)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 108, alignment: .bottom)
            .padding(.horizontal, 20)
            .padding(.bottom, 18)

            Rectangle().fill(EmberPalette.hairline).frame(height: 1).padding(.horizontal, 20)

            ForEach(Array(Mock.history.prefix(4).enumerated()), id: \.offset) { _, entry in
                HStack(spacing: 10) {
                    Circle()
                        .fill(entry.3 ? EmberPalette.accentDeep : EmberPalette.hairline)
                        .frame(width: 7, height: 7)
                    Text(entry.1).font(.system(size: 12.5, weight: .medium, design: .rounded)).foregroundStyle(EmberPalette.ink)
                    Spacer()
                    Text(entry.0).font(.system(size: 11.5)).foregroundStyle(EmberPalette.inkSoft)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
