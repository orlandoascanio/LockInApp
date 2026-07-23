import AppKit
import SwiftUI

/// `UIConcepts --export <dir>` renders every mockup screen to a 2x PNG and quits.
/// Useful for reviewing the concepts without keeping a window open.
@MainActor
enum ConceptExporter {
    static func runIfRequested() {
        let args = CommandLine.arguments
        guard let flag = args.firstIndex(of: "--export") else { return }
        let dir = args.indices.contains(flag + 1) ? args[flag + 1] : FileManager.default.currentDirectoryPath
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        write(LockInWindow(page: .focus, running: true), to: dir, name: "redesign-1-focus")
        write(LockInWindow(page: .focus, running: false), to: dir, name: "redesign-2-focus-idle")
        write(LockInWindow(page: .apps, running: true), to: dir, name: "redesign-3-apps")
        write(PinnedHUDContext(), to: dir, name: "redesign-4-hud-pinned")
        write(LockInHUD(hovered: true), to: dir, name: "redesign-5-hud-hover")
        write(LockInMenuBarTuck(), to: dir, name: "redesign-6-menubar")

        write(EmberPanel(isRunning: true), to: dir, name: "ember-1-panel-running")
        write(EmberPanel(isRunning: false), to: dir, name: "ember-2-panel-idle")
        write(EmberGuard(), to: dir, name: "ember-3-guard")
        write(EmberSheet(), to: dir, name: "ember-4-sheet")

        write(StudioWindow(page: .dashboard), to: dir, name: "studio-1-dashboard")
        write(StudioWindow(page: .apps), to: dir, name: "studio-2-apps")
        write(StudioGuard(), to: dir, name: "studio-3-guard")

        write(SageStrip(), to: dir, name: "sage-1-strip")
        write(SageMenuBarTuck(), to: dir, name: "sage-2-menubar")
        write(SageExpanded(), to: dir, name: "sage-3-expanded")
        write(SageGuard(), to: dir, name: "sage-4-guard")

        print("Exported concept screens to \(dir)")
        exit(0)
    }

    private static func write<V: View>(_ view: V, to dir: String, name: String) {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .light))
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else {
            print("failed: \(name)")
            return
        }
        try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
    }
}
