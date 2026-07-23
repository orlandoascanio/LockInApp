import SwiftUI

// =====================================================================
// THE REDESIGN — Sage base, Studio structure, Ember controls.
//
// Sage's palette, serif numerals and hairline chrome carry the whole
// app. From Studio: the sidebar, and the blocked-apps table with
// behaviour + hit counts. From Ember: the timer's own button pair,
// pulled back up under the countdown where it belongs, and the app
// pile instead of Sage's chip row. Guard screen is Sage, untouched.
//
// Fixes applied to Sage:
//   · controls sit under the timer, not stranded at the window edge
//   · guarded-app chip row → compact pile that links to the real list
//   · the odd "today" bar log → Studio's weekly rhythm + streak
// =====================================================================

struct LockInShowcase: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 40) {
            SectionTitle(
                index: "★",
                title: "LockIn — the redesign",
                body_: "Sage does the talking: sand canvas, moss accent, serif numerals, hairline rules, one filled button per screen. Studio lends the sidebar so History and Settings stop being modal detours, and lends the blocked-apps table with behaviour and hit counts. Ember lends the timer's control pair, moved back up under the countdown so it reads as part of the clock. The guard screen stays exactly as it was.",
                accent: SagePalette.accentDeep
            )

            ScreenCard("Focus", note: "900 × 620 · sidebar + timer, controls under the clock") {
                LockInWindow(page: .focus, running: true)
            }

            HStack(alignment: .top, spacing: 32) {
                ScreenCard("Focus — idle", note: "One filled button, nothing else") {
                    LockInWindow(page: .focus, running: false)
                        .scaleEffect(0.62, anchor: .topLeading)
                        .frame(width: 558, height: 384)
                }
                ScreenCard("Blocked apps", note: "Studio's table, Sage's skin") {
                    LockInWindow(page: .apps, running: true)
                        .scaleEffect(0.62, anchor: .topLeading)
                        .frame(width: 558, height: 384)
                }
            }

            ScreenCard("Guard screen", note: "Unchanged — this one already won") {
                SageGuard()
            }

            SectionTitle(
                index: "＋",
                title: "The pinned HUD",
                body_: "Your idea, kept as a real feature. The collapsed strip floats above every window so the countdown is never more than a glance away — and the menu-bar tuck is the same strip, folded down from the status item when you click it.",
                accent: SagePalette.accentDeep
            )

            ScreenCard("Pinned HUD", note: "Always on top, click-through everywhere else") {
                PinnedHUDContext()
            }

            HStack(alignment: .top, spacing: 32) {
                ScreenCard("HUD — expanded on hover", note: "Reveals controls without unpinning") {
                    LockInHUD(hovered: true)
                }
                ScreenCard("Menu-bar tuck", note: "Same strip, dropped from the status item") {
                    LockInMenuBarTuck()
                }
            }
        }
    }
}

// MARK: - Window

enum LockInPage { case focus, apps }

