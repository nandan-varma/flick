import AppKit
import CoreWLAN
import Foundation

@MainActor final class SystemExtension: FlickExtension {
    let id = "system"
    let name = "System Commands"
    var searchPriority: Double { 5 }
    var maxSearchResults: Int { 4 }

    private let commands: [any FlickCommand]

    init() {
        commands = [
            SleepCommand(),
            LockScreenCommand(),
            RestartCommand(),
            ShutdownCommand(),
            EmptyTrashCommand(),
            ToggleDarkModeCommand(),
            ToggleWiFiCommand(),
            ScreenshotCommand(),
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

// MARK: - Shared helpers

@discardableResult
private func runAppleScript(_ source: String) -> String? {
    let script = NSAppleScript(source: source)
    var error: NSDictionary?
    let result = script?.executeAndReturnError(&error)
    return result?.stringValue
}

// MARK: - Command implementations

private final class SleepCommand: FlickCommand {
    let id = "sys-sleep"
    let title = "Sleep"
    let subtitle: String? = nil
    let icon: NSImage? = NSImage(systemSymbolName: "moon.fill", accessibilityDescription: nil)
    let keywords = ["sleep", "sleep computer"]
    let category = "Command"
    let actionLabel = "Run Command"
    let sectionTitle = "System Commands"
    func run() { runAppleScript("tell application \"System Events\" to sleep") }
}

private final class LockScreenCommand: FlickCommand {
    let id = "sys-lock"
    let title = "Lock Screen"
    let subtitle: String? = nil
    let icon: NSImage? = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil)
    let keywords = ["lock", "lock screen"]
    let category = "Command"
    let actionLabel = "Run Command"
    let sectionTitle = "System Commands"
    func run() { runAppleScript("tell application \"System Events\" to keystroke \"q\" using {control down, command down}") }
}

private final class RestartCommand: FlickCommand {
    let id = "sys-restart"
    let title = "Restart"
    let subtitle: String? = nil
    let icon: NSImage? = NSImage(systemSymbolName: "arrow.clockwise.circle.fill", accessibilityDescription: nil)
    let keywords = ["restart", "reboot"]
    let category = "Command"
    let actionLabel = "Run Command"
    let sectionTitle = "System Commands"
    func run() { runAppleScript("tell application \"Finder\" to restart") }
}

private final class ShutdownCommand: FlickCommand {
    let id = "sys-shutdown"
    let title = "Shut Down"
    let subtitle: String? = nil
    let icon: NSImage? = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
    let keywords = ["shutdown", "shut down", "power off"]
    let category = "Command"
    let actionLabel = "Run Command"
    let sectionTitle = "System Commands"
    func run() { runAppleScript("tell application \"Finder\" to shut down") }
}

private final class EmptyTrashCommand: FlickCommand {
    let id = "sys-trash"
    let title = "Empty Trash"
    let subtitle: String? = nil
    let icon: NSImage? = NSImage(systemSymbolName: "trash.fill", accessibilityDescription: nil)
    let keywords = ["empty trash", "trash"]
    let category = "Command"
    let actionLabel = "Run Command"
    let sectionTitle = "System Commands"
    func run() { runAppleScript("tell application \"Finder\" to empty trash") }
}

private final class ToggleDarkModeCommand: FlickCommand {
    let id = "sys-darkmode"
    let title = "Toggle Dark Mode"
    let subtitle: String? = nil
    let icon: NSImage? = NSImage(systemSymbolName: "circle.lefthalf.filled", accessibilityDescription: nil)
    let keywords = ["dark mode", "light mode", "toggle dark mode"]
    let category = "Command"
    let actionLabel = "Run Command"
    let sectionTitle = "System Commands"
    func run() {
        runAppleScript("tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode")
    }
}

private final class ToggleWiFiCommand: FlickCommand {
    let id = "sys-wifi"
    let title = "Toggle Wi-Fi"
    let subtitle: String? = nil
    let icon: NSImage? = NSImage(systemSymbolName: "wifi", accessibilityDescription: nil)
    let keywords = ["wifi", "wi-fi", "toggle wifi"]
    let category = "Command"
    let actionLabel = "Run Command"
    let sectionTitle = "System Commands"
    func run() {
        guard let iface = CWWiFiClient.shared().interface() else { return }
        try? iface.setPower(!iface.powerOn())
    }
}

private final class ScreenshotCommand: FlickCommand {
    let id = "sys-screenshot"
    let title = "Screenshot"
    let subtitle: String? = nil
    let icon: NSImage? = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: nil)
    let keywords = ["screenshot", "capture screen", "screen capture"]
    let category = "Command"
    let actionLabel = "Run Command"
    let sectionTitle = "System Commands"
    func run() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-i", "-c"]
        try? task.run()
    }
}
