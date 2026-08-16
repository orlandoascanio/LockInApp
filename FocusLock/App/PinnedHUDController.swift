import AppKit
import FocusLockCore
import SwiftUI

/// Hosts the floating countdown strip.
///
/// The window sits above normal windows on every Space but stays out of the
/// way: it never takes key focus (so typing is unaffected), it is not part of
/// the window cycle, and it is only on screen while a session is running.
@MainActor
final class PinnedHUDController {
    var onEnd: (() -> Void)?
    var onUnpin: (() -> Void)?

    private let model = PinnedHUDModel()
    private var window: NSPanel?

    var isShowing: Bool {
        window?.isVisible ?? false
    }

    func show() {
        if let window {
            window.orderFrontRegardless()
            return
        }

        let rootView = PinnedHUDView(
            model: model,
            onEnd: { [weak self] in self?.onEnd?() },
            onUnpin: { [weak self] in self?.onUnpin?() }
        )

        // .nonactivatingPanel keeps the frontmost app frontmost when the HUD is
        // clicked, so using it never steals focus from what you are working in.
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 468, height: 114),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.contentView = NSHostingView(rootView: rootView)
        panel.setFrameAutosaveName("LockInPinnedHUD")

        if panel.frame.origin == .zero {
            positionAtTopCenter(panel)
        }

        panel.orderFrontRegardless()
        window = panel
        FocusLockLog.debug("pinned HUD shown")
    }

    func update(countdown: String, phaseLabel: String, guardedLine: String, progress: Double) {
        model.countdown = countdown
        model.phaseLabel = phaseLabel
        model.guardedLine = guardedLine
        model.progress = progress
    }

    func dismiss() {
        guard let window else {
            return
        }

        window.orderOut(nil)
        self.window = nil
        FocusLockLog.debug("pinned HUD dismissed")
    }

    private func positionAtTopCenter(_ panel: NSPanel) {
        guard let screen = NSScreen.main else {
            return
        }

        let visible = screen.visibleFrame
        let origin = NSPoint(
            x: visible.midX - panel.frame.width / 2,
            y: visible.maxY - panel.frame.height - 12
        )
        panel.setFrameOrigin(origin)
    }
}
