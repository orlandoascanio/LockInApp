import Foundation
import Sparkle

/// Sparkle, switched on only once the build carries a feed and a public
/// signing key. A build without them — any local one before the release
/// setup has been run — simply has no updater rather than an error alert.
@MainActor
final class UpdateController: ObservableObject {
    static let shared = UpdateController()

    private var controller: SPUStandardUpdaterController?

    var isAvailable: Bool { controller != nil }

    func start() {
        guard controller == nil, Self.isConfigured else { return }
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        objectWillChange.send()
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }

    var automaticallyChecks: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set {
            controller?.updater.automaticallyChecksForUpdates = newValue
            objectWillChange.send()
        }
    }

    private static var isConfigured: Bool {
        let info = Bundle.main.infoDictionary ?? [:]
        let key = (info["SUPublicEDKey"] as? String ?? "").trimmingCharacters(in: .whitespaces)
        let feed = (info["SUFeedURL"] as? String ?? "").trimmingCharacters(in: .whitespaces)
        return !key.isEmpty && !key.hasPrefix("$(") && URL(string: feed)?.scheme == "https"
    }
}
