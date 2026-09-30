import AppKit
import FocusLockCore
import SwiftUI

/// Presents a borderless, full-screen overlay (one window per attached screen)
/// when a blocked app is activated during focus. The overlay never terminates
/// anything — it simply interrupts the activation and offers a few exits.
@MainActor
final class FocusOverlayController {
    var onBackToFocus: (() -> Void)?
    var onAllow: (() -> Void)?
    var onEndSession: (() -> Void)?

    private let model = FocusOverlayModel()
    private var windows: [NSWindow] = []

    var isShowing: Bool {
        !windows.isEmpty
    }

    func show(
        appName: String,
        countdown: String,
        allowSnooze: Bool,
        allowEnd: Bool,
        snoozeMinutes: Int
    ) {
        model.appName = appName
        model.countdown = countdown
        model.allowSnooze = allowSnooze
        model.allowEnd = allowEnd
        model.snoozeMinutes = snoozeMinutes

        guard windows.isEmpty else {
            bringToFront()
            return
        }

        let rootView = FocusOverlayView(
            model: model,
            onBackToFocus: { [weak self] in self?.onBackToFocus?() },
            onAllow: { [weak self] in self?.onAllow?() },
            onEndSession: { [weak self] in self?.onEndSession?() }
        )

        for screen in NSScreen.screens {
            windows.append(makeOverlayWindow(for: screen, rootView: rootView))
        }

        bringToFront()
        FocusLockLog.debug("focus overlay shown for \(appName)")
    }

    /// Live-update the countdown while the overlay stays on screen.
    func updateCountdown(_ countdown: String) {
        guard !windows.isEmpty else {
            return
        }
        model.countdown = countdown
    }

    func dismiss() {
        guard !windows.isEmpty else {
            return
        }

        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
        FocusLockLog.debug("focus overlay dismissed")
    }

    private func bringToFront() {
        NSApp.activate(ignoringOtherApps: true)
        for window in windows {
            window.makeKeyAndOrderFront(nil)
        }
        windows.first?.makeKey()
    }

    private func makeOverlayWindow<Content: View>(for screen: NSScreen, rootView: Content) -> NSWindow {
        BlockOverlayWindow(screen: screen, rootView: rootView)
    }
}
