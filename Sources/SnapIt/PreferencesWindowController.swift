import AppKit
import SwiftUI

/// Hosts the SwiftUI preferences in a plain resizable window. Snap It is an
/// accessory app, so it has to activate itself to take focus.
final class PreferencesWindowController {
    private let model: PreferencesModel
    private var window: NSWindow?

    init(controller: AppController) {
        model = PreferencesModel(controller: controller)
    }

    func show() {
        if window == nil { window = makeWindow() }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.center()
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Snap It Settings"
        window.contentView = NSHostingView(rootView: PreferencesView(model: model))
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("SnapItPreferences")
        return window
    }
}
