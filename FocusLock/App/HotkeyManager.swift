import AppKit
import Carbon.HIToolbox
import FocusLockCore

/// System-wide shortcuts through Carbon's `RegisterEventHotKey`, which needs
/// no Accessibility permission — unlike watching every key press, it only
/// ever hears the combinations registered here.
@MainActor
final class HotkeyManager {
    var onAction: ((HotkeyAction) -> Void)?

    private var registered: [UInt32: (ref: EventHotKeyRef, action: HotkeyAction)] = [:]
    private var handlerRef: EventHandlerRef?

    private static let signature: OSType = 0x4C4B494E  // 'LKIN'

    /// Registers the enabled shortcuts, replacing any from before. Returns the
    /// actions whose combination another app already owns.
    @discardableResult
    func register(_ settings: HotkeySettings) -> Set<HotkeyAction> {
        unregisterAll()
        guard settings.enabled else { return [] }
        installHandlerIfNeeded()

        var failures: Set<HotkeyAction> = []
        for (index, action) in HotkeyAction.allCases.enumerated() {
            guard let combo = settings[action], combo.isUsable else { continue }
            let id = UInt32(index + 1)
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(
                combo.keyCode,
                combo.modifiers,
                EventHotKeyID(signature: Self.signature, id: id),
                GetApplicationEventTarget(),
                0,
                &ref
            )
            if status == noErr, let ref {
                registered[id] = (ref, action)
            } else {
                failures.insert(action)
            }
        }
        return failures
    }

    func unregisterAll() {
        for entry in registered.values {
            UnregisterEventHotKey(entry.ref)
        }
        registered.removeAll()
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard status == noErr, hotKeyID.signature == HotkeyManager.signature else {
                return OSStatus(eventNotHandledErr)
            }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(context).takeUnretainedValue()
            let id = hotKeyID.id
            Task { @MainActor in
                if let action = manager.registered[id]?.action {
                    manager.onAction?(action)
                }
            }
            return noErr
        }, 1, &eventType, context, &handlerRef)
    }
}

extension KeyCombo {
    /// Builds a combo from a key press in the recorder.
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= KeyCombo.command }
        if flags.contains(.option) { modifiers |= KeyCombo.option }
        if flags.contains(.control) { modifiers |= KeyCombo.control }
        if flags.contains(.shift) { modifiers |= KeyCombo.shift }
        self.init(keyCode: UInt32(event.keyCode), modifiers: modifiers)
    }

    /// "⌃⌥⌘S", with the key named for the current keyboard layout.
    var displayString: String {
        modifierSymbols + Self.keyName(for: keyCode)
    }

    private static let specialKeys: [Int: String] = [
        kVK_Return: "↩", kVK_Tab: "⇥", kVK_Space: "Space", kVK_Delete: "⌫", kVK_Escape: "⎋",
        kVK_ForwardDelete: "⌦", kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑",
        kVK_DownArrow: "↓", kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12"
    ]

    static func keyName(for keyCode: UInt32) -> String {
        if let special = specialKeys[Int(keyCode)] {
            return special
        }
        guard
            let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
            let layoutPointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else {
            return "Key \(keyCode)"
        }
        let layoutData = Unmanaged<CFData>.fromOpaque(layoutPointer).takeUnretainedValue() as Data
        var deadKeyState: UInt32 = 0
        var characters = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = layoutData.withUnsafeBytes { buffer -> OSStatus in
            guard let layout = buffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else {
                return OSStatus(paramErr)
            }
            return UCKeyTranslate(
                layout,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                characters.count,
                &length,
                &characters
            )
        }
        guard status == noErr, length > 0 else { return "Key \(keyCode)" }
        return String(utf16CodeUnits: characters, count: length).uppercased()
    }
}
