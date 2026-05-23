import AppKit

@MainActor final class SnippetExtension: FlickExtension {
    let id = "snippets"
    let name = "Snippets"
    var searchPriority: Double { 2 }
    var maxSearchResults: Int { 4 }

    let manager: SnippetManager

    init(manager: SnippetManager) {
        self.manager = manager
    }

    func homeCommands() -> [any FlickCommand] { [] }

    func search(query: String) -> [(command: any FlickCommand, score: Double)] {
        // "snip:" prefix → show all snippets, fuzzy on the remainder
        let effectiveQuery: String
        let snipMode = query.hasPrefix("snip:")
        if snipMode {
            effectiveQuery = String(query.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        } else {
            effectiveQuery = query
        }

        if effectiveQuery.isEmpty && snipMode {
            return manager.snippets.map { (SnippetExpandCommand(snippet: $0, manager: manager), 1.0) }
        }

        return manager.snippets.compactMap { snippet in
            let s = FuzzyMatcher.bestScore(query: effectiveQuery, title: snippet.name, keywords: [snippet.keyword])
            guard s > 0 else { return nil }
            return (SnippetExpandCommand(snippet: snippet, manager: manager), s)
        }
    }
}

// MARK: - Command

@MainActor final class SnippetExpandCommand: FlickCommand {
    let id: String
    let title: String
    let subtitle: String?
    let icon: NSImage? = NSImage(systemSymbolName: "text.quote", accessibilityDescription: nil)
    let keywords: [String]
    let category = "Snippet"
    let actionLabel = "Expand Snippet"
    let sectionTitle = "Snippets"

    private let snippet: Snippet
    private let manager: SnippetManager

    init(snippet: Snippet, manager: SnippetManager) {
        self.id = "snippet-\(snippet.id)"
        self.title = snippet.name
        self.subtitle = snippet.keyword
        self.keywords = [snippet.name, snippet.keyword]
        self.snippet = snippet
        self.manager = manager
    }

    func run() { manager.paste(snippet: snippet) }
}
