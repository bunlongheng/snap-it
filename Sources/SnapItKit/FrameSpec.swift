import CoreGraphics
import Foundation

/// A window position expressed as fractions of the usable screen area.
///
/// The origin is the top left of the screen's visible frame, which matches both
/// the grid picker in preferences and the Accessibility API's coordinate space.
/// Fractions keep a saved layout correct on any display size.
struct FrameSpec: Codable, Hashable, Sendable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    /// Smallest window edge Snap It will produce, as a fraction of the screen.
    /// Guards against a config that would shrink a window to nothing.
    static let minimumSide = 0.05

    func validate(layoutName: String) throws {
        for (label, value) in [("x", x), ("y", y), ("width", width), ("height", height)]
        where !value.isFinite {
            throw SnapItError.invalidFrame(layout: layoutName, reason: "\(label) is not a number")
        }
        guard x >= 0, y >= 0 else {
            throw SnapItError.invalidFrame(layout: layoutName, reason: "x and y cannot be negative")
        }
        guard width >= FrameSpec.minimumSide, height >= FrameSpec.minimumSide else {
            throw SnapItError.invalidFrame(
                layout: layoutName,
                reason: "width and height must be at least \(FrameSpec.minimumSide)"
            )
        }
        guard x + width <= 1.0 + .ulpOfOne, y + height <= 1.0 + .ulpOfOne else {
            throw SnapItError.invalidFrame(layout: layoutName, reason: "it extends past the screen")
        }
    }
}

enum Placement {
    /// Largest gap Snap It accepts, in points.
    static let maximumGap = 64.0

    /// Converts a layout into a concrete rectangle on `screen`.
    ///
    /// `screen` is the usable area in Accessibility coordinates (top left
    /// origin). `gap` is applied once against a screen edge and split between
    /// neighbours in the interior, so two halves end up evenly spaced.
    static func rect(for spec: FrameSpec, in screen: CGRect, gap: Double) -> CGRect {
        let gap = max(0, min(gap, maximumGap))
        let outer = screen.insetBy(dx: gap, dy: gap)
        guard outer.width > 0, outer.height > 0 else { return screen }

        var rect = CGRect(
            x: outer.minX + spec.x * outer.width,
            y: outer.minY + spec.y * outer.height,
            width: spec.width * outer.width,
            height: spec.height * outer.height
        )

        let half = gap / 2
        let touchesLeft = spec.x <= .ulpOfOne
        let touchesTop = spec.y <= .ulpOfOne
        let touchesRight = spec.x + spec.width >= 1 - .ulpOfOne
        let touchesBottom = spec.y + spec.height >= 1 - .ulpOfOne

        if !touchesLeft { rect.origin.x += half; rect.size.width -= half }
        if !touchesRight { rect.size.width -= half }
        if !touchesTop { rect.origin.y += half; rect.size.height -= half }
        if !touchesBottom { rect.size.height -= half }

        return rect.integral
    }
}
