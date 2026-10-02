import AppKit
import FocusLockCore
import SwiftUI

enum AppLinks {
    static let website = URL(string: "https://www.orlandoascanio.com/products/lockin")!
    static let source = URL(string: "https://github.com/orlandoascanio/LockInApp")!
    static let releases = URL(string: "https://github.com/orlandoascanio/LockInApp/releases")!
}

/// What this copy of LockIn is, read from its own bundle.
struct AppBuildInfo {
    let version: String
    let build: String
    /// The commit the build was made from; `nil` for a build that never knew.
    let commit: String?

    static let current = AppBuildInfo(info: Bundle.main.infoDictionary ?? [:])

    init(info: [String: Any]) {
        version = info["CFBundleShortVersionString"] as? String ?? "?"
        build = info["CFBundleVersion"] as? String ?? "?"
        let rawCommit = (info["LockInSourceCommit"] as? String ?? "").trimmingCharacters(in: .whitespaces)
        commit = rawCommit.isEmpty || rawCommit == "unknown" || rawCommit.hasPrefix("$(") ? nil : rawCommit
    }

    var versionLine: String {
        var line = "\(version) (\(build))"
        if let commit {
            line += " · \(commit)"
        }
        return line
    }

    /// Where "Report a problem" goes, carrying the build and macOS version so
    /// a report says what it was written about. Nothing identifying.
    var feedbackURL: URL {
        let system = ProcessInfo.processInfo.operatingSystemVersion
        var components = URLComponents(string: "https://www.orlandoascanio.com/feedback/lockin")!
        components.queryItems = [
            URLQueryItem(name: "source", value: "app"),
            URLQueryItem(name: "v", value: version),
            URLQueryItem(name: "b", value: build),
            URLQueryItem(name: "os", value: "\(system.majorVersion).\(system.minorVersion)")
        ]
        return components.url ?? AppLinks.website
    }
}

struct AboutView: View {
    @EnvironmentObject private var controller: MenuBarController
    @ObservedObject private var updates = UpdateController.shared

    private let info = AppBuildInfo.current

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 44)
                .padding(.bottom, FLSpacing.lg)

            FLRule()

            VStack(spacing: 0) {
                row("Version", value: info.versionLine, selectable: true)
                row("Made by", value: "Orlando Ascanio")
                row("Updates", value: updatesValue) {
                    if updates.isAvailable {
                        Button("Check now") { updates.checkForUpdates() }
                            .buttonStyle(FLLinkButtonStyle())
                    }
                }
                row("Your data", value: "Stays on this Mac") {
                    Button("Show in Finder") { controller.revealDataFolder() }
                        .buttonStyle(FLLinkButtonStyle())
                }
                row("License", value: "MIT, open source", isLast: true)
            }
            .padding(.horizontal, FLSpacing.lg)

            FLRule()

            HStack(spacing: FLSpacing.md) {
                link("Website", AppLinks.website)
                link("Source code", AppLinks.source)
                link("Release notes", AppLinks.releases)
                link("Report a problem", info.feedbackURL)
            }
            .padding(.top, FLSpacing.md)

            Text("Made for fun, and for focus.")
                .font(FLTypography.caption)
                .foregroundStyle(Color.flInkSoft)
                .padding(.top, FLSpacing.md)
                .padding(.bottom, FLSpacing.lg)
        }
        .frame(width: 440)
        .background(Color.flCanvas)
    }

    private var header: some View {
        VStack(spacing: FLSpacing.sm) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 84, height: 84)
                .accessibilityHidden(true)

            Text(AppIdentity.name)
                .font(.system(size: 28, weight: .regular, design: .serif))
                .foregroundStyle(Color.flInk)

            Text("A focus timer that guards the apps and sites you reach for, without closing them.")
                .font(FLTypography.body)
                .foregroundStyle(Color.flInk.opacity(0.85))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 320)
                .padding(.top, FLSpacing.xs)
        }
    }

    private var updatesValue: String {
        guard updates.isAvailable else { return "Not available in this build" }
        return updates.automaticallyChecks ? "Checks automatically" : "Automatic checks are off"
    }

    private func row(_ label: String, value: String, selectable: Bool = false, isLast: Bool = false) -> some View {
        row(label, value: value, selectable: selectable, isLast: isLast) { EmptyView() }
    }

    private func row<Trailing: View>(
        _ label: String,
        value: String,
        selectable: Bool = false,
        isLast: Bool = false,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: FLSpacing.md) {
                FLMicroLabel(text: label)
                    .frame(width: 84, alignment: .leading)

                Group {
                    if selectable {
                        Text(value).textSelection(.enabled)
                    } else {
                        Text(value)
                    }
                }
                .font(FLTypography.body)
                .monospacedDigit()
                .foregroundStyle(Color.flInk)

                Spacer(minLength: FLSpacing.sm)

                trailing()
            }
            .padding(.vertical, 11)

            if !isLast {
                FLRule().opacity(0.6)
            }
        }
    }

    private func link(_ title: String, _ url: URL) -> some View {
        Button(title) { NSWorkspace.shared.open(url) }
            .buttonStyle(FLLinkButtonStyle())
    }
}
