import SwiftUI

struct PreferencesView: View {
    @ObservedObject var model: PreferencesModel

    @State private var confirmingDelete = false

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 320)
        } detail: {
            detail
        }
        .frame(minWidth: 680, minHeight: 480)
        .tint(model.hue(for: model.selection))
        .toolbar {
            ToolbarItemGroup {
                Button(action: model.addLayout) {
                    Image(systemName: "plus")
                }
                .help("Add a layout")
                .accessibilityLabel("Add layout")

                Button(action: { confirmingDelete = true }) {
                    Image(systemName: "minus")
                }
                .disabled(model.selection == nil)
                .help("Remove the selected layout")
                .accessibilityLabel("Remove layout")
                .confirmationDialog(
                    "Delete \(model.selectedLayout?.name ?? "this layout")?",
                    isPresented: $confirmingDelete
                ) {
                    Button("Delete", role: .destructive, action: model.removeSelected)
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Its shortcut is freed. This cannot be undone.")
                }

                Button("Restore Defaults", action: model.restoreDefaults)
                    .help("Replace every layout with the shipped set")
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        .onAppear { model.startWatching() }
        .onDisappear { model.stopWatching() }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $model.selection) {
            ForEach(Array(model.config.layouts.enumerated()), id: \.element.id) { index, layout in
                let hue = Palette.hue(for: index)
                HStack(spacing: 9) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(hue)
                        .frame(width: model.selection == layout.id ? 5 : 10,
                               height: model.selection == layout.id ? 22 : 10)
                        .shadow(color: hue.opacity(0.8), radius: 4)
                    Text(layout.name)
                    Spacer(minLength: 8)
                    Text(layout.shortcut?.displayValue ?? "\u{2014}")
                        .foregroundStyle(hue)
                }
                .padding(.vertical, 1)
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(hue.opacity(model.selection == layout.id ? 0.28 : 0.07))
                        .padding(.horizontal, 6)
                )
                .tag(layout.id)
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        if let id = model.selection, let layout = model.binding(for: id) {
            LayoutEditor(layout: layout, model: model, accent: model.hue(for: id))
                .id(id)
        } else if model.config.layouts.isEmpty {
            placeholder(
                symbol: "tray",
                title: "No layouts left",
                message: "Add one with the plus button, or bring the defaults back."
            )
        } else {
            placeholder(
                symbol: "rectangle.dashed",
                title: "No layout selected",
                message: "Pick a layout on the left, or add one."
            )
        }
    }

    private func placeholder(symbol: String, title: String, message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 34))
                .foregroundStyle(.tertiary)
            Text(title).font(.title3)
            Text(message).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: Palette.spectrum, startPoint: .leading, endPoint: .trailing)
                .frame(height: 2)

            if let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
            }

            if !model.shortcutConflicts.isEmpty {
                Label(
                    "Already in use by another app: \(model.shortcutConflicts.joined(separator: ", "))",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.callout)
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }

            if !model.isTrusted {
                HStack(spacing: 8) {
                    Label(
                        "Snap It cannot move windows until you allow Accessibility access.",
                        systemImage: "lock.fill"
                    )
                    .font(.callout)
                    Spacer()
                    Button("Open Settings", action: model.requestAccessibility)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }

            HStack(spacing: 16) {
                Toggle("Launch at login", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: model.setLaunchAtLogin
                ))
                .toggleStyle(.checkbox)

                Spacer()

                Button("Reveal Config") {
                    NSWorkspace.shared.activateFileViewerSelecting([ConfigStore.defaultURL()])
                }
                .help(model.configPath)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.bar)
    }
}

/// Editor for one saved layout.
private struct LayoutEditor: View {
    @Binding var layout: Layout
    @ObservedObject var model: PreferencesModel
    let accent: Color

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(accent)
                        .frame(width: 14, height: 14)
                        .shadow(color: accent.opacity(0.8), radius: 5)
                    TextField("Name", text: $layout.name)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                }

                GridPicker(frame: $layout.frame, grid: model.config.grid, accent: accent)

                HStack(spacing: 6) {
                    Text("Shortcut")
                        .foregroundStyle(.secondary)
                        .fixedSize()
                    ShortcutRecorder(shortcut: $layout.shortcut, accent: accent) { recording in
                        recording ? model.suspendShortcuts() : model.resumeShortcuts()
                    }
                }

                Button("Apply to focused window", action: model.applySelectedToFocusedWindow)
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                    .help("Moves whichever window was focused before the settings window opened.")
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
