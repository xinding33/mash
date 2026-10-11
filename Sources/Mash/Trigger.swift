import AppKit
import Carbon.HIToolbox

/// What the user presses to turn auto-pressing on and off.
enum Trigger: Codable, Equatable {
    /// `modifiers` is an `NSEvent.ModifierFlags` raw value limited to `supportedModifiers`.
    case key(keyCode: UInt16, modifiers: UInt)
    /// `button` uses `NSEvent.buttonNumber` numbering: 2 is middle, 3 and 4 are the side buttons.
    case mouse(button: Int)

    static let `default` = Trigger.key(keyCode: UInt16(kVK_ANSI_Grave), modifiers: 0)
    static let supportedModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    /// The pressed key with no modifiers would retrigger itself on every synthetic press.
    func conflicts(withPressedKey keyCode: UInt16) -> Bool {
        self == .key(keyCode: keyCode, modifiers: 0)
    }

    var displayName: String {
        switch self {
        case let .key(keyCode, modifiers):
            return modifierSymbols(NSEvent.ModifierFlags(rawValue: modifiers)) + keyName(for: keyCode)
        case let .mouse(button):
            return button == 2 ? "Middle Mouse Button" : "Mouse Button \(button + 1)"
        }
    }
}

func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
    var result = 0
    if flags.contains(.command) { result |= cmdKey }
    if flags.contains(.option) { result |= optionKey }
    if flags.contains(.control) { result |= controlKey }
    if flags.contains(.shift) { result |= shiftKey }
    return UInt32(result)
}

private func modifierSymbols(_ flags: NSEvent.ModifierFlags) -> String {
    var result = ""
    if flags.contains(.control) { result += "⌃" }
    if flags.contains(.option) { result += "⌥" }
    if flags.contains(.shift) { result += "⇧" }
    if flags.contains(.command) { result += "⌘" }
    return result
}

private let specialKeyNames: [Int: String] = [
    kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
    kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
    kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
    kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
    kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16", kVK_F17: "F17", kVK_F18: "F18",
    kVK_F19: "F19", kVK_F20: "F20",
]

func keyName(for keyCode: UInt16) -> String {
    if let name = specialKeyNames[Int(keyCode)] { return name }
    let fallback = "Key \(keyCode)"

    guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
          let layoutPointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
    else { return fallback }
    let layoutData = unsafeBitCast(layoutPointer, to: CFData.self) as Data

    var deadKeyState: UInt32 = 0
    var chars = [UniChar](repeating: 0, count: 4)
    var length = 0
    let status = layoutData.withUnsafeBytes { bytes in
        UCKeyTranslate(
            bytes.bindMemory(to: UCKeyboardLayout.self).baseAddress,
            keyCode,
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            OptionBits(1 << kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            chars.count,
            &length,
            &chars
        )
    }
    guard status == noErr, length > 0 else { return fallback }
    return String(utf16CodeUnits: chars, count: length).uppercased()
}
