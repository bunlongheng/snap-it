import Foundation
import ServiceManagement

/// Thin wrapper over the modern login item API, which needs no helper bundle.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Returns the state after the attempt, so the UI can correct itself when
    /// macOS refuses (for example while the app runs outside /Applications).
    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Snap It: could not change the login item: \(error.localizedDescription)")
        }
        return isEnabled
    }
}
