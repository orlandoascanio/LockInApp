import AppKit
import FocusLockCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        FocusLockLog.debug("AppDelegate applicationDidFinishLaunching called")
        NSApp.setActivationPolicy(.regular)
        menuBarController = MenuBarController()
        menuBarController?.setup()
        UpdateController.shared.start()
        menuBarController?.setupMainMenu()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NotificationCenter.default.post(name: .lockInShowMainWindow, object: nil)
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Every quit comes through here — the menu, ⌘Q, the Dock, a script — so
    /// this is where a strict block holds the line.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let menuBarController else { return .terminateNow }
        return menuBarController.shouldAllowTermination() ? .terminateNow : .terminateCancel
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBarController?.handleAppWillTerminate()
    }

    /// `lockin://start`, `lockin://stop`, `lockin://skip`, or just `lockin://`
    /// to bring the window forward. Used by the widget when LockIn is not
    /// already running to receive its buttons.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "lockin" {
            let command = url.host ?? ""
            if let action = HotkeyAction(rawValue: command) {
                menuBarController?.perform(action)
            } else {
                menuBarController?.openMainWindow()
            }
        }
    }
}

extension Notification.Name {
    static let lockInShowMainWindow = Notification.Name("LockInShowMainWindow")
}