struct LockInWindow: View {
    let page: LockInPage
    var running: Bool = true

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(SagePalette.hairline.opacity(0.8)).frame(width: 1)
            Group {
                switch page {
                case .focus: focusPage
                case .apps: appsPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SagePalette.canvas)
        }
        .frame(width: 900, height: 620)
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("LockIn")
                    .font(.system(size: 19, weight: .regular, design: .serif))
                    .foregroundStyle(SagePalette.ink)
                Text("FOCUS")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(2.0)
                    .foregroundStyle(SagePalette.inkSoft)
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)
            .padding(.bottom, 28)

            navItem("timer", "Focus", selected: page == .focus)
            navItem("shield", "Blocked apps", selected: page == .apps, badge: "5")
            navItem("clock.arrow.circlepath", "History", selected: false)
            navItem("gearshape", "Settings", selected: false)

            Spacer()

            VStack(alignment: .leading, spacing: 9) {
                Text("4 DAY STREAK")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(SagePalette.inkSoft)

                HStack(spacing: 4) {
                    ForEach(0..<7) { i in
                        Rectangle()
                            .fill(i < 4 ? SagePalette.accentDeep : SagePalette.hairline.opacity(0.7))
                            .frame(height: 20)
                    }
                }

                Text("25 min today keeps it alive")
                    .font(.system(size: 10.5))
                    .foregroundStyle(SagePalette.inkSoft.opacity(0.85))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 22)
        }
        .frame(width: 208)
        .background(SagePalette.canvasWarm)
    }

    private func navItem(_ icon: String, _ label: String, selected: Bool, badge: String? = nil) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12.5, weight: .regular))
                .frame(width: 16)
            Text(label)
                .font(.system(size: 13, weight: selected ? .semibold : .regular))
            Spacer()
            if let badge {
                Text(badge)
                    .font(.system(size: 10, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(selected ? SagePalette.canvas.opacity(0.9) : SagePalette.inkSoft)
            }
        }
        .foregroundStyle(selected ? SagePalette.canvas : SagePalette.ink.opacity(0.75))
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(selected ? SagePalette.accentDeep : .clear)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 2)
    }

    // MARK: Focus page

    private var focusPage: some View {
        VStack(spacing: 0) {
            // Hero — clock and its own controls, together
            VStack(spacing: 0) {
                Text(running ? "FOCUS · SESSION 3 OF 4" : "READY · 25 / 5")
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(1.8)
                    .foregroundStyle(running ? SagePalette.accentDeep : SagePalette.inkSoft)
                    .padding(.bottom, 10)

                Text(running ? Mock.remaining : "25:00")
                    .font(.system(size: 88, weight: .regular, design: .serif))
                    .monospacedDigit()
                    .foregroundStyle(SagePalette.ink)

                HStack(spacing: 6) {
                    ForEach(0..<4) { i in
                        Capsule()
                            .fill(running
                                  ? (i < 2 ? SagePalette.accentDeep : (i == 2 ? SagePalette.accent : SagePalette.hairline))
                                  : SagePalette.hairline)
                            .frame(width: (running && i == 2) ? 26 : 16, height: 3)
                    }
                }
                .padding(.top, 10)

                // Ember's control pair, pulled up under the clock
                HStack(spacing: 10) {
                    if running {
                        Text("Pause")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(SagePalette.accentDeep)
                            .padding(.horizontal, 26)
                            .frame(height: 44)
                            .overlay(Capsule().strokeBorder(SagePalette.accentDeep.opacity(0.35), lineWidth: 1.2))

                        HStack(spacing: 8) {
                            Image(systemName: "stop.fill").font(.system(size: 11, weight: .bold))
                            Text("End session").font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(SagePalette.canvas)
                        .padding(.horizontal, 26)
                        .frame(height: 44)
                        .background(Capsule().fill(SagePalette.accentDeep))
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill").font(.system(size: 11, weight: .bold))
                            Text("Start focus").font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(SagePalette.canvas)
                        .padding(.horizontal, 42)
                        .frame(height: 44)
                        .background(Capsule().fill(SagePalette.accentDeep))
                    }
                }
                .padding(.top, 24)

                Text(running ? "5 min break at 3:07 PM · 1 session left after this"
                             : "Ends at 3:02 PM · break follows automatically")
                    .font(.system(size: 11.5))
                    .foregroundStyle(SagePalette.inkSoft)
                    .padding(.top, 14)
            }
            .padding(.top, 34)
            .padding(.bottom, 30)

            rule

            // Presets — underline tabs, unchanged from Sage
            HStack(spacing: 0) {
                tab("25 / 5", selected: true)
                tab("45 / 10", selected: false)
                tab("Custom", selected: false)
            }
            .frame(height: 46)

            rule

            // Guarded apps — Ember's pile, links to the real table
            HStack(spacing: 12) {
                HStack(spacing: -7) {
                    ForEach(Array(Mock.apps.prefix(4).enumerated()), id: \.offset) { _, app in
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(app.2)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Image(systemName: app.1)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(SagePalette.canvas, lineWidth: 2)
                            )
                    }
                }

                Text("5 apps guarded")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(SagePalette.ink)

                Text("Guard screen")
                    .font(.system(size: 11.5))
                    .foregroundStyle(SagePalette.inkSoft)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .overlay(Capsule().strokeBorder(SagePalette.hairline, lineWidth: 1))

                Spacer()

                HStack(spacing: 5) {
                    Text("Manage").font(.system(size: 12, weight: .medium))
                    Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(SagePalette.accentDeep)
            }
            .padding(.horizontal, 26)
            .frame(height: 62)

            rule

            // Studio's weekly rhythm, in Sage's clothes
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("THIS WEEK")
                        .font(.system(size: 9.5, weight: .semibold))
                        .tracking(1.6)
                        .foregroundStyle(SagePalette.inkSoft)
                    Spacer()
                    Text("Today 2h 40m · 4 sessions")
                        .font(.system(size: 11.5))
                        .foregroundStyle(SagePalette.inkSoft)
                }

                VStack(spacing: 0) {
                    HStack(alignment: .bottom, spacing: 12) {
                        ForEach(Array(Mock.weekBars.enumerated()), id: \.offset) { i, value in
                            Rectangle()
                                .fill(i == 4 ? SagePalette.accentDeep : SagePalette.accent.opacity(0.5))
                                .frame(height: max(3, 62 * value))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 62, alignment: .bottom)

                    Rectangle().fill(SagePalette.hairline).frame(height: 1)

                    HStack(spacing: 12) {
                        ForEach(Array(Mock.weekLabels.enumerated()), id: \.offset) { i, label in
                            Text(label)
                                .font(.system(size: 10, weight: i == 4 ? .semibold : .regular))
                                .foregroundStyle(i == 4 ? SagePalette.ink : SagePalette.inkSoft)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.top, 7)
                }
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 20)

            Spacer(minLength: 0)
        }
    }

    private var rule: some View {
        Rectangle().fill(SagePalette.hairline.opacity(0.7)).frame(height: 1)
    }

    private func tab(_ label: String, selected: Bool) -> some View {
        VStack(spacing: 0) {
            Spacer()
            Text(label)
                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? SagePalette.ink : SagePalette.inkSoft)
            Spacer()
            Rectangle().fill(selected ? SagePalette.accentDeep : .clear).frame(height: 2)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Blocked apps page

    private var appsPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Blocked apps")
                        .font(.system(size: 22, weight: .regular, design: .serif))
                        .foregroundStyle(SagePalette.ink)
                    Text("5 guarded · behaviour applies during focus only")
                        .font(.system(size: 12))
                        .foregroundStyle(SagePalette.inkSoft)
                }
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                    Text("Add app").font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(SagePalette.canvas)
                .padding(.horizontal, 18)
                .frame(height: 36)
                .background(Capsule().fill(SagePalette.accentDeep))
            }
            .padding(.horizontal, 26)
            .padding(.top, 28)
            .padding(.bottom, 20)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 11.5)).foregroundStyle(SagePalette.inkSoft)
                Text("Filter applications").font(.system(size: 12.5)).foregroundStyle(SagePalette.inkSoft.opacity(0.65))
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(SagePalette.hairline, lineWidth: 1))
            .padding(.horizontal, 26)
            .padding(.bottom, 18)

            // Column headers
            HStack(spacing: 0) {
                Text("APPLICATION").frame(width: 230, alignment: .leading)
                Text("BEHAVIOUR").frame(width: 140, alignment: .leading)
                Text("BLOCKED TODAY").frame(width: 130, alignment: .leading)
                Spacer()
                Text("ACTIVE")
            }
            .font(.system(size: 9.5, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(SagePalette.inkSoft)
            .padding(.horizontal, 26)
            .padding(.bottom, 10)

            Rectangle().fill(SagePalette.hairline).frame(height: 1).padding(.horizontal, 26)

            ForEach(Array(Mock.apps.enumerated()), id: \.offset) { i, app in
                let off = (i == 4)
                HStack(spacing: 0) {
                    HStack(spacing: 11) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(app.2.opacity(off ? 0.35 : 1))
                            .frame(width: 26, height: 26)
                            .overlay(Image(systemName: app.1).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white))
                        Text(app.0)
                            .font(.system(size: 13))
                            .foregroundStyle(off ? SagePalette.inkSoft : SagePalette.ink)
                    }
                    .frame(width: 230, alignment: .leading)

                    Text(i == 2 ? "Quit app" : (i == 3 ? "Hide only" : "Guard screen"))
                        .font(.system(size: 11.5))
                        .foregroundStyle(off ? SagePalette.inkSoft : SagePalette.accentDeep)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .overlay(Capsule().strokeBorder(
                            (off ? SagePalette.hairline : SagePalette.accentDeep.opacity(0.3)), lineWidth: 1))
                        .frame(width: 140, alignment: .leading)

                    Text(["6×", "3×", "2×", "1×", "—"][i])
                        .font(.system(size: 12.5, design: .serif))
                        .monospacedDigit()
                        .foregroundStyle(SagePalette.inkSoft)
                        .frame(width: 130, alignment: .leading)

                    Spacer()

                    Capsule()
                        .fill(off ? SagePalette.hairline : SagePalette.accentDeep)
                        .frame(width: 34, height: 20)
                        .overlay(Circle().fill(SagePalette.canvas).frame(width: 15, height: 15).offset(x: off ? -6.5 : 6.5))
                }
                .padding(.horizontal, 26)
                .frame(height: 50)

                if i < Mock.apps.count - 1 {
                    Rectangle().fill(SagePalette.hairline.opacity(0.5)).frame(height: 1).padding(.horizontal, 26)
                }
            }

            Rectangle().fill(SagePalette.hairline).frame(height: 1).padding(.horizontal, 26)

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Pinned HUD

