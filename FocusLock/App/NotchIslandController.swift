import AppKit
import FocusLockCore
import SwiftUI

/// Hosts the island that grows out of the notch.
///
/// It only exists for a moment at a time: a block or a break ran out, or a
/// minute is left. It opens out of the notch (or out of the menu bar on a
/// display without one), says what happened with the time still running
/// beside the notch, offers the one or two things worth doing next, and folds
/// back in. It never takes key focus, and a moment that needs an answer stays
/// until it gets one. Hovering keeps any moment open.
@MainActor
final class NotchIslandController {
    var onAction: ((String) -> Void)?

    private let model = NotchIslandModel()
    private var panel: NotchPanel?
    private var pollTimer: Timer?
    private var closesAt: Date?
    private var orderOutWork: DispatchWorkItem?

    var isShowing: Bool {
        panel?.isVisible == true && model.isOpen
    }

    /// The moment on screen, if one is.
    var currentMoment: NotchMoment? {
        isShowing ? model.moment : nil
    }

    func present(_ moment: NotchMoment) {
        guard let screen = Self.targetScreen else { return }
        orderOutWork?.cancel()

        let notch = Self.notchSize(on: screen)
        model.hasNotch = screen.safeAreaInsets.top > 0
        model.notch = notch

        let panel = self.panel ?? makePanel()
        let frame = Self.frame(for: moment, notch: notch, hasNotch: model.hasNotch, on: screen)
        let wasOpen = isShowing

        if wasOpen {
            panel.setFrame(frame, display: true, animate: false)
            model.moment = moment
        } else {
            model.isOpen = false
            model.moment = moment
            panel.setFrame(frame, display: true)
            panel.orderFrontRegardless()
            // Open on the next pass so SwiftUI animates from the notch outwards.
            DispatchQueue.main.async { [weak self] in
                self?.model.isOpen = true
            }
        }

        panel.ignoresMouseEvents = false
        closesAt = moment.holdsUntilAnswered ? nil : Date().addingTimeInterval(moment.lifetime)
        startPolling()
        FocusLockLog.debug("notch island: \(moment.eyebrow)")
    }

    /// Folds the island back into the notch, whatever it was saying.
    func dismiss() {
        guard let panel, panel.isVisible else { return }
        closesAt = nil
        pollTimer?.invalidate()
        pollTimer = nil
        panel.ignoresMouseEvents = true
        model.isOpen = false

        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.model.isOpen else { return }
            self.panel?.orderOut(nil)
            self.model.moment = nil
        }
        orderOutWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
    }

    /// Dismisses only if the island is still showing a moment of `kind`.
    func dismiss(ifShowing kind: NotchMoment.Kind) {
        if currentMoment?.kind == kind {
            dismiss()
        }
    }

    // MARK: - Window

    private func makePanel() -> NotchPanel {
        let rootView = NotchIslandView(
            model: model,
            onAction: { [weak self] id in self?.onAction?(id) },
            onDismiss: { [weak self] in
                guard self?.model.moment?.holdsUntilAnswered != true else { return }
                self?.dismiss()
            }
        )

        let panel = NotchPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        // Above the menu bar, which it grows out of.
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        self.panel = panel
        return panel
    }

    /// Closes the island when its time is up, unless the pointer is resting
    /// on it: someone reading it gets to finish.
    private func startPolling() {
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
    }

    private func poll() {
        guard let panel, let closesAt else { return }
        if panel.frame.contains(NSEvent.mouseLocation) {
            self.closesAt = max(closesAt, Date().addingTimeInterval(1.5))
            return
        }
        if Date() >= closesAt {
            dismiss()
        }
    }

    // MARK: - Geometry

    /// The built-in display when it has a notch, which is where people look
    /// for the island; otherwise the display with the menu bar in use.
    private static var targetScreen: NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens.first
    }

    private static func notchSize(on screen: NSScreen) -> CGSize {
        let top = screen.safeAreaInsets.top
        guard top > 0,
              let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea
        else {
            // No notch: a slim tab at the top of the menu bar to grow from.
            return CGSize(width: 150, height: 0)
        }
        return CGSize(width: screen.frame.width - left.width - right.width, height: top)
    }

    private static func frame(for moment: NotchMoment, notch: CGSize, hasNotch: Bool, on screen: NSScreen) -> CGRect {
        let content = NotchIslandContent(moment: moment, notch: notch, hasNotch: hasNotch, onAction: { _ in })
        let measured = NSHostingView(rootView: content).fittingSize
        let width = max(NotchIslandContent.width, notch.width + 160)
        let height = ceil(max(measured.height, notch.height + 40))
        return CGRect(
            x: (screen.frame.midX - width / 2).rounded(),
            y: screen.frame.maxY - height,
            width: width,
            height: height
        )
    }
}

/// A panel AppKit leaves where it is put, even over the menu bar.
private final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}
