import AppKit

/// Renders a shortcut as a native menu key equivalent where macOS has one.
enum MenuKeys {
    static func keyEquivalent(for combo: KeyCombo) -> (key: String, flags: NSEvent.ModifierFlags)? {
        guard let name = KeyCombo.keyNames[combo.keyCode] else { return nil }

        let key: String
        switch name {
        case "left": key = String(utf16CodeUnits: [unichar(NSLeftArrowFunctionKey)], count: 1)
        case "right": key = String(utf16CodeUnits: [unichar(NSRightArrowFunctionKey)], count: 1)
        case "up": key = String(utf16CodeUnits: [unichar(NSUpArrowFunctionKey)], count: 1)
        case "down": key = String(utf16CodeUnits: [unichar(NSDownArrowFunctionKey)], count: 1)
        case "return": key = "\r"
        case "space": key = " "
        case "tab": key = "\t"
        default:
            guard name.count == 1 else { return nil }
            key = name
        }

        var flags: NSEvent.ModifierFlags = []
        if combo.modifiers.contains(.command) { flags.insert(.command) }
        if combo.modifiers.contains(.control) { flags.insert(.control) }
        if combo.modifiers.contains(.option) { flags.insert(.option) }
        if combo.modifiers.contains(.shift) { flags.insert(.shift) }

        return (key, flags)
    }
}
