import AppKit
import CoreGraphics

/// Bridges between AppKit screen coordinates (bottom left origin, y up) and the
/// Accessibility API's coordinates (top left origin of the primary display,
/// y down). All window maths happens in Accessibility coordinates.
enum ScreenGeometry {
    /// Top edge of the primary display in AppKit coordinates, which is the
    /// line the Accessibility API measures y downwards from.
    private static var primaryMaxY: CGFloat {
        NSScreen.screens.first?.frame.maxY ?? 0
    }

    static func axFrame(of screen: NSScreen) -> CGRect {
        convert(screen.frame)
    }

    /// The area a window may occupy: excludes the menu bar and the Dock.
    static func axVisibleFrame(of screen: NSScreen) -> CGRect {
        convert(screen.visibleFrame)
    }

    private static func convert(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: primaryMaxY - rect.maxY, width: rect.width, height: rect.height)
    }

    /// The display a window belongs to: the one it overlaps most, which keeps a
    /// shortcut acting on the display the user is actually looking at.
    static func screen(containing axRect: CGRect) -> NSScreen? {
        let best = NSScreen.screens.max { lhs, rhs in
            overlap(axRect, axFrame(of: lhs)) < overlap(axRect, axFrame(of: rhs))
        }
        if let best, overlap(axRect, axFrame(of: best)) > 0 { return best }
        return NSScreen.main ?? NSScreen.screens.first
    }

    private static func overlap(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }
}
