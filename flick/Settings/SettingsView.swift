import SwiftUI

struct SettingsView: View {
    let snippetManager: SnippetManager
    let quicklinkManager: QuicklinkManager

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gear") }
            HotkeySettingsView()
                .tabItem { Label("Hotkey", systemImage: "keyboard") }
            SnippetsSettingsView(snippetManager: snippetManager)
                .tabItem { Label("Snippets", systemImage: "text.quote") }
            QuicklinksSettingsView(quicklinkManager: quicklinkManager)
                .tabItem { Label("Quicklinks", systemImage: "link") }
            WindowHotkeySettingsView()
                .tabItem { Label("Windows", systemImage: "rectangle.split.2x1") }
        }
        .frame(minWidth: 500, minHeight: 350)
    }
}
