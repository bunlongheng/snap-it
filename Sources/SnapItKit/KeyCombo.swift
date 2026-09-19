import Foundation

/// Modifier keys a global shortcut can require.
///
/// Raw values are private to Snap It. `HotKeyCenter` maps them to Carbon
/// modifier masks; the preferences UI maps them to `NSEvent.ModifierFlags`.
struct KeyModifiers: OptionSet, Hashable, Sendable {
    let rawValue: Int
    init(rawValue: Int) { self.rawValue = rawValue }

    static let command = KeyModifiers(rawValue: 1 << 0)
    static let control = KeyModifiers(rawValue: 1 << 1)
    static let option = KeyModifiers(rawValue: 1 << 2)
    static let shift = KeyModifiers(rawValue: 1 << 3)

    /// Shift alone is not enough to make a safe global shortcut, because it
    /// would swallow ordinary typing.
    var hasNonShiftModifier: Bool {
        !intersection([.command, .control, .option]).isEmpty
    }
}

/// A parsed global shortcut, for example `cmd+alt+left`.
///
/// Encodes to and from the single human readable string that lives in
/// `config.json`, so the file stays editable by hand.
struct KeyCombo: Codable, Hashable, Sendable {
    let keyCode: UInt16
    let modifiers: KeyModifiers

    init(keyCode: UInt16, modifiers: KeyModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init(parsing input: String) throws {
        let tokens = input
            .lowercased()
            .split(whereSeparator: { $0 == "+" || $0 == " " })
            .map(String.init)
            .filter { !$0.isEmpty }

        guard !tokens.isEmpty else { throw SnapItError.invalidShortcut(input, reason: "it is empty") }

        var modifiers: KeyModifiers = []
        var keyToken: String?

        for token in tokens {
            if let modifier = KeyCombo.modifierNames[token] {
                guard !modifiers.contains(modifier) else {
                    throw SnapItError.invalidShortcut(input, reason: "modifier '\(token)' is repeated")
                }
                modifiers.insert(modifier)
            } else if keyToken == nil {
                keyToken = token
            } else {
                throw SnapItError.invalidShortcut(input, reason: "it names more than one key")
            }
        }

        guard let keyToken else {
            throw SnapItError.invalidShortcut(input, reason: "it has modifiers but no key")
        }
        guard let keyCode = KeyCombo.keyCodes[KeyCombo.keyAliases[keyToken] ?? keyToken] else {
            throw SnapItError.invalidShortcut(input, reason: "'\(keyToken)' is not a known key")
        }
        guard modifiers.hasNonShiftModifier else {
            throw SnapItError.invalidShortcut(input, reason: "it needs cmd, ctrl or alt")
        }

        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// Canonical string form, and the value written back to `config.json`.
    var stringValue: String {
        var parts: [String] = []
        if modifiers.contains(.command) { parts.append("cmd") }
        if modifiers.contains(.control) { parts.append("ctrl") }
        if modifiers.contains(.option) { parts.append("alt") }
        if modifiers.contains(.shift) { parts.append("shift") }
        parts.append(KeyCombo.keyNames[keyCode] ?? "key\(keyCode)")
        return parts.joined(separator: "+")
    }

    /// Glyph form for menus and the preferences UI, in Apple's display order.
    var displayValue: String {
        var glyphs = ""
        if modifiers.contains(.control) { glyphs += "\u{2303}" }
        if modifiers.contains(.option) { glyphs += "\u{2325}" }
        if modifiers.contains(.shift) { glyphs += "\u{21E7}" }
        if modifiers.contains(.command) { glyphs += "\u{2318}" }
        let key = KeyCombo.keyNames[keyCode] ?? "?"
        return glyphs + (KeyCombo.keyGlyphs[key] ?? key.uppercased())
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        try self.init(parsing: raw)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(stringValue)
    }
}

extension KeyCombo {
    static let modifierNames: [String: KeyModifiers] = [
        "cmd": .command, "command": .command, "\u{2318}": .command,
        "ctrl": .control, "control": .control, "\u{2303}": .control,
        "alt": .option, "opt": .option, "option": .option, "\u{2325}": .option,
        "shift": .shift, "\u{21E7}": .shift,
    ]

    /// Spellings accepted in config files, mapped onto the canonical key name.
    static let keyAliases: [String: String] = [
        "\u{2190}": "left", "arrowleft": "left", "<": "left",
        "\u{2192}": "right", "arrowright": "right", ">": "right",
        "\u{2191}": "up", "arrowup": "up",
        "\u{2193}": "down", "arrowdown": "down",
        "enter": "return", "\u{21A9}": "return",
        "esc": "escape", "del": "delete", "spacebar": "space",
    ]

    /// Virtual key codes (Carbon `kVK_*`). Stable across keyboard layouts.
    static let keyCodes: [String: UInt16] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
        "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
        "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26,
        "-": 27, "8": 28, "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35,
        "return": 36, "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43,
        "/": 44, "n": 45, "m": 46, ".": 47, "tab": 48, "space": 49, "`": 50,
        "delete": 51, "escape": 53,
        "f5": 96, "f6": 97, "f7": 98, "f3": 99, "f8": 100, "f9": 101, "f11": 103,
        "f10": 109, "f12": 111, "help": 114, "home": 115, "pageup": 116,
        "forwarddelete": 117, "f4": 118, "end": 119, "f2": 120, "pagedown": 121, "f1": 122,
        "left": 123, "right": 124, "down": 125, "up": 126,
    ]

    static let keyNames: [UInt16: String] = {
        var names: [UInt16: String] = [:]
        for (name, code) in keyCodes { names[code] = name }
        return names
    }()

    static let keyGlyphs: [String: String] = [
        "left": "\u{2190}", "right": "\u{2192}", "up": "\u{2191}", "down": "\u{2193}",
        "return": "\u{21A9}", "tab": "\u{21E5}", "space": "\u{2423}", "escape": "\u{238B}",
        "delete": "\u{232B}", "forwarddelete": "\u{2326}", "home": "\u{2196}", "end": "\u{2198}",
        "pageup": "\u{21DE}", "pagedown": "\u{21DF}",
    ]
}