struct LockInHUD: View {
    var hovered: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(SagePalette.accent.opacity(0.22), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: Mock.progress)
                    .stroke(SagePalette.accentDeep, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 22, height: 22)

            Text(Mock.remaining)
                .font(.system(size: 30, weight: .regular, design: .serif))
                .monospacedDigit()
                .foregroundStyle(SagePalette.ink)

            VStack(alignment: .leading, spacing: 1) {
                Text("FOCUS · 25/5")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(SagePalette.accentDeep)
                    .fixedSize()
                Text("Slack, Discord, X +2")
                    .font(.system(size: 11))
                    .foregroundStyle(SagePalette.inkSoft)
                    .fixedSize()
            }

            Spacer(minLength: 12)

            if hovered {
                HStack(spacing: 14) {
                    Text("Pause").font(.system(size: 12.5)).foregroundStyle(SagePalette.inkSoft).fixedSize()
                    Text("End").font(.system(size: 12.5, weight: .medium)).foregroundStyle(SagePalette.clay).fixedSize()
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(SagePalette.accentDeep)
                        .rotationEffect(.degrees(45))
                }
            } else {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(SagePalette.inkSoft.opacity(0.5))
                    .rotationEffect(.degrees(45))
            }
        }
        .padding(.horizontal, 20)
        .frame(width: 420, height: 66)
        .background(SagePalette.canvas)
        .overlay(alignment: .bottomLeading) {
            Rectangle()
                .fill(SagePalette.accentDeep)
                .frame(width: 420 * Mock.progress, height: 2)
        }
        // Clip last so the progress rule follows the corner radius.
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(SagePalette.hairline.opacity(0.9), lineWidth: 1)
        )
    }
}

