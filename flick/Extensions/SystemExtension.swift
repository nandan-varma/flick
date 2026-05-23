import AppKit
import CoreWLAN

@MainActor final class SystemExtension: FlickExtension {
    let id = "system"
    let name = "System Commands"
    var searchPriority: Double { 5 }
    var maxSearchResults: Int { 4 }

    private let commands: [any FlickCommand]

    init() {
        commands = [
            SystemCommand(
                id: "sys-sleep", title: "Sleep",
                systemImage: "moon.fill",
                keywords: ["sleep", "sleep computer"]
            ) {
                runAppleScript("tell application \"System Events\" to sleep")
            },
            SystemCommand(
                id: "sys-lock", title: "Lock Screen",
                systemImage: "lock.fill",
                keywords: ["lock", "lock screen"]
            ) {
                runAppleScript(#"tell application "System Events" to keystroke "q" using {control down, command down}"#)
            },
            SystemCommand(
                id: "sys-restart", title: "Restart",
                systemImage: "arrow.clockwise.circle.fill",
                keywords: ["restart", "reboot"]
            ) {
                runAppleScript("tell application \"Finder\" to restart")
            },
            SystemCommand(
                id: "sys-shutdown", title: "Shut Down",
                systemImage: "power",
                keywords: ["shutdown", "shut down", "power off"]
            ) {
                runAppleScript("tell application \"Finder\" to shut down")
            },
            SystemCommand(
                id: "sys-trash", title: "Empty Trash",
                systemImage: "trash.fill",
                keywords: ["empty trash", "trash"]
            ) {
                runAppleScript("tell application \"Finder\" to empty trash")
            },
            SystemCommand(
                id: "sys-darkmode", title: "Toggle Dark Mode",
                systemImage: "circle.lefthalf.filled",
                keywords: ["dark mode", "light mode", "toggle dark mode"]
            ) {
                runAppleScript("tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode")
            },
            SystemCommand(
                id: "sys-wifi", title: "Toggle Wi-Fi",
                systemImage: "wifi",
                keywords: ["wifi", "wi-fi", "toggle wifi"]
            ) {
                guard let iface = CWWiFiClient.shared().interface() else { return }
                try? iface.setPower(!iface.powerOn())
            },
            SystemCommand(
                id: "sys-screenshot", title: "Screenshot",
                systemImage: "camera.viewfinder",
                keywords: ["screenshot", "capture screen", "screen capture"]
            ) {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                task.arguments = ["-i", "-c"]
                try? task.run()
            },
        ]
    }

    func homeCommands() -> [any FlickCommand] { [] }

    func search(query: String) -> [(command: any FlickCommand, score: Double)] {
        commands.compactMap { cmd in
            let s = FuzzyMatcher.bestScore(query: query, title: cmd.title, keywords: cmd.keywords)
            guard s > 0 else { return nil }
            return (cmd, s)
        }
    }
}

// MARK: - Shared helper

@discardableResult
private func runAppleScript(_ source: String) -> String? {
    var error: NSDictionary?
    return NSAppleScript(source: source)?.executeAndReturnError(&error).stringValue
}

// MARK: - Command

private final class SystemCommand: FlickCommand {
    let id: String
    let title: String
    let icon: NSImage?
    let keywords: [String]
    let category = "Command"
    let actionLabel = "Run Command"
    let sectionTitle = "System Commands"

    private let action: () -> Void

    init(id: String, title: String, systemImage: String, keywords: [String], action: @escaping () -> Void) {
        self.id = id
        self.title = title
        self.icon = NSImage(systemSymbolName: systemImage, accessibilityDescription: nil)
        self.keywords = keywords
        self.action = action
    }

    func run() { action() }
}
