import AppKit

@MainActor final class WindowExtension: FlickExtension {
    let id = "window"
    let name = "Window Management"
    var searchPriority: Double { 4 }
    var maxSearchResults: Int { 4 }

    private let commands: [WindowActionCommand]

    init(manager: WindowManager) {
        commands = WindowAction.allCases.map { WindowActionCommand(action: $0, manager: manager) }
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

// MARK: - Command

@MainActor final class WindowActionCommand: FlickCommand {
    let id: String
    let title: String
    let subtitle: String? = nil
    let icon: NSImage? = NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: nil)
    let keywords: [String]
    let category = "Window"
    let actionLabel = "Apply Layout"
    let sectionTitle = "Window Management"

    private let action: WindowAction
    private let manager: WindowManager

    init(action: WindowAction, manager: WindowManager) {
        self.id = "window-\(action.rawValue)"
        self.title = action.name
        self.keywords = action.keywords
        self.action = action
        self.manager = manager
    }

    func run() { manager.apply(action) }
}
