import AppKit
import CoreGraphics
import FocusLockCore
import SwiftUI

/// Hosts the floating HUD.
///
/// The window sits above normal windows on every Space but stays out of the
/// way: it never takes key focus (so typing is unaffected), it is not part of
/// the window cycle, and it is only on screen while a session is running. It
/// rests small and faded, and comes back when the pointer is over it, when the
/// phase changes, and for the last minute.
@MainActor
final class PinnedHUDController: NSObject, NSMenuDelegate {
    var onEnd: (() -> Void)?
    var onUnpin: (() -> Void)?
    /// Stores a change the HUD made to its own settings: where it was
    /// dropped, or a choice from its menu.
    var onSettingsChange: (((inout HUDSettings) -> Void) -> Void)?

    /// How long the HUD stays fully visible after it last needed attention.
    private static let fadeDelay: TimeInterval = 3
    private static let pulseDuration: TimeInterval = 1.4

    private let model = PinnedHUDModel()
    private var panel: NSPanel?
    private var settings = HUDSettings()
    private var pollTimer: Timer?
    private var screenObserver: NSObjectProtocol?
    private var moveObserver: NSObjectProtocol?

    private var isHovered = false
    private var isMenuOpen = false
    private var lastAttention = Date()
    private var targetAlpha: CGFloat = 1
    /// True while the HUD itself is moving the window, so its own moves are
    /// never mistaken for a drag.
    private var isPositioning = false
    private var draggedSinceSnap = false
    private var lastMoveAt = Date.distantPast
    private var pulseEndsAt: Date?
    private var dismissAfterPulse = false
    /// The newest content, held back while the pulse shows 00:00.
    private var pendingContent: Content?

    struct Content: Equatable {
        var countdown: String
        var phaseLabel: String
        var goal: String?
        var progress: Double
        var canEnd: Bool
        var tone: HUDTone
    }

    var isShowing: Bool {
        panel?.isVisible ?? false
    }

    func apply(_ settings: HUDSettings) {
        guard settings != self.settings else { return }
        self.settings = settings
        guard panel != nil else { return }
        layout(animated: true)
        poll()
    }

    func show() {
        dismissAfterPulse = false
        if let panel {
            panel.orderFrontRegardless()
            return
        }

        let rootView = PinnedHUDView(
            model: model,
            onEnd: { [weak self] in self?.onEnd?() },
            menu: { [weak self] in self?.makeMenu() ?? NSMenu() }
        )

        // .nonactivatingPanel keeps the frontmost app frontmost when the HUD is
        // clicked, so using it never steals focus from what you are working in.
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: PinnedHUDView.compactSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // The window server's shadow follows the rounded shape and, unlike a
        // drawn one, needs no transparent margin that would catch clicks.
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        let hostingView = NSHostingView(rootView: rootView)
        // The controller sizes the window; SwiftUI just fills it.
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        self.panel = panel

        isHovered = false
        lastAttention = Date()
        targetAlpha = 1
        panel.alphaValue = 1
        layout(animated: false)
        panel.orderFrontRegardless()
        startObserving()
        FocusLockLog.debug("pinned HUD shown")
    }

    func update(countdown: String, phaseLabel: String, goal: String?, progress: Double, canEnd: Bool, tone: HUDTone) {
        let content = Content(
            countdown: countdown,
            phaseLabel: phaseLabel,
            goal: goal,
            progress: progress,
            canEnd: canEnd,
            tone: tone
        )
        guard pulseEndsAt == nil else {
            pendingContent = content
            return
        }
        show(content)
    }

    /// Plays the pulse at 0:00, alongside the chime. If the session is over,
    /// the HUD stays up until it has finished.
    func pulse() {
        guard panel != nil else { return }
        show(Content(
            countdown: "00:00",
            phaseLabel: model.phaseLabel,
            goal: model.goal,
            progress: 1,
            canEnd: model.canEnd,
            tone: model.tone
        ))
        pulseEndsAt = Date().addingTimeInterval(Self.pulseDuration)
        model.pulseCount += 1
        poll()
    }

