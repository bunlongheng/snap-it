import AppKit

/// Owns the running state: the config, the registered shortcuts, the menu bar
/// item and the preferences window.
final class AppController: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store: ConfigStore
    private var config: Config
    private var hotKeys: HotKeyCenter?
    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    private var preferences: PreferencesWindowController?

    /// macOS asks for Accessibility access once. Snap It matches that: one
    /// prompt per launch, then the menu bar carries the reminder instead.
    private var hasPromptedForAccessibility = false

    override init() {
        store = ConfigStore(url: ConfigStore.defaultURL())
        config = .standard
        super.init()
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadConfig()
        installStatusItem()

        hotKeys = HotKeyCenter { [weak self] layoutID in
            self?.apply(layoutID: layoutID)
        }
        reloadShortcuts()

        if !AccessibilityPermission.isTrusted {
            hasPromptedForAccessibility = true
            AccessibilityPermission.request()
        }
    }

    // MARK: - Config

    private func loadConfig() {
        do {
            config = try store.loadOrCreate()
        } catch {
            config = .standard
            present(
                title: "Snap It is using its default layouts",
                message: """
                \(error.localizedDescription)

                The file was left untouched so you can fix it by hand.
                """
            )
        }
    }

    /// Single place where a change reaches disk, the shortcuts and the menu.
    func update(_ newConfig: Config) throws {
        try store.save(newConfig)
        config = newConfig
        reloadShortcuts()
    }

    var currentConfig: Config { config }

    /// Layouts whose shortcut another application already owns.
    var shortcutConflicts: [String] { hotKeys?.conflicts ?? [] }

    private func reloadShortcuts() {
        hotKeys?.reload(with: config.layouts)
        rebuildMenu()
    }

    // MARK: - Applying layouts

    private func apply(layoutID: String) {
        guard let layout = config.layouts.first(where: { $0.id == layoutID }) else { return }
        apply(layout)
    }

    func apply(_ layout: Layout) {
        do {
            try WindowMover.apply(layout.frame, gap: config.gap)
        } catch WindowError.notTrusted {
            promptForAccessibility()
        } catch {
            NSSound.beep()
        }
    }

    private func promptForAccessibility() {
        // A grant that was later revoked earns one fresh explanation.
        if AccessibilityPermission.isTrusted { hasPromptedForAccessibility = false }

        // Beep and leave the reminder in the menu rather than stacking alerts
        // on every keypress.
        guard !hasPromptedForAccessibility, NSApp.modalWindow == nil else {
            NSSound.beep()
            rebuildMenu()
            return
        }
        hasPromptedForAccessibility = true

        let alert = NSAlert()
        alert.messageText = "Snap It needs Accessibility access"
        alert.informativeText = """
        macOS only lets an app move other windows once you allow it under \
        Privacy & Security, Accessibility.
        """
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)

        if alert.runModal() == .alertFirstButtonReturn {
            AccessibilityPermission.request()
            AccessibilityPermission.openSystemSettings()
        }
    }

    // MARK: - Menu bar

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "rectangle.split.2x1",
            accessibilityDescription: "Snap It"
        )
        item.button?.toolTip = "Snap It"
        menu.delegate = self
        menu.autoenablesItems = false
        item.menu = menu
        statusItem = item
        rebuildMenu()
    }

    /// Rebuilds in place so it is safe to call while the menu is opening.
    private func rebuildMenu() {
        menu.removeAllItems()

        if !AccessibilityPermission.isTrusted {
            let warning = NSMenuItem(
                title: "Grant Accessibility access\u{2026}",
                action: #selector(openAccessibilitySettings),
                keyEquivalent: ""
            )
            warning.target = self
            menu.addItem(warning)
            menu.addItem(.separator())
        }

        if let conflicts = hotKeys?.conflicts, !conflicts.isEmpty {
            let item = NSMenuItem(
                title: "Shortcut in use elsewhere: \(conflicts.joined(separator: ", "))",
                action: nil,
                keyEquivalent: ""
            )
            item.isEnabled = false
            menu.addItem(item)
            menu.addItem(.separator())
        }

        for layout in config.layouts {
            let item = NSMenuItem(title: layout.name, action: #selector(menuApply(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = layout.id
            if let shortcut = layout.shortcut, let equivalent = MenuKeys.keyEquivalent(for: shortcut) {
                item.keyEquivalent = equivalent.key
                item.keyEquivalentModifierMask = equivalent.flags
            }
            menu.addItem(item)
        }

        menu.addItem(.separator())
        menu.addItem(item(title: "Settings\u{2026}", action: #selector(openPreferences), key: ","))
        menu.addItem(item(title: "Reveal Config File", action: #selector(revealConfig), key: ""))
        menu.addItem(.separator())
        menu.addItem(item(title: "Quit Snap It", action: #selector(quit), key: "q"))
    }

    /// Rebuilt every time it opens, so granting access or a shortcut clash
    /// shows up without restarting the app.
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === self.menu else { return }
        rebuildMenu()
    }

    private func item(title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    // MARK: - Actions

    @objc private func menuApply(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        apply(layoutID: id)
    }

    @objc private func openAccessibilitySettings() {
        AccessibilityPermission.request()
        AccessibilityPermission.openSystemSettings()
    }

    @objc private func revealConfig() {
        try? store.save(config)
        NSWorkspace.shared.activateFileViewerSelecting([store.url])
    }

    @objc func openPreferences() {
        if preferences == nil {
            preferences = PreferencesWindowController(controller: self)
        }
        preferences?.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Shortcut recording

    /// The recorder needs the keys released back to the system while it listens.
    func suspendShortcuts() { hotKeys?.suspend() }
    func resumeShortcuts() { reloadShortcuts() }

    private func present(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
