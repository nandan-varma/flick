import AppKit

@MainActor final class QuicklinkExtension: FlickExtension {
    let id = "quicklinks"
    let name = "Quicklinks"
    var searchPriority: Double { 3 }
    var maxSearchResults: Int { 4 }

    let manager: QuicklinkManager

    init(manager: QuicklinkManager) {
        self.manager = manager
    }

    func homeCommands() -> [any FlickCommand] {
        manager.quicklinks.map { QuicklinkOpenCommand(link: $0, query: "", manager: manager) }
    }

    /// "g hello world" → opens Google with "hello world"; short-circuits all other search.
    func keywordDispatch(query: String) -> (any FlickCommand)? {
        guard let (link, remainder) = manager.match(query: query), !remainder.isEmpty else { return nil }
        return QuicklinkOpenCommand(link: link, query: remainder, manager: manager)
    }

    func search(query: String) -> [(command: any FlickCommand, score: Double)] {
        manager.quicklinks.compactMap { link in
            let s = FuzzyMatcher.bestScore(query: query, title: link.name, keywords: [link.keyword])
            guard s > 0 else { return nil }
            // Fuzzy match → open the base URL (no search term substitution)
            return (QuicklinkOpenCommand(link: link, query: "", manager: manager), s)
        }
    }
}

// MARK: - Command

@MainActor final class QuicklinkOpenCommand: FlickCommand {
    let id: String
    let title: String
    let subtitle: String?
    let icon: NSImage? = NSImage(systemSymbolName: "link", accessibilityDescription: nil)
    let keywords: [String]
    let category = "Quicklink"
    let actionLabel = "Open in Browser"
    let sectionTitle = "Quicklinks"

    private let link: Quicklink
    private let query: String
    private let manager: QuicklinkManager

    init(link: Quicklink, query: String, manager: QuicklinkManager) {
        self.id = "quicklink-\(link.id)-\(query)"
        self.title = query.isEmpty ? link.name : "\(link.name): \(query)"
        self.subtitle = link.keyword
        self.keywords = [link.name, link.keyword]
        self.link = link
        self.query = query
        self.manager = manager
    }

    func run() { manager.open(quicklink: link, query: query) }
}
