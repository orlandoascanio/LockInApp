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
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NotificationCenter.default.post(name: .lockInShowMainWindow, object: nil)
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBarController?.handleAppWillTerminate()
    }
}

extension Notification.Name {
    static let lockInShowMainWindow = Notification.Name("LockInShowMainWindow")
}
