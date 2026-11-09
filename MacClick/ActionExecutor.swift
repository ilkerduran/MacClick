import AppKit
import Carbon

enum ActionExecutor {
    static func execute(_ action: GestureAction) {
        switch action {
        case .middleClick:
            guard let position = CGEvent(source: nil)?.location,
                  let down = CGEvent(mouseEventSource: nil, mouseType: .otherMouseDown,
                                     mouseCursorPosition: position, mouseButton: .center),
                  let up = CGEvent(mouseEventSource: nil, mouseType: .otherMouseUp,
                                   mouseCursorPosition: position, mouseButton: .center) else { return }
            for event in [down, up] {
                event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(CGMouseButton.center.rawValue))
                event.setIntegerValueField(.mouseEventClickState, value: 1)
                event.post(tap: .cgSessionEventTap)
            }
        case .shortcut(let shortcut):
            guard let down = CGEvent(keyboardEventSource: nil, virtualKey: shortcut.keyCode, keyDown: true),
                  let up = CGEvent(keyboardEventSource: nil, virtualKey: shortcut.keyCode, keyDown: false) else { return }
            var flags: CGEventFlags = []
            if shortcut.modifiers.contains(.command) { flags.insert(.maskCommand) }
            if shortcut.modifiers.contains(.control) { flags.insert(.maskControl) }
            if shortcut.modifiers.contains(.shift) { flags.insert(.maskShift) }
            if shortcut.modifiers.contains(.option) { flags.insert(.maskAlternate) }
            for event in [down, up] {
                event.flags = flags
                event.post(tap: .cgSessionEventTap)
            }
        }
    }
}

extension KeyboardShortcut {
    @MainActor
    init(event: NSEvent) {
        var modifiers: ShortcutModifiers = []
        if event.modifierFlags.contains(.command) { modifiers.insert(.command) }
        if event.modifierFlags.contains(.control) { modifiers.insert(.control) }
        if event.modifierFlags.contains(.shift) { modifiers.insert(.shift) }
        if event.modifierFlags.contains(.option) { modifiers.insert(.option) }
        self.init(keyCode: event.keyCode, modifiers: modifiers)
    }

    @MainActor
    var title: String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        return result + keyName
    }

    @MainActor
    private var keyName: String {
        switch Int(keyCode) {
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Space: return "Space"
        case kVK_Delete: return "Delete"
        case kVK_Escape: return "Esc"
        case kVK_ForwardDelete: return "Forward Delete"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_Home: return "Home"
        case kVK_End: return "End"
        case kVK_PageUp: return "Page Up"
        case kVK_PageDown: return "Page Down"
        case kVK_Help: return "Help"
        case kVK_ANSI_KeypadEnter: return "Keypad Enter"
        default: break
        }
        let functionKeys = [
            kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
            kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20
        ]
        if let index = functionKeys.firstIndex(of: Int(keyCode)) { return "F\(index + 1)" }

        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return "Key \(keyCode)"
        }
        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 8)
        let status = withExtendedLifetime(source) { () -> OSStatus in
            let data = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue()
            guard let bytes = CFDataGetBytePtr(data) else { return OSStatus(paramErr) }
            let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
            return UCKeyTranslate(layout, keyCode, UInt16(kUCKeyActionDisplay), 0,
                                  UInt32(LMGetKbdType()), UInt32(kUCKeyTranslateNoDeadKeysMask),
                                  &deadKeyState, characters.count, &length, &characters)
        }
        guard status == noErr, length > 0 else { return "Key \(keyCode)" }
        return String(decoding: characters.prefix(length), as: UTF16.self).uppercased()
    }
}

extension GestureAction {
    @MainActor
    var title: String {
        switch self {
        case .middleClick: "Middle Mouse Click"
        case .shortcut(let shortcut): shortcut.title
        }
    }
}
