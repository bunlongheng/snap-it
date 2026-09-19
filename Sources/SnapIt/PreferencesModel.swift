import AppKit
import Combine
import SwiftUI

/// Editing state for the preferences window.
///
/// Edits are kept in memory and written through `AppController` on every
/// change. A change that fails validation stays on screen with an explanation
/// instead of being silently dropped or written to disk.
final class PreferencesModel: ObservableObject {
    @Published var config: Config
    @Published var selection: String?
    @Published var errorMessage: String?
    @Published private(set) var isTrusted: Bool

    @Published var launchAtLogin: Bool

    private weak var controller: AppController?
    private var trustTimer: Timer?
    private var pendingCommit: DispatchWorkItem?

    init(controller: AppController) {
        self.controller = controller
        config = controller.currentConfig
        selection = controller.currentConfig.layouts.first?.id
        isTrusted = AccessibilityPermission.isTrusted
        launchAtLogin = LaunchAtLogin.isEnabled
    }

    deinit {
        stopWatching()
    }

    /// The permission is granted in System Settings, which sends no
    /// notification, so the status row polls. Only while the window is open:
    /// a menu bar app that wakes every two seconds forever is not idle.
    func startWatching() {
        guard trustTimer == nil else { return }
        refreshSystemState()
        trustTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.refreshSystemState()
        }
    }

    func stopWatching() {
        trustTimer?.invalidate()
        trustTimer = nil
        pendingCommit?.perform()
        pendingCommit = nil
    }

    private func refreshSystemState() {
        let trusted = AccessibilityPermission.isTrusted
        if trusted != isTrusted { isTrusted = trusted }
        let login = LaunchAtLogin.isEnabled
        if login != launchAtLogin { launchAtLogin = login }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLogin = LaunchAtLogin.set(enabled)
    }

    var shortcutConflicts: [String] { controller?.shortcutConflicts ?? [] }

    var selectedLayout: Layout? {
        config.layouts.first { $0.id == selection }
    }

    func binding(for id: String) -> Binding<Layout>? {
        guard let index = config.layouts.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { self.config.layouts[index] },
            set: { self.config.layouts[index] = $0; self.commitSoon() }
        )
    }

    /// Text fields report every keystroke. Saving the file and re-registering
    /// every global shortcut that often would briefly leave the shortcuts
    /// unregistered, so edits are allowed to settle first.
    func commitSoon() {
        pendingCommit?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.commit() }
        pendingCommit = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func commit() {
        pendingCommit?.cancel()
        pendingCommit = nil
        do {
            try controller?.update(config)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addLayout() {
        let layout = Layout(
            id: Self.uniqueIdentifier(existing: config.layouts.map(\.id)),
            name: "New Layout",
            frame: FrameSpec(x: 0.25, y: 0.25, width: 0.5, height: 0.5),
            shortcut: nil
        )
        config.layouts.append(layout)
        selection = layout.id
        commit()
    }

    func removeSelected() {
        guard let selection else { return }
        let index = config.layouts.firstIndex { $0.id == selection }
        config.layouts.removeAll { $0.id == selection }
        self.selection = config.layouts.indices.contains(index ?? 0)
            ? config.layouts[index ?? 0].id
            : config.layouts.last?.id
        commit()
    }

    func restoreDefaults() {
        config = .standard
        selection = config.layouts.first?.id
        commit()
    }

    func applySelectedToFocusedWindow() {
        guard let layout = selectedLayout else { return }
        controller?.apply(layout)
    }

    func suspendShortcuts() { controller?.suspendShortcuts() }
    func resumeShortcuts() { controller?.resumeShortcuts() }
    func requestAccessibility() {
        AccessibilityPermission.request()
        AccessibilityPermission.openSystemSettings()
    }

    var configPath: String {
        controller.map { _ in ConfigStore.defaultURL().path } ?? ""
    }

    private static func uniqueIdentifier(existing: [String]) -> String {
        var index = 1
        var candidate = "custom-1"
        while existing.contains(candidate) {
            index += 1
            candidate = "custom-\(index)"
        }
        return candidate
    }
}
