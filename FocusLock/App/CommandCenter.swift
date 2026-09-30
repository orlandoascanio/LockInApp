import Foundation
import FocusLockCore

/// Where App Intents and widget buttons find the running app. Intents run in
/// the app's own process, so they reach the controller directly.
@MainActor
final class LockInCommandCenter {
    static let shared = LockInCommandCenter()

    weak var controller: MenuBarController?

    /// An intent can arrive while the app is still launching; wait briefly for
    /// the controller rather than failing the shortcut.
    func readyController() async -> MenuBarController? {
        for _ in 0..<40 {
            if let controller {
                return controller
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return controller
    }
}

/// Listens for Darwin notifications — the one channel a sandboxed widget can
/// use to reach an app outside its sandbox.
final class DarwinNotificationObserver {
    private let names: [String]
    private let handler: (String) -> Void

    init(names: [String], handler: @escaping (String) -> Void) {
        self.names = names
        self.handler = handler
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        for name in names {
            CFNotificationCenterAddObserver(center, observer, { _, observer, name, _, _ in
                guard let observer, let name else { return }
                let me = Unmanaged<DarwinNotificationObserver>.fromOpaque(observer).takeUnretainedValue()
                me.handler(name.rawValue as String)
            }, name as CFString, nil, .deliverImmediately)
        }
    }

    deinit {
        CFNotificationCenterRemoveEveryObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque()
        )
    }
}
