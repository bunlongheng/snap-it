import Foundation

/// One saved window position and the global shortcut that applies it.
struct Layout: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var name: String
    var frame: FrameSpec
    var shortcut: KeyCombo?

    init(id: String, name: String, frame: FrameSpec, shortcut: KeyCombo?) {
        self.id = id
        self.name = name
        self.frame = frame
        self.shortcut = shortcut
    }

    func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SnapItError.emptyName(id: id)
        }
        try frame.validate(layoutName: name)
    }
}

extension Layout {
    /// Convenience used by the defaults and by the preferences grid picker.
    static func make(
        _ id: String,
        _ name: String,
        _ x: Double, _ y: Double, _ width: Double, _ height: Double,
        _ shortcut: String?
    ) -> Layout {
        Layout(
            id: id,
            name: name,
            frame: FrameSpec(x: x, y: y, width: width, height: height),
            shortcut: shortcut.flatMap { try? KeyCombo(parsing: $0) }
        )
    }
}
