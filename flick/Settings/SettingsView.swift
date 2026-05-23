import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gear") }
            HotkeySettingsView()
                .tabItem { Label("Hotkey", systemImage: "keyboard") }
            SnippetsSettingsView()
                .tabItem { Label("Snippets", systemImage: "text.quote") }
            QuicklinksSettingsView()
                .tabItem { Label("Quicklinks", systemImage: "link") }
            WindowHotkeySettingsView()
                .tabItem { Label("Windows", systemImage: "rectangle.split.2x1") }
        }
        .frame(minWidth: 500, minHeight: 350)
    }
}
