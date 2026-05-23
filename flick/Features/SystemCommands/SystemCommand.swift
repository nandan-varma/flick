import AppKit
import CoreWLAN
import Foundation

protocol SystemCommandProtocol: AnyObject, Sendable {
    var name: String { get }
    var keywords: [String] { get }
    func run()
}

@discardableResult
private func runAppleScript(_ source: String) -> String? {
    let script = NSAppleScript(source: source)
    var error: NSDictionary?
    let result = script?.executeAndReturnError(&error)
    return result?.stringValue
}

final class SleepCommand: SystemCommandProtocol, @unchecked Sendable {
    let name = "Sleep"
    let keywords = ["sleep", "sleep computer"]
    func run() { runAppleScript("tell application \"System Events\" to sleep") }
}

final class LockScreenCommand: SystemCommandProtocol, @unchecked Sendable {
    let name = "Lock Screen"
    let keywords = ["lock", "lock screen"]
    func run() { runAppleScript("tell application \"System Events\" to keystroke \"q\" using {control down, command down}") }
}

final class RestartCommand: SystemCommandProtocol, @unchecked Sendable {
    let name = "Restart"
    let keywords = ["restart", "reboot"]
    func run() { runAppleScript("tell application \"Finder\" to restart") }
}

final class ShutdownCommand: SystemCommandProtocol, @unchecked Sendable {
    let name = "Shut Down"
    let keywords = ["shutdown", "shut down", "power off"]
    func run() { runAppleScript("tell application \"Finder\" to shut down") }
}

final class EmptyTrashCommand: SystemCommandProtocol, @unchecked Sendable {
    let name = "Empty Trash"
    let keywords = ["empty trash", "trash"]
    func run() { runAppleScript("tell application \"Finder\" to empty trash") }
}

final class ToggleDarkModeCommand: SystemCommandProtocol, @unchecked Sendable {
    let name = "Toggle Dark Mode"
    let keywords = ["dark mode", "toggle dark mode", "light mode"]
    func run() { runAppleScript("tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode") }
}

final class ToggleWiFiCommand: SystemCommandProtocol, @unchecked Sendable {
    let name = "Toggle Wi-Fi"
    let keywords = ["wifi", "wi-fi", "toggle wifi"]
    func run() {
        guard let iface = CWWiFiClient.shared().interface() else { return }
        let currentPower = iface.powerOn()
        try? iface.setPower(!currentPower)
    }
}

final class ScreenshotCommand: SystemCommandProtocol, @unchecked Sendable {
    let name = "Screenshot"
    let keywords = ["screenshot", "capture screen", "screen capture"]
    func run() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-i", "-c"]
        try? task.run()
    }
}

enum SystemCommandRegistry {
    static let all: [any SystemCommandProtocol] = [
        SleepCommand(),
        LockScreenCommand(),
        RestartCommand(),
        ShutdownCommand(),
        EmptyTrashCommand(),
        ToggleDarkModeCommand(),
        ToggleWiFiCommand(),
        ScreenshotCommand(),
    ]

    static func matching(query: String) -> [any SystemCommandProtocol] {
        all.filter { cmd in
            cmd.keywords.contains { $0.localizedCaseInsensitiveContains(query) } ||
            cmd.name.localizedCaseInsensitiveContains(query)
        }
    }
}
