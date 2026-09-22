import Foundation

/// The whole of Snap It's state: a gap and a list of saved layouts.
struct Config: Codable, Hashable, Sendable {
    var gap: Double
    var grid: GridSize
    var layouts: [Layout]

    init(gap: Double = 0, grid: GridSize = .standard, layouts: [Layout]) {
        self.gap = gap
        self.grid = grid
        self.layouts = layouts
    }

    /// Tolerates a config file that omits `gap` or `grid`.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gap = try container.decodeIfPresent(Double.self, forKey: .gap) ?? 0
        grid = try container.decodeIfPresent(GridSize.self, forKey: .grid) ?? .standard
        layouts = try container.decode([Layout].self, forKey: .layouts)
    }

    /// Rejects anything that would produce a broken window placement or a
    /// shortcut that silently never fires.
    func validate() throws {
        guard gap.isFinite, gap >= 0, gap <= Placement.maximumGap else {
            throw SnapItError.invalidGap(gap)
        }
        try grid.validate()

        var seenIdentifiers = Set<String>()
        var owners: [String: [String]] = [:]

        for layout in layouts {
            try layout.validate()
            guard seenIdentifiers.insert(layout.id).inserted else {
                throw SnapItError.duplicateIdentifier(layout.id)
            }
            if let shortcut = layout.shortcut {
                owners[shortcut.stringValue, default: []].append(layout.name)
            }
        }

        if let clash = owners.first(where: { $0.value.count > 1 }) {
            throw SnapItError.duplicateShortcut(clash.key, layouts: clash.value.sorted())
        }
    }

    func validated() throws -> Config {
        try validate()
        return self
    }
}

extension Config {
    /// Shipped defaults: a 6 by 6 grid with halves and thirds, on the key
    /// combinations most window managers already use.
    static let standard = Config(
        gap: 0,
        grid: .standard,
        layouts: [
            .make("left-half", "Left Half", 0, 0, 0.5, 1, "cmd+alt+left"),
            .make("right-half", "Right Half", 0.5, 0, 0.5, 1, "cmd+alt+right"),
            .make("maximize", "Maximize", 0, 0, 1, 1, "cmd+alt+up"),
            .make("top-half", "Top Half", 0, 0, 1, 0.5, "cmd+ctrl+alt+up"),
            .make("bottom-half", "Bottom Half", 0, 0.5, 1, 0.5, "cmd+ctrl+alt+down"),
            .make("left-third", "Left Third", 0, 0, 1.0 / 3, 1, "cmd+alt+1"),
            .make("center-third", "Center Third", 1.0 / 3, 0, 1.0 / 3, 1, "cmd+alt+3"),
            .make("right-third", "Right Third", 2.0 / 3, 0, 1.0 / 3, 1, "cmd+alt+5"),
            .make("right-two-thirds", "Right Two Thirds", 1.0 / 3, 0, 2.0 / 3, 1, "cmd+alt+2"),
            .make("center-two-thirds", "Center Two Thirds", 1.0 / 6, 0, 2.0 / 3, 1, "cmd+ctrl+alt+c"),
        ]
    )
}
