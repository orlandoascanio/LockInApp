import AppKit
import SwiftUI

final class BlockOverlayWindow<Content: View>: NSWindow {
    init(screen: NSScreen, rootView: Content) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = false
        setFrame(screen.frame, display: true)
        contentView = NSHostingView(rootView: rootView)
    }
}
