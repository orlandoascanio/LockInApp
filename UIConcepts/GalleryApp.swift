import SwiftUI

@main
struct UIConceptsGalleryApp: App {
    init() {
        ConceptExporter.runIfRequested()
        NSApplication.shared.setActivationPolicy(.regular)
        DispatchQueue.main.async { NSApp.activate(ignoringOtherApps: true) }
    }

    var body: some Scene {
        WindowGroup("LockIn — UI Concepts") {
            GalleryRoot()
                .frame(minWidth: 1080, minHeight: 760)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1240, height: 900)
    }
}

// MARK: - Gallery shell

enum Concept: String, CaseIterable, Identifiable {
    case lockIn = "★ Redesign"
    case ember = "Ember"
    case studio = "Studio"
    case sage = "Sage"

    var id: String { rawValue }

    var tagline: String {
        switch self {
        case .lockIn: return "Sage base · Studio sidebar · Ember controls"
        case .ember: return "Warm ritual panel · radial timer"
        case .studio: return "Sidebar dashboard · data rich"
        case .sage: return "Quiet HUD · typographic minimalism"
        }
    }

    var swatch: [Color] {
        switch self {
        case .lockIn: return [SagePalette.accent, SagePalette.accentDeep, SagePalette.canvas]
        case .ember: return [EmberPalette.accent, EmberPalette.accentDeep, EmberPalette.canvas]
        case .studio: return [StudioPalette.accent, StudioPalette.violet, StudioPalette.canvas]
        case .sage: return [SagePalette.accent, SagePalette.accentDeep, SagePalette.canvas]
        }
    }
}

struct GalleryRoot: View {
    @State private var concept: Concept = .lockIn

    var body: some View {
        VStack(spacing: 0) {
            chrome
            Divider().opacity(0.5)

            ScrollView {
                VStack(spacing: 56) {
                    switch concept {
                    case .lockIn: LockInShowcase()
                    case .ember: EmberShowcase()
                    case .studio: StudioShowcase()
                    case .sage: SageShowcase()
                    }
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 48)
                .frame(maxWidth: .infinity)
            }
            .background(GalleryBackdrop(concept: concept))
        }
        .background(Color(white: 0.96))
    }

    private var chrome: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 2) {
                Text("LockIn · UI Concepts")
                    .font(.system(size: 15, weight: .semibold))
                Text(concept.tagline)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                ForEach(Concept.allCases) { item in
                    ConceptTab(concept: item, isSelected: item == concept) {
                        withAnimation(.easeOut(duration: 0.22)) { concept = item }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 16)
        .background(.regularMaterial)
    }
}

private struct ConceptTab: View {
    let concept: Concept
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                HStack(spacing: -4) {
                    ForEach(Array(concept.swatch.enumerated()), id: \.offset) { _, color in
                        Circle()
                            .fill(color)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().strokeBorder(.white.opacity(0.8), lineWidth: 1))
                    }
                }
                Text(concept.rawValue)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? Color.primary.opacity(0.09) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color.primary.opacity(isSelected ? 0.14 : 0.07), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct GalleryBackdrop: View {
    let concept: Concept

    var body: some View {
        LinearGradient(
            colors: [concept.swatch[2], concept.swatch[2].opacity(0.55)],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(
            RadialGradient(
                colors: [concept.swatch[0].opacity(0.10), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 700
            )
        )
        .ignoresSafeArea()
    }
}

// MARK: - Showcase framing helpers

struct ScreenCard<Content: View>: View {
    let title: String
    let note: String
    var chromeTint: Color = .white
    private let content: Content

    init(_ title: String, note: String, chromeTint: Color = .white, @ViewBuilder content: () -> Content) {
        self.title = title
        self.note = note
        self.chromeTint = chromeTint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.75))
                Text(note)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }

            content
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.16), radius: 30, x: 0, y: 16)
        }
    }
}

struct SectionTitle: View {
    let index: String
    let title: String
    let body_: String
    let accent: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(index)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(accent)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 22, weight: .semibold))
                Text(body_)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 620, alignment: .leading)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Shared mock data

enum Mock {
    static let remaining = "18:42"
    static let progress: Double = 0.252
    static let apps: [(String, String, Color)] = [
        ("Slack", "message.fill", Color(red: 0.36, green: 0.20, blue: 0.44)),
        ("Discord", "gamecontroller.fill", Color(red: 0.35, green: 0.40, blue: 0.85)),
        ("X", "at", Color(red: 0.20, green: 0.22, blue: 0.26)),
        ("YouTube", "play.rectangle.fill", Color(red: 0.85, green: 0.22, blue: 0.20)),
        ("Safari", "safari.fill", Color(red: 0.16, green: 0.52, blue: 0.86))
    ]
    static let history: [(String, String, String, Bool)] = [
        ("Today, 14:05", "Focus · 45 min", "Completed", true),
        ("Today, 13:12", "Focus · 25 min", "Completed", true),
        ("Today, 11:40", "Focus · 25 min", "Stopped early", false),
        ("Today, 10:02", "Focus · 45 min", "Completed", true),
        ("Yesterday, 17:20", "Focus · 25 min", "Completed", true)
    ]
    static let weekBars: [Double] = [0.35, 0.62, 0.48, 0.80, 0.95, 0.30, 0.55]
    static let weekLabels = ["M", "T", "W", "T", "F", "S", "S"]
}
