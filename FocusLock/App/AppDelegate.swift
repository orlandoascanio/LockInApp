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
        NotificationCenter.default.post(name: .quietwhileShowMainWindow, object: nil)
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

    /// `quietwhile://start`, `quietwhile://stop`, `quietwhile://skip`, or just
    /// `quietwhile://` to bring the window forward. Used by the widget when
    /// Quietwhile is not already running to receive its buttons. The LockIn-era
    /// `lockin://` still works, for shortcuts and scripts made before the rename.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "quietwhile" || url.scheme == "lockin" {
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
    static let quietwhileShowMainWindow = Notification.Name("QuietwhileShowMainWindow")
}
