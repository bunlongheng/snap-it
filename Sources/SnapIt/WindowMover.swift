import AppKit
import ApplicationServices

/// Applies a saved layout to whichever window currently has focus.
enum WindowMover {
    static func apply(_ frame: FrameSpec, gap: Double) throws {
        guard AccessibilityPermission.isTrusted else { throw WindowError.notTrusted }

        let window = try focusedWindow()
        guard isMovable(window) else { throw WindowError.windowNotMovable }

        let current = currentFrame(of: window) ?? .zero
        guard let screen = ScreenGeometry.screen(containing: current) else { throw WindowError.noScreen }

        let target = Placement.rect(
            for: frame,
            in: ScreenGeometry.axVisibleFrame(of: screen),
            gap: gap
        )
        try setFrame(target, of: window)
    }

    private static func focusedWindow() throws -> AXUIElement {
        guard let frontmost = NSWorkspace.shared.frontmostApplication,
              frontmost.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else { throw WindowError.noFocusedWindow }

        let application = AXUIElementCreateApplication(frontmost.processIdentifier)
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            application,
            kAXFocusedWindowAttribute as CFString,
            &value
        )
        guard status == .success, let element = value, CFGetTypeID(element) == AXUIElementGetTypeID() else {
            throw WindowError.noFocusedWindow
        }
        return element as! AXUIElement
    }

    /// Full screen windows and some system windows refuse position changes.
    /// Asking first avoids leaving a window half moved.
    private static func isMovable(_ window: AXUIElement) -> Bool {
        var settable: DarwinBoolean = false
        let position = AXUIElementIsAttributeSettable(window, kAXPositionAttribute as CFString, &settable)
        guard position == .success, settable.boolValue else { return false }

        var size: DarwinBoolean = false
        let sizeStatus = AXUIElementIsAttributeSettable(window, kAXSizeAttribute as CFString, &size)
        guard sizeStatus == .success, size.boolValue else { return false }

        return !isFullScreen(window)
    }

    private static func isFullScreen(_ window: AXUIElement) -> Bool {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &value)
        guard status == .success, let number = value as? NSNumber else { return false }
        return number.boolValue
    }

    private static func currentFrame(of window: AXUIElement) -> CGRect? {
        guard let origin = readPoint(window, kAXPositionAttribute),
              let size = readSize(window, kAXSizeAttribute)
        else { return nil }
        return CGRect(origin: origin, size: size)
    }

    private static func readPoint(_ window: AXUIElement, _ attribute: String) -> CGPoint? {
        guard let value = axValue(window, attribute) else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(value, .cgPoint, &point) else { return nil }
        return point
    }

    private static func readSize(_ window: AXUIElement, _ attribute: String) -> CGSize? {
        guard let value = axValue(window, attribute) else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(value, .cgSize, &size) else { return nil }
        return size
    }

    private static func axValue(_ window: AXUIElement, _ attribute: String) -> AXValue? {
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, attribute as CFString, &raw) == .success,
              let raw, CFGetTypeID(raw) == AXValueGetTypeID()
        else { return nil }
        return (raw as! AXValue)
    }

    /// Size, position, then size again: applications that clamp to a minimum
    /// size need the second pass or they end up at the wrong origin.
    private static func setFrame(_ rect: CGRect, of window: AXUIElement) throws {
        var origin = rect.origin
        var size = rect.size
        guard let positionValue = AXValueCreate(.cgPoint, &origin),
              let sizeValue = AXValueCreate(.cgSize, &size)
        else { throw WindowError.windowNotMovable }

        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        let status = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)

        guard status == .success else { throw WindowError.windowNotMovable }
    }
}
