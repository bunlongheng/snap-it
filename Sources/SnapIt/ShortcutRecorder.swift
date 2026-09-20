import AppKit
import SwiftUI

/// Captures one key combination.
///
/// While recording, Snap It's own global shortcuts are released so an already
/// registered combination can be re-recorded, and the key event is swallowed so
/// it never reaches the rest of the system.
struct ShortcutRecorder: View {
    @Binding var shortcut: KeyCombo?
    let accent: Color
    let onRecordingChanged: (Bool) -> Void

    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var hint: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Button(action: toggle) {
                    Text(label)
                        .frame(minWidth: 120)
                        .monospacedDigit()
                        .foregroundStyle(shortcut == nil ? Color.secondary : accent)
                }
                .buttonStyle(.bordered)
                .tint(isRecording ? Color.red : accent)
                .accessibilityLabel("Shortcut")
                .accessibilityValue(shortcut?.stringValue ?? "none")
                .accessibilityHint("Activates recording, then press the key combination you want.")

                Button("Clear") {
                    stop()
                    shortcut = nil
                }
                .disabled(shortcut == nil)
            }

            if let hint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onDisappear(perform: stop)
    }

    private var label: String {
        if isRecording { return "Press keys\u{2026}" }
        return shortcut?.displayValue ?? "Record shortcut"
    }

    private func toggle() {
        isRecording ? stop() : start()
    }

    private func start() {
        isRecording = true
        hint = "Esc cancels."
        onRecordingChanged(true)

        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            handle(event)
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if isRecording { onRecordingChanged(false) }
        isRecording = false
        hint = nil
    }

    private func handle(_ event: NSEvent) {
        if event.keyCode == 53 { // Escape
            stop()
            return
        }

        var modifiers: KeyModifiers = []
        if event.modifierFlags.contains(.command) { modifiers.insert(.command) }
        if event.modifierFlags.contains(.control) { modifiers.insert(.control) }
        if event.modifierFlags.contains(.option) { modifiers.insert(.option) }
        if event.modifierFlags.contains(.shift) { modifiers.insert(.shift) }

        guard modifiers.hasNonShiftModifier else {
            hint = "Add cmd, ctrl or alt so the shortcut cannot swallow normal typing."
            return
        }
        guard KeyCombo.keyNames[event.keyCode] != nil else {
            hint = "That key is not supported."
            return
        }

        shortcut = KeyCombo(keyCode: event.keyCode, modifiers: modifiers)
        stop()
    }
}
