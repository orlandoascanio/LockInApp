import SwiftUI

// =====================================================================
// CONCEPT C — "SAGE"
// Anti-dashboard. A floating hairline HUD that sits above your work
// instead of a panel you visit. No cards, no shadows, no filled buttons
// except one. Serif display numerals, letterspaced micro-labels, sand
// canvas, moss accent. Everything secondary is disclosed on demand.
// Architecture: 560pt wide floating strip → expands in place.
// =====================================================================

enum SagePalette {
    static let accent = Color(red: 0.38, green: 0.55, blue: 0.41)      // #618C69
    static let accentDeep = Color(red: 0.23, green: 0.38, blue: 0.28)  // #3B6148
    static let accentSoft = Color(red: 0.85, green: 0.88, blue: 0.82)  // #D9E0D1
    static let canvas = Color(red: 0.96, green: 0.95, blue: 0.91)      // #F5F2E8
    static let canvasWarm = Color(red: 0.93, green: 0.91, blue: 0.85)
    static let ink = Color(red: 0.16, green: 0.19, blue: 0.16)         // #293129
    static let inkSoft = Color(red: 0.45, green: 0.48, blue: 0.43)     // #737B6E
    static let hairline = Color(red: 0.80, green: 0.78, blue: 0.71)
    static let clay = Color(red: 0.72, green: 0.45, blue: 0.33)        // #B87355
}

struct SageShowcase: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 40) {
            SectionTitle(
                index: "03",
                title: "Sage — the quiet companion",
                body_: "The opposite bet. A focus app should not be a place you go; it should be a thin presence at the edge of your screen. One hairline strip floats above your work with the time and a single action. Tap once and it unfolds in place — presets, guarded apps, today's log — then folds away again. Serif numerals and sand tones so it reads like paper, not software.",
                accent: SagePalette.accentDeep
            )

            HStack(alignment: .top, spacing: 32) {
                ScreenCard("Collapsed HUD", note: "560 × 104 · floats over your work") {
                    SageStrip()
                }
                ScreenCard("Menu-bar tuck", note: "Alternate: same strip, docked under the menu bar") {
                    SageMenuBarTuck()
                }
            }

            ScreenCard("Expanded in place", note: "560 × 556 · the strip unfolds — presets, apps, log") {
                SageExpanded()
            }

            ScreenCard("Guard screen", note: "One sentence, one choice, no chrome") {
                SageGuard()
            }
        }
    }
}

// MARK: - Collapsed strip

struct SageStrip: View {
    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle().stroke(SagePalette.accent.opacity(0.22), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: Mock.progress)
                    .stroke(SagePalette.accentDeep, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Circle().fill(SagePalette.accentDeep).frame(width: 5, height: 5)
            }
            .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text("FOCUS")
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(SagePalette.accentDeep)
                Text("5 apps guarded")
                    .font(.system(size: 11.5))
                    .foregroundStyle(SagePalette.inkSoft)
            }

            Spacer()

            Text(Mock.remaining)
                .font(.system(size: 40, weight: .regular, design: .serif))
                .monospacedDigit()
                .foregroundStyle(SagePalette.ink)

            Spacer()

            HStack(spacing: 14) {
                sageGlyph("pause")
                sageGlyph("stop")
                Rectangle().fill(SagePalette.hairline).frame(width: 1, height: 20)
                sageGlyph("chevron.down")
            }
        }
        .padding(.horizontal, 22)
        .frame(width: 560, height: 104)
        .background(SagePalette.canvas)
        .overlay(alignment: .bottom) {
            Rectangle().fill(SagePalette.accentDeep).frame(width: 560 * Mock.progress, height: 2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func sageGlyph(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(SagePalette.inkSoft)
            .frame(width: 26, height: 26)
    }
}

struct SageMenuBarTuck: View {
    var body: some View {
        VStack(spacing: 0) {
            // faux menu bar
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
                Image(systemName: "wifi").font(.system(size: 11))
                Text("100%").font(.system(size: 11))
            }
            .foregroundStyle(SagePalette.ink.opacity(0.75))
            .padding(.horizontal, 14)
            .frame(height: 26)
            .background(SagePalette.canvasWarm)

            HStack(spacing: 14) {
                Text("18:42")
                    .font(.system(size: 28, weight: .regular, design: .serif))
                    .monospacedDigit()
                    .foregroundStyle(SagePalette.ink)

                VStack(alignment: .leading, spacing: 1) {
                    Text("FOCUS · 25/5").font(.system(size: 9, weight: .semibold)).tracking(1.4).foregroundStyle(SagePalette.accentDeep)
                    Text("Slack, Discord, X +2").font(.system(size: 11)).foregroundStyle(SagePalette.inkSoft)
                }

                Spacer()

                Text("Pause").font(.system(size: 12)).foregroundStyle(SagePalette.inkSoft)
                Text("End").font(.system(size: 12)).foregroundStyle(SagePalette.clay)
            }
            .padding(.horizontal, 18)
            .frame(height: 78)
            .background(SagePalette.canvas)

            Spacer(minLength: 0)
        }
        .frame(width: 420, height: 104)
        .background(SagePalette.canvasWarm)
    }
}

// MARK: - Expanded

