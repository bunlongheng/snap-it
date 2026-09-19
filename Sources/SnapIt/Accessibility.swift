import AppKit
import ApplicationServices

/// Snap It moves other applications' windows, which macOS gates behind the
/// Accessibility permission. Nothing else here is privileged.
enum AccessibilityPermission {
    /// `AXIsProcessTrusted()` caches its answer for the life of the process,
    /// so an app granted access while running keeps reporting `false`. Asking
    /// with an explicit "do not prompt" option reads the live state instead.
    static var isTrusted: Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Asks macOS to show the system prompt. Returns the state as of right now,
    /// which is still `false` immediately after the prompt appears.
    @discardableResult
    static func request() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        guard let url else { return }
        NSWorkspace.shared.open(url)
    }
}

enum WindowError: Error, LocalizedError {
    case notTrusted
    case noFocusedWindow
    case windowNotMovable
    case noScreen

    var errorDescription: String? {
        switch self {
        case .notTrusted:
            return "Snap It needs Accessibility access before it can move windows."
        case .noFocusedWindow:
            return "No focused window to move."
        case .windowNotMovable:
            return "That window cannot be moved. Full screen windows and some system windows are fixed."
        case .noScreen:
            return "Could not work out which display the window is on."
        }
    }
}
