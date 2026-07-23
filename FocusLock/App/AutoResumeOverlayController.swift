import AppKit
import FocusLockCore
import SwiftUI

/// Hosts the autopilot takeover: one borderless full-screen window per display,
/// at the same level as the guard screen so it lands on top of whatever the user
/// wandered into — including full-screen video.
@MainActor
final class AutoResumeOverlayController {
    var onStartNow: (() -> Void)?
    var onPostpone: (() -> Void)?
    var onEndCycle: (() -> Void)?

    private let model = AutoResumeOverlayModel()
    private var windows: [NSWindow] = []

    var isShowing: Bool {
        !windows.isEmpty
    }

    func show(countdown: String, progress: Double, awayMinutes: Int, focusMinutes: Int, postponeMinutes: Int) {
        model.countdown = countdown
        model.progress = progress
        model.awayMinutes = awayMinutes
        model.focusMinutes = focusMinutes
        model.postponeMinutes = postponeMinutes

        guard windows.isEmpty else {
            return
        }

        let rootView = AutoResumeOverlayView(
            model: model,
            onStartNow: { [weak self] in self?.onStartNow?() },
            onPostpone: { [weak self] in self?.onPostpone?() },
            onEndCycle: { [weak self] in self?.onEndCycle?() }
        )

        for screen in NSScreen.screens {
            windows.append(BlockOverlayWindow(screen: screen, rootView: rootView))
        }

        NSApp.activate(ignoringOtherApps: true)
        for window in windows {
            window.makeKeyAndOrderFront(nil)
        }
        windows.first?.makeKey()

        // The screen may be on another Space or behind a full-screen app, so
        // bounce the Dock icon too — this is the one moment LockIn interrupts.
        NSApp.requestUserAttention(.criticalRequest)
        NSSound(named: "Submarine")?.play()
        FocusLockLog.debug("autopilot takeover shown")
    }

    /// Live-update the countdown while the takeover stays on screen.
    func update(countdown: String, progress: Double, awayMinutes: Int) {
        guard !windows.isEmpty else {
            return
        }

        model.countdown = countdown
        model.progress = progress
        model.awayMinutes = awayMinutes
    }

    func dismiss() {
        guard !windows.isEmpty else {
            return
        }

        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
        FocusLockLog.debug("autopilot takeover dismissed")
    }
}
