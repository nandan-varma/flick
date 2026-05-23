import AppKit

@MainActor final class CommandRegistry {
    private(set) var extensions: [any FlickExtension] = []

    func register(_ ext: any FlickExtension) {
        extensions.append(ext)
    }

    /// Commands for the home screen, grouped by extension registration order.
    func homeCommands() -> [any FlickCommand] {
        extensions.flatMap { $0.homeCommands() }
    }

    /// Unified search across all extensions, sorted by composite score.
    func search(query: String) -> [any FlickCommand] {
        // Keyword dispatch: first match short-circuits everything else.
        for ext in extensions {
            if let cmd = ext.keywordDispatch(query: query) {
                return [cmd]
            }
        }

        // Collect (extensionID, maxResults, command, score) from every extension.
        var scored: [(extID: String, cap: Int, cmd: any FlickCommand, score: Double)] = []
        for ext in extensions {
            for (cmd, score) in ext.search(query: query) {
                scored.append((ext.id, ext.maxSearchResults, cmd, score + ext.searchPriority))
            }
        }
        scored.sort { $0.score > $1.score }

        // Apply per-extension result caps while preserving global score order.
        var countByExt: [String: Int] = [:]
        var output: [any FlickCommand] = []
        for entry in scored {
            let current = countByExt[entry.extID, default: 0]
            guard current < entry.cap else { continue }
            countByExt[entry.extID] = current + 1
            output.append(entry.cmd)
        }
        return output
    }
}