struct SageExpanded: View {
    var body: some View {
        VStack(spacing: 0) {
            // Hero
            VStack(spacing: 10) {
                Text("FOCUS · SESSION 3 OF 4")
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(1.8)
                    .foregroundStyle(SagePalette.accentDeep)

                Text(Mock.remaining)
                    .font(.system(size: 82, weight: .regular, design: .serif))
                    .monospacedDigit()
                    .foregroundStyle(SagePalette.ink)

                HStack(spacing: 6) {
                    ForEach(0..<4) { i in
                        Capsule()
                            .fill(i < 2 ? SagePalette.accentDeep : SagePalette.hairline)
                            .frame(width: i == 2 ? 26 : 16, height: 3)
                    }
                }
                .padding(.top, 2)
            }
            .padding(.top, 30)
            .padding(.bottom, 22)

            sageRule

            // Presets — underline tabs, not buttons
            HStack(spacing: 0) {
                sageTab("25 / 5", selected: true)
                sageTab("45 / 10", selected: false)
                sageTab("Custom", selected: false)
            }
            .frame(height: 46)

            sageRule

            // Guarded apps as a single reading line
            VStack(alignment: .leading, spacing: 10) {
                Text("GUARDED")
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(SagePalette.inkSoft)

                HStack(spacing: 8) {
                    ForEach(Array(Mock.apps.enumerated()), id: \.offset) { _, app in
                        HStack(spacing: 6) {
                            Circle().fill(app.2).frame(width: 6, height: 6)
                            Text(app.0).font(.system(size: 12.5)).foregroundStyle(SagePalette.ink)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .overlay(Capsule().strokeBorder(SagePalette.hairline, lineWidth: 1))
                    }
                    Text("edit")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SagePalette.accentDeep)
                        .underline()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 26)
            .padding(.vertical, 18)

            sageRule

            // Today's log — plain rows, no card
            VStack(spacing: 0) {
                HStack {
                    Text("TODAY").font(.system(size: 9.5, weight: .semibold)).tracking(1.6).foregroundStyle(SagePalette.inkSoft)
                    Spacer()
                    Text("2h 40m · 4 sessions").font(.system(size: 11.5)).foregroundStyle(SagePalette.inkSoft)
                }
                .padding(.bottom, 10)

                ForEach(Array(Mock.history.prefix(3).enumerated()), id: \.offset) { _, entry in
                    HStack(spacing: 10) {
                        Text(entry.0.replacingOccurrences(of: "Today, ", with: ""))
                            .font(.system(size: 12, design: .serif))
                            .monospacedDigit()
                            .foregroundStyle(SagePalette.inkSoft)
                            .frame(width: 44, alignment: .leading)

                        Rectangle()
                            .fill(entry.3 ? SagePalette.accent : SagePalette.hairline)
                            .frame(width: entry.1.contains("45") ? 150 : 84, height: 8)

                        Text(entry.2)
                            .font(.system(size: 11.5))
                            .foregroundStyle(entry.3 ? SagePalette.inkSoft : SagePalette.clay)

                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 16)

            Spacer(minLength: 0)

            sageRule

            // Single filled action on the whole screen
            HStack(spacing: 18) {
                Text("Pause")
                    .font(.system(size: 13))
                    .foregroundStyle(SagePalette.inkSoft)

                Text("Skip to break")
                    .font(.system(size: 13))
                    .foregroundStyle(SagePalette.inkSoft)

                Spacer()

                Text("End session")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .frame(height: 36)
                    .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(SagePalette.accentDeep))
            }
            .padding(.horizontal, 26)
            .frame(height: 68)
        }
        .frame(width: 560, height: 556)
        .background(SagePalette.canvas)
    }

    private var sageRule: some View {
        Rectangle().fill(SagePalette.hairline.opacity(0.7)).frame(height: 1)
    }

    private func sageTab(_ label: String, selected: Bool) -> some View {
        VStack(spacing: 0) {
            Spacer()
            Text(label)
                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? SagePalette.ink : SagePalette.inkSoft)
            Spacer()
            Rectangle()
                .fill(selected ? SagePalette.accentDeep : .clear)
                .frame(height: 2)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Guard

struct SageGuard: View {
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HStack {
                    Text("LOCKIN")
                        .font(.system(size: 9.5, weight: .semibold))
                        .tracking(2.2)
                        .foregroundStyle(SagePalette.inkSoft)
                    Spacer()
                    Text("18:42 remaining")
                        .font(.system(size: 12, design: .serif))
                        .monospacedDigit()
                        .foregroundStyle(SagePalette.inkSoft)
                }
                .padding(.horizontal, 34)
                .padding(.top, 28)

                Spacer()

                VStack(spacing: 22) {
                    Text("Not now.")
                        .font(.system(size: 64, weight: .regular, design: .serif))
                        .foregroundStyle(SagePalette.ink)

                    Rectangle().fill(SagePalette.accentDeep).frame(width: 44, height: 2)

                    Text("Slack is guarded until this block ends.\nIt is still running — nothing was closed, nothing was lost.")
                        .font(.system(size: 15))
                        .foregroundStyle(SagePalette.inkSoft)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                }

                Spacer()

                HStack(spacing: 26) {
                    Text("Back to work")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28)
                        .frame(height: 44)
                        .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(SagePalette.accentDeep))

                    Text("Allow 5 minutes")
                        .font(.system(size: 13.5))
                        .foregroundStyle(SagePalette.inkSoft)
                        .underline()

                    Text("End session")
                        .font(.system(size: 13.5))
                        .foregroundStyle(SagePalette.clay)
                        .underline()
                }
                .padding(.bottom, 46)
            }
        }
        .frame(width: 796, height: 470)
        // Ornament sits in the background so it never drives layout.
        .background(
            ZStack {
                SagePalette.canvas
                ForEach(0..<4) { i in
                    Circle()
                        .strokeBorder(SagePalette.accent.opacity(0.10), lineWidth: 1)
                        .frame(width: 240 + CGFloat(i) * 140, height: 240 + CGFloat(i) * 140)
                }
            }
            .clipped()
        )
        .clipped()
    }
}