/// The HUD shown in situ, floating above whatever you are working in.
struct PinnedHUDContext: View {
    var body: some View {
        ZStack(alignment: .top) {
            // faux workspace behind it
            VStack(spacing: 0) {
                HStack(spacing: 7) {
                    ForEach(0..<3) { i in
                        Circle().fill(SagePalette.hairline.opacity(0.9)).frame(width: 9, height: 9)
                            .opacity(1 - Double(i) * 0.1)
                    }
                    Spacer()
                    Text("MainView.swift").font(.system(size: 11, weight: .medium)).foregroundStyle(SagePalette.inkSoft)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(Color(white: 0.90))

                VStack(alignment: .leading, spacing: 11) {
                    ForEach(0..<11) { i in
                        HStack(spacing: 8) {
                            Rectangle().fill(Color(white: 0.86)).frame(width: 18, height: 7)
                            Rectangle()
                                .fill(Color(white: i % 3 == 0 ? 0.80 : 0.88))
                                .frame(width: [220.0, 380, 150, 300, 260, 420, 190, 340, 240, 400, 170][i], height: 7)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(20)
                .background(Color(white: 0.945))
            }

            LockInHUD(hovered: false)
                .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 8)
                .padding(.top, 54)
        }
        .frame(width: 796, height: 300)
    }
}

// MARK: - Menu-bar tuck

struct LockInMenuBarTuck: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "apple.logo").font(.system(size: 11))
                Text("Xcode").font(.system(size: 11.5, weight: .semibold))
                Text("File").font(.system(size: 11.5))
                Text("Edit").font(.system(size: 11.5))
                Spacer()
                HStack(spacing: 5) {
                    Circle().fill(SagePalette.accentDeep).frame(width: 5, height: 5)
                    Text("18:42").font(.system(size: 11.5, weight: .medium, design: .serif)).monospacedDigit()
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4).fill(SagePalette.accentSoft.opacity(0.9)))
                Image(systemName: "wifi").font(.system(size: 11))
                Text("100%").font(.system(size: 11))
            }
            .foregroundStyle(SagePalette.ink.opacity(0.75))
            .padding(.horizontal, 14)
            .frame(height: 26)
            .background(SagePalette.canvasWarm)

            HStack {
                Spacer()
                VStack(spacing: 0) {
                    HStack(alignment: .center, spacing: 14) {
                        Text(Mock.remaining)
                            .font(.system(size: 34, weight: .regular, design: .serif))
                            .monospacedDigit()
                            .foregroundStyle(SagePalette.ink)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("FOCUS · 25/5")
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(1.4)
                                .foregroundStyle(SagePalette.accentDeep)
                                .fixedSize()
                            Text("Slack, Discord, X +2")
                                .font(.system(size: 11))
                                .foregroundStyle(SagePalette.inkSoft)
                                .lineLimit(1)
                                .fixedSize()
                        }

                        Spacer(minLength: 12)

                        Text("Pause").font(.system(size: 12.5)).foregroundStyle(SagePalette.inkSoft).fixedSize()
                        Text("End").font(.system(size: 12.5, weight: .medium)).foregroundStyle(SagePalette.clay).fixedSize()
                    }
                    .padding(.horizontal, 18)
                    .frame(height: 74)

                    Rectangle().fill(SagePalette.hairline.opacity(0.7)).frame(height: 1)

                    HStack(spacing: 0) {
                        tuckAction("Open LockIn")
                        Rectangle().fill(SagePalette.hairline.opacity(0.7)).frame(width: 1, height: 16)
                        tuckAction("Pin HUD")
                    }
                    .frame(height: 36)
                }
                .frame(width: 404)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(SagePalette.canvas)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(SagePalette.hairline.opacity(0.9), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.16), radius: 16, y: 8)
                .padding(.trailing, 22)
                .padding(.top, 6)
            }

            Spacer(minLength: 0)
        }
        .frame(width: 580, height: 220)
        .background(Color(white: 0.90))
    }

    private func tuckAction(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 12))
            .foregroundStyle(SagePalette.inkSoft)
            .frame(maxWidth: .infinity)
    }
}
