import AppKit

// Snap It lives in the menu bar only: no Dock icon, no main window.
let application = NSApplication.shared
application.setActivationPolicy(.accessory)

let controller = AppController()
application.delegate = controller
application.run()
