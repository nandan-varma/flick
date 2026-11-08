import SwiftUI

@MainActor
struct ExtensionsSettingsView: View {
    let registry: CommandRegistry
    let extensionStore: ExtensionStore
    let commandStore: CommandStore

    var body: some View {
        List {
            ForEach(registry.extensions, id: \.id) { ext in
                ExtensionSection(ext: ext, extensionStore: extensionStore, commandStore: commandStore)
            }
        }
        .listStyle(.inset)
    }
}

// MARK: - Extension row (with optional disclosure for commands)

@MainActor
private struct ExtensionSection: View {
    let ext: any FlickExtension
    let extensionStore: ExtensionStore
    let commandStore: CommandStore
    @State private var expanded = false

    private var commands: [any FlickCommand] { ext.settingsCommands() }

    var body: some View {
        if commands.isEmpty {
            ExtensionHeaderRow(ext: ext, store: extensionStore)
        } else {
            DisclosureGroup(isExpanded: $expanded) {
                ForEach(commands, id: \.id) { cmd in
                    CommandRow(cmd: cmd, commandStore: commandStore)
                        .padding(.leading, 8)
                }
            } label: {
                ExtensionHeaderRow(ext: ext, store: extensionStore)
            }
        }
    }
}

@MainActor
private struct ExtensionHeaderRow: View {
    let ext: any FlickExtension
    let store: ExtensionStore

    private var enabled: Bool { store.isEnabled(ext.id) }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: ext.icon)
                .frame(width: 22, height: 22)
                .foregroundStyle(enabled ? .primary : .tertiary)

            Text(ext.name)
                .foregroundStyle(enabled ? .primary : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("", isOn: Binding(
                get: { store.isEnabled(ext.id) },
                set: { store.setEnabled(ext.id, $0) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Command row

@MainActor
private struct CommandRow: View {
    let cmd: any FlickCommand
    let commandStore: CommandStore
    @State private var isRecording = false
    @State private var eventMonitor: Any?

    private var currentHotkey: CommandStore.Hotkey? { commandStore.hotkey(for: cmd.id) }
    private var isEnabled: Bool { commandStore.isEnabled(cmd.id) }

    var body: some View {
        HStack(spacing: 8) {
            Text(cmd.title)
                .foregroundStyle(isEnabled ? .primary : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            hotkeyControl

            Toggle("", isOn: Binding(
                get: { commandStore.isEnabled(cmd.id) },
                set: { commandStore.setEnabled(cmd.id, $0) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
        .padding(.vertical, 3)
        .onDisappear { stopRecording() }
    }

    @ViewBuilder
    private var hotkeyControl: some View {
        if isRecording {
            HStack(spacing: 6) {
                Text("Press keys…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Cancel") { stopRecording() }
                    .controlSize(.mini)
                    .buttonStyle(.bordered)
            }
        } else {
            HStack(spacing: 4) {
                Button(action: startRecording) {
                    if let h = currentHotkey {
                        Text(hotkeyDescription(keyCode: h.keyCode, modifiers: h.modifiers))
                            .fontDesign(.monospaced)
                            .font(.caption)
                    } else {
                        Text("Add Shortcut")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .controlSize(.small)
                .buttonStyle(.bordered)

                if currentHotkey != nil {
                    Button {
                        commandStore.setHotkey(nil, for: cmd.id)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Clear shortcut")
                }
            }
        }
    }

    private func startRecording() {
        stopRecording()
        isRecording = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Escape → cancel
                self.stopRecording()
            } else {
                let mods = event.modifierFlags
                    .intersection([.command, .option, .shift, .control])
                    .rawValue
                self.commandStore.setHotkey(
                    CommandStore.Hotkey(keyCode: Int(event.keyCode), modifiers: Int(mods)),
                    for: self.cmd.id
                )
                self.stopRecording()
            }
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let m = eventMonitor { NSEvent.removeMonitor(m); eventMonitor = nil }
    }
}
