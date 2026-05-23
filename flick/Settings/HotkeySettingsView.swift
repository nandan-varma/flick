import SwiftUI
import AppKit

@MainActor
struct HotkeySettingsView: View {
    @State private var isRecording = false
    @State private var eventMonitor: Any?
    @AppStorage("flick.hotkey.keyCode") var keyCode: Int = 49
    @AppStorage("flick.hotkey.modifiers") var modifiers: Int = Int(NSEvent.ModifierFlags.option.rawValue)

    var body: some View {
        Form {
            Section("Global Hotkey") {
                HStack {
                    Text("Current:")
                    Text(hotkeyDescription(keyCode: keyCode, modifiers: modifiers))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.15))
                        .cornerRadius(6)
                        .fontDesign(.monospaced)
                }

                if isRecording {
                    HStack {
                        Text("Press any key combination…")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Cancel") {
                            stopRecording()
                        }
                    }
                } else {
                    Button("Record Hotkey") {
                        startRecording()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        stopRecording()
        isRecording = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            self.keyCode = Int(event.keyCode)
            self.modifiers = Int(event.modifierFlags.intersection([.command, .option, .shift, .control]).rawValue)
            self.stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

private let keyCodeNames: [Int: String] = [
    49: "Space", 36: "Return", 51: "Delete", 53: "Esc", 48: "Tab"
]

func hotkeyDescription(keyCode: Int, modifiers: Int) -> String {
    var desc = ""
    let flags = NSEvent.ModifierFlags(rawValue: UInt(modifiers))
    if flags.contains(.control) { desc += "⌃" }
    if flags.contains(.option) { desc += "⌥" }
    if flags.contains(.shift) { desc += "⇧" }
    if flags.contains(.command) { desc += "⌘" }
    desc += keyCodeNames[keyCode] ?? "Key\(keyCode)"
    return desc
}
