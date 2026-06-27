import AppKit
import FocusLockCore
import SwiftUI

@MainActor
final class BreakEndedWindowController {
    var onStartFocus: (() -> Void)?
    var onSnooze: (() -> Void)?
    var onEndCycle: (() -> Void)?

    private var window: NSWindow?

    var isShowing: Bool {
        window?.isVisible == true
    }

    func show() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let rootView = BreakEndedOverlayView(
            onStartFocus: { [weak self] in self?.onStartFocus?() },
            onSnooze: { [weak self] in self?.onSnooze?() },
            onEndCycle: { [weak self] in self?.onEndCycle?() }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Break is done"
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: rootView)
        window.center()
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        FocusLockLog.debug("break-ended overlay shown")
    }

    func dismiss() {
        guard let window else {
            return
        }

        window.orderOut(nil)
        FocusLockLog.debug("break-ended overlay dismissed")
    }
}
