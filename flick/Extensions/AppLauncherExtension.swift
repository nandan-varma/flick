import AppKit

@MainActor final class AppLauncherExtension: FlickExtension {
    let id = "app-launcher"
    let name = "App Launcher"
    var searchPriority: Double { 10 }
    var maxSearchResults: Int { 6 }

    private var commands: [AppLaunchCommand] = []
    private let frecencyStore: FrecencyStore

    init(frecencyStore: FrecencyStore) {
        self.frecencyStore = frecencyStore
    }

    func setApps(_ apps: [AppEntry]) {
        commands = apps.map { AppLaunchCommand(entry: $0, frecencyStore: frecencyStore) }
    }

    func homeCommands() -> [any FlickCommand] {
        commands
            .sorted { frecencyStore.score(for: $0.bundleID) > frecencyStore.score(for: $1.bundleID) }
            .prefix(5)
            .map { $0 }
    }

    func search(query: String) -> [(command: any FlickCommand, score: Double)] {
        commands.compactMap { cmd in
            let fuzzy = FuzzyMatcher.score(query: query, against: cmd.title)
            guard fuzzy > 0 else { return nil }
            let frec = frecencyStore.score(for: cmd.bundleID)
            return (cmd, fuzzy * (1 + frec))
        }
    }
}

// MARK: - Command

@MainActor final class AppLaunchCommand: FlickCommand {
    let id: String
    let title: String
    let subtitle: String? = nil
    let icon: NSImage?
    let keywords: [String]
    let category = "Application"
    let actionLabel = "Launch Application"
    let sectionTitle = "Suggested"
    let bundleID: String
    let appPath: URL

    private let frecencyStore: FrecencyStore

    init(entry: AppEntry, frecencyStore: FrecencyStore) {
        self.id = "app-\(entry.id)"
        self.title = entry.name
        self.bundleID = entry.bundleID
        self.appPath = entry.path
        self.keywords = [entry.name.lowercased()]
        self.icon = NSWorkspace.shared.icon(forFile: entry.path.path)
        self.frecencyStore = frecencyStore
    }

    func run() {
        frecencyStore.record(bundleID: bundleID)
        NSWorkspace.shared.openApplication(at: appPath, configuration: .init())
    }
}
