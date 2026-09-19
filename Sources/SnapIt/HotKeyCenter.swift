import Carbon.HIToolbox
import Foundation

/// Registers system wide shortcuts through Carbon's hot key API.
///
/// This is the one path that does not need an event tap, so Snap It never sees
/// a single keystroke it was not explicitly given.
final class HotKeyCenter {
    /// Called on the main thread when a registered shortcut fires.
    private let onTrigger: (String) -> Void

    private var handlerRef: EventHandlerRef?
    private var registered: [UInt32: (ref: EventHotKeyRef, layoutID: String)] = [:]
    private var nextID: UInt32 = 1

    /// Layouts whose shortcut another application already owns.
    private(set) var conflicts: [String] = []

    init(onTrigger: @escaping (String) -> Void) {
        self.onTrigger = onTrigger
        installHandler()
    }

    deinit {
        unregisterAll()
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }

    /// Replaces every registration with the shortcuts in `layouts`.
    func reload(with layouts: [Layout]) {
        unregisterAll()
        conflicts = []

        for layout in layouts {
            guard let shortcut = layout.shortcut else { continue }
            if !register(shortcut, for: layout.id) {
                conflicts.append(layout.name)
            }
        }
    }

    /// Frees the shortcuts so the preferences recorder can capture a key
    /// combination that is currently registered.
    func suspend() {
        unregisterAll()
    }

    private func register(_ shortcut: KeyCombo, for layoutID: String) -> Bool {
        let id = nextID
        nextID += 1

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: HotKeyCenter.signature, id: id)
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            HotKeyCenter.carbonModifiers(shortcut.modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        guard status == noErr, let ref else { return false }
        registered[id] = (ref, layoutID)
        return true
    }

    private func unregisterAll() {
        for (_, entry) in registered { UnregisterEventHotKey(entry.ref) }
        registered.removeAll()
    }

    private func installHandler() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return OSStatus(eventNotHandledErr) }

                let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
                center.handle(hotKeyID.id)
                return noErr
            },
            1,
            &spec,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
    }

    private func handle(_ id: UInt32) {
        guard let entry = registered[id] else { return }
        onTrigger(entry.layoutID)
    }

    /// Four character code identifying Snap It's hot keys to Carbon.
    private static let signature = OSType(0x534E_5049) // "SNPI"

    private static func carbonModifiers(_ modifiers: KeyModifiers) -> UInt32 {
        var mask: UInt32 = 0
        if modifiers.contains(.command) { mask |= UInt32(cmdKey) }
        if modifiers.contains(.control) { mask |= UInt32(controlKey) }
        if modifiers.contains(.option) { mask |= UInt32(optionKey) }
        if modifiers.contains(.shift) { mask |= UInt32(shiftKey) }
        return mask
    }
}
