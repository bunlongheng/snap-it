import SwiftUI

/// One hue per step, the same spectrum the landing page and the diagrams use.
/// A layout keeps its colour wherever it appears: the sidebar dot, the grid
/// picker, the shortcut recorder.
enum Palette {
    static let spectrum: [Color] = [
        Color(hex: 0xEF4444), // red
        Color(hex: 0xF97316), // orange
        Color(hex: 0xEAB308), // amber
        Color(hex: 0x22C55E), // green
        Color(hex: 0x14B8A6), // teal
        Color(hex: 0x06B6D4), // cyan
        Color(hex: 0x3B82F6), // blue
        Color(hex: 0x8B5CF6), // violet
    ]

    static func hue(for index: Int) -> Color {
        let count = spectrum.count
        return spectrum[((index % count) + count) % count]
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
