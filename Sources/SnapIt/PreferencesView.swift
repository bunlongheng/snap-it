import SwiftUI

struct PreferencesView: View {
    @ObservedObject var model: PreferencesModel

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 320)
        } detail: {
            detail
        }
        .frame(minWidth: 680, minHeight: 480)
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(model.config.layouts, selection: $model.selection) { layout in
                HStack {
                    Text(layout.name)
                    Spacer(minLength: 8)
                    Text(layout.shortcut?.displayValue ?? "\u{2014}")
                        .foregroundStyle(.secondary)
                }
                .tag(layout.id)
            }
            .listStyle(.sidebar)

            Divider()

            HStack(spacing: 2) {
                Button(action: model.addLayout) {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add layout")

                Button(action: model.removeSelected) {
                    Image(systemName: "minus")
                }
                .disabled(model.selection == nil)
                .accessibilityLabel("Remove layout")

                Spacer()

                Button("Restore Defaults", action: model.restoreDefaults)
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        if let id = model.selection, let layout = model.binding(for: id) {
            LayoutEditor(layout: layout, model: model)
                .id(id)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "rectangle.dashed")
                    .font(.system(size: 34))
                    .foregroundStyle(.tertiary)
                Text("No layout selected").font(.title3)
                Text("Pick a layout on the left, or add one.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()

            if let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
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
                HStack(spacing: 8) {
                    Text("Gap")
                    Slider(
                        value: Binding(
                            get: { model.config.gap },
                            set: { model.config.gap = $0.rounded(); model.commit() }
                        ),
                        in: 0 ... Placement.maximumGap
                    )
                    .frame(width: 140)
                    .accessibilityLabel("Gap between windows in points")
                    Text("\(Int(model.config.gap)) pt")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .leading)
                }

                HStack(spacing: 6) {
                    Text("Grid")
                    Stepper(
                        value: Binding(
                            get: { model.config.grid.columns },
                            set: { model.config.grid.columns = $0; model.commit() }
                        ),
                        in: GridSize.range
                    ) {
                        Text("\(model.config.grid.columns)").monospacedDigit()
                    }
                    .accessibilityLabel("Grid columns")

                    Text("by")
                    Stepper(
                        value: Binding(
                            get: { model.config.grid.rows },
                            set: { model.config.grid.rows = $0; model.commit() }
                        ),
                        in: GridSize.range
                    ) {
                        Text("\(model.config.grid.rows)").monospacedDigit()
                    }
                    .accessibilityLabel("Grid rows")
                }

                Toggle("Launch at login", isOn: Binding(
                    get: { LaunchAtLogin.isEnabled },
                    set: { _ = LaunchAtLogin.set($0) }
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                TextField("Name", text: $layout.name)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)

                GridPicker(frame: $layout.frame, grid: model.config.grid)

                LabeledContent("Shortcut") {
                    ShortcutRecorder(shortcut: $layout.shortcut) { recording in
                        recording ? model.suspendShortcuts() : model.resumeShortcuts()
                    }
                }

                percentages

                Button("Apply to focused window", action: model.applySelectedToFocusedWindow)
                    .help("Moves whichever window was focused before the settings window opened.")
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var percentages: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
            GridRow {
                percentField("Left", value: $layout.frame.x)
                percentField("Top", value: $layout.frame.y)
            }
            GridRow {
                percentField("Width", value: $layout.frame.width)
                percentField("Height", value: $layout.frame.height)
            }
        }
    }

    private func percentField(_ title: String, value: Binding<Double>) -> some View {
        LabeledContent(title) {
            HStack(spacing: 4) {
                TextField(
                    title,
                    value: Binding(
                        get: { (value.wrappedValue * 100).rounded() },
                        set: { value.wrappedValue = min(max($0, 0), 100) / 100 }
                    ),
                    format: .number.precision(.fractionLength(0))
                )
                .textFieldStyle(.roundedBorder)
                .frame(width: 70)
                Text("%").foregroundStyle(.secondary)
            }
        }
    }
}
