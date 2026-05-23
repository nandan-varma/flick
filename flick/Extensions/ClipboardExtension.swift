import AppKit

@MainActor final class ClipboardExtension: FlickExtension {
    let id = "clipboard"
    let name = "Clipboard History"
    var searchPriority: Double { 0 }
    // Non-zero so the registry's cap logic applies in clip-mode; 0 results returned
    // for queries that don't begin with "clip", so general search is unaffected.
    var maxSearchResults: Int { 8 }

    let manager: ClipboardManager

    init(manager: ClipboardManager) {
        self.manager = manager
    }

    func homeCommands() -> [any FlickCommand] {
        manager.entries.prefix(3).map { ClipPasteCommand(entry: $0, manager: manager) }
    }

    func search(query: String) -> [(command: any FlickCommand, score: Double)] {
        guard query.lowercased().hasPrefix("clip") else { return [] }
        let term = String(query.dropFirst(4)).trimmingCharacters(in: .whitespaces)
        if term.isEmpty {
            return manager.entries.prefix(8).map { (ClipPasteCommand(entry: $0, manager: manager), 1.0) }
        }
        return manager.entries.compactMap { entry in
            let s = FuzzyMatcher.score(query: term, against: entry.text)
            guard s > 0 else { return nil }
            return (ClipPasteCommand(entry: entry, manager: manager), s)
        }.prefix(8).map { $0 }
    }
}

// MARK: - Command

@MainActor final class ClipPasteCommand: FlickCommand {
    let id: String
    let title: String
    let subtitle: String?
    let icon: NSImage? = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: nil)
    let keywords: [String]
    let category = "Clipboard"
    let actionLabel = "Paste to Active App"
    let sectionTitle = "Recent"

    private let entry: ClipEntry
    private let manager: ClipboardManager

    init(entry: ClipEntry, manager: ClipboardManager) {
        self.id = "clip-\(entry.id)"
        self.title = entry.text
        self.keywords = []
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        self.subtitle = f.localizedString(for: entry.date, relativeTo: Date())
        self.entry = entry
        self.manager = manager
    }

    func run() { manager.paste(entry: entry) }
}
