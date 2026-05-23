import SwiftUI
import ServiceManagement

@MainActor
struct GeneralSettingsView: View {
    @AppStorage("flick.maxClipboardEntries") var maxEntries: Int = 500
    @AppStorage("flick.appearance") var appearance: String = "auto"

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at Login", isOn: Binding(
                    get: { SMAppService.mainApp.status == .enabled },
                    set: { enabled in
                        try? enabled ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                    }
                ))

                Picker("Appearance", selection: $appearance) {
                    Text("Auto").tag("auto")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .onChange(of: appearance) { _, newValue in
                    switch newValue {
                    case "light": NSApp.appearance = NSAppearance(named: .aqua)
                    case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
                    default: NSApp.appearance = nil
                    }
                }
            }

            Section("Clipboard") {
                Stepper("Max Clipboard Entries: \(maxEntries)", value: $maxEntries, in: 50...1000, step: 50)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