    func dismiss() {
        guard panel != nil else { return }
        if pulseEndsAt != nil {
            dismissAfterPulse = true
            return
        }
        tearDown()
    }

    // MARK: - Content

    private func show(_ content: Content) {
        if content.tone != model.tone {
            // A new phase, or the last minute: worth a look.
            lastAttention = Date()
        }
        if model.countdown != content.countdown { model.countdown = content.countdown }
        if model.phaseLabel != content.phaseLabel { model.phaseLabel = content.phaseLabel }
        if model.goal != content.goal { model.goal = content.goal }
        if model.progress != content.progress { model.progress = content.progress }
        if model.canEnd != content.canEnd { model.canEnd = content.canEnd }
        if model.tone != content.tone { model.tone = content.tone }
    }

    private func tearDown() {
        pollTimer?.invalidate()
        pollTimer = nil
        [screenObserver, moveObserver].compactMap { $0 }.forEach(NotificationCenter.default.removeObserver)
        screenObserver = nil
        moveObserver = nil
        pulseEndsAt = nil
        pendingContent = nil
        dismissAfterPulse = false
        panel?.orderOut(nil)
        panel = nil
        FocusLockLog.debug("pinned HUD dismissed")
    }

    // MARK: - Watching the pointer

    private func startObserving() {
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        // .common keeps it running during a drag or while the menu is open.
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.layout(animated: false) }
        }
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            // Posted on the main thread while the move happens, so
            // `isPositioning` still describes who moved it.
            MainActor.assumeIsolated {
                guard let self, !self.isPositioning else { return }
                self.draggedSinceSnap = true
                self.lastMoveAt = Date()
            }
        }
    }

    private func poll() {
        guard let panel else { return }
        let now = Date()

        if let pulseEndsAt, now >= pulseEndsAt {
            self.pulseEndsAt = nil
            lastAttention = now
            if dismissAfterPulse {
                tearDown()
                return
            }
            if let pendingContent {
                show(pendingContent)
                self.pendingContent = nil
            }
        }

        // The window server carries out the drag and the window can still be
        // catching up after the button comes up, so wait for it to settle.
        let buttonDown = Self.isMouseButtonDown
        if draggedSinceSnap, !buttonDown, now.timeIntervalSince(lastMoveAt) > 0.25 {
            finishDrag()
        }

        let interactive = !settings.clickThrough || NSEvent.modifierFlags.contains(.option)
        if panel.ignoresMouseEvents == interactive {
            panel.ignoresMouseEvents = !interactive
        }

        let pointerInside = panel.frame.insetBy(dx: -2, dy: -2).contains(NSEvent.mouseLocation)
        // Until a drag has been snapped, the HUD keeps the size it was
        // dragged at, so the snap works from where it was dropped.
        let hovered = interactive && (pointerInside || draggedSinceSnap || isMenuOpen)
        if hovered != isHovered {
            isHovered = hovered
            if !hovered { lastAttention = now }
            layout(animated: false)
        }

        let needsAttention = hovered
            || pulseEndsAt != nil
            || model.tone == .finalMinute
            || now.timeIntervalSince(lastAttention) < Self.fadeDelay
        let alpha = needsAttention ? 1 : CGFloat(settings.restingOpacity)
        if alpha != targetAlpha {
            targetAlpha = alpha
            NSAnimationContext.runAnimationGroup { context in
                // Fading away is gentle; coming back is quick.
                context.duration = alpha < panel.alphaValue ? 0.8 : 0.15
                panel.animator().alphaValue = alpha
            }
        }
    }

    /// Session-wide state, so it agrees with the events the drag was made of.
    /// `NSEvent.pressedMouseButtons` can lag behind it.
    private static var isMouseButtonDown: Bool {
        CGEventSource.buttonState(.combinedSessionState, button: .left)
    }

    // MARK: - Placement

    private var isExpanded: Bool {
        isHovered || settings.size == .large
    }

    /// The display the HUD belongs on: the last one it was put on, if it is
    /// still connected.
    private var targetScreen: NSScreen? {
        if let last = settings.lastDisplay, let screen = NSScreen.screens.first(where: { $0.lockInDisplayKey == last }) {
            return screen
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    private func layout(animated: Bool) {
        guard let panel, let screen = targetScreen else { return }
        let expanded = isExpanded
        let size = expanded ? PinnedHUDView.expandedSize : PinnedHUDView.compactSize
        let placement = settings.placement(forDisplay: screen.lockInDisplayKey)
        let frame = placement.frame(size: size, in: screen.visibleFrame)

        if model.isExpanded != expanded { model.isExpanded = expanded }
        if model.showsControls != isHovered { model.showsControls = isHovered }

        guard panel.frame != frame else { return }
        isPositioning = true
        if animated {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                panel.animator().setFrame(frame, display: true)
            }, completionHandler: { [weak self, weak panel] in
                MainActor.assumeIsolated {
                    self?.isPositioning = false
                    panel?.invalidateShadow()
                }
            })
        } else {
            panel.setFrame(frame, display: true)
            isPositioning = false
            // The shadow is cut from the window's shape, which just changed.
            DispatchQueue.main.async { [weak panel] in
                panel?.invalidateShadow()
            }
        }
    }

    /// Snaps a dropped HUD to the nearest edge or the middle and remembers
    /// where it went, for the display it was dropped on.
    private func finishDrag() {
        guard draggedSinceSnap, let panel else { return }
        draggedSinceSnap = false
        guard let screen = panel.screen ?? targetScreen, let key = screen.lockInDisplayKey else { return }

        let placement = HUDPlacement.snapped(frame: panel.frame, in: screen.visibleFrame)
        change {
            $0.placements[key] = placement
            $0.lastDisplay = key
        }
        layout(animated: true)
    }

    private func change(_ mutate: (inout HUDSettings) -> Void) {
        mutate(&settings)
        onSettingsChange?(mutate)
    }

    // MARK: - Menu

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        menu.addItem(.sectionHeader(title: "Size"))
        for size in HUDSettings.Size.allCases {
            menu.addItem(ActionMenuItem(size.displayName, checked: settings.size == size) { [weak self] in
                self?.change { $0.size = size }
                self?.layout(animated: true)
            })
        }

        menu.addItem(.separator())
        menu.addItem(.sectionHeader(title: "While you work"))
        for opacity in HUDSettings.restingOpacityChoices {
            let title = opacity >= 1 ? "Don't Fade" : "Fade to \(Int((opacity * 100).rounded()))%"
            menu.addItem(ActionMenuItem(title, checked: settings.restingOpacity == opacity) { [weak self] in
                self?.change { $0.restingOpacity = opacity }
            })
        }
        let clickThrough = ActionMenuItem("Let Clicks Pass Through", checked: settings.clickThrough) { [weak self] in
            self?.change { $0.clickThrough.toggle() }
        }
        clickThrough.toolTip = "Clicks reach whatever is under the HUD. Hold Option to use it."
        menu.addItem(clickThrough)

        menu.addItem(.separator())
        menu.addItem(ActionMenuItem("Move to Top Right") { [weak self] in
            guard let self, let key = self.targetScreen?.lockInDisplayKey else { return }
            self.change { $0.placements[key] = nil }
            self.layout(animated: true)
        })
        menu.addItem(ActionMenuItem("Unpin HUD") { [weak self] in
            self?.onUnpin?()
        })
        return menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
    }

    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
        lastAttention = Date()
    }
}

/// A menu item that runs a closure.
private final class ActionMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, checked: Bool = false, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
        state = checked ? .on : .off
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func run() {
        handler()
    }
}

extension NSScreen {
    /// A stable identifier for the display, kept across launches and
    /// reconnections, unlike its display number.
    var lockInDisplayKey: String? {
        guard
            let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
            let uuid = CGDisplayCreateUUIDFromDisplayID(number)?.takeRetainedValue()
        else {
            return nil
        }
        return CFUUIDCreateString(nil, uuid) as String
    }
}
