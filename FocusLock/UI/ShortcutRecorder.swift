import AppKit
import FocusLockCore
import SwiftUI

/// Click, press a combination, done. Escape cancels; Delete clears.
struct ShortcutRecorder: View {
    @EnvironmentObject private var controller: MenuBarController
    let action: HotkeyAction

    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var hint: String?

    private var combo: KeyCombo? { controller.config.hotkeys[action] }

    var body: some View {
        HStack(spacing: 10) {
            Text(action.title)
                .font(FLTypography.body)
                .foregroundStyle(Color.flInk)
                .frame(width: 150, alignment: .leading)

            Button(action: toggleRecording) {
                Text(label)
                    .font(.system(size: 12.5, weight: .medium, design: isRecording ? .default : .rounded))
                    .foregroundStyle(isRecording ? Color.flAccentDeep : (combo == nil ? Color.flInkSoft : Color.flInk))
                    .frame(minWidth: 120)
                    .frame(height: 28)
                    .padding(.horizontal, 10)
                    .background(Color.flField, in: RoundedRectangle(cornerRadius: FLRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: FLRadius.md)
                            .strokeBorder(isRecording ? Color.flAccentDeep : Color.flHairline, lineWidth: isRecording ? 1.5 : 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Shortcut for \(action.title): \(label)")

            if combo != nil && !isRecording {
                Button {
                    controller.updateHotkeys { $0.assign(nil, to: action) }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.flInkSoft.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Clear this shortcut")
                .accessibilityLabel("Clear the \(action.title) shortcut")
            }

            if controller.hotkeyFailures.contains(action) {
                Text("Another app already uses this")
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flClay)
            } else if let hint {
                Text(hint)
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flInkSoft)
            }
        }
        .onDisappear(perform: stopRecording)
    }

    private var label: String {
        if isRecording { return "Press keys…" }
        return combo?.displayString ?? "None"
    }

    private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        hint = nil
        isRecording = true
        controller.suspendHotkeys(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch Int(event.keyCode) {
            case 53:  // Escape
                stopRecording()
            case 51, 117:  // Delete, Forward Delete
                controller.updateHotkeys { $0.assign(nil, to: action) }
                stopRecording()
            default:
                guard let combo = KeyCombo(event: event), combo.isUsable else {
                    hint = "Include ⌘, ⌥, or ⌃"
                    return nil
                }
                controller.updateHotkeys { $0.assign(combo, to: action) }
                stopRecording()
            }
            return nil
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        if isRecording {
            isRecording = false
            controller.suspendHotkeys(false)
        }
    }
}
