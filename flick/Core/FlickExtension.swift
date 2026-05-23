import AppKit

/// A container that groups related FlickCommands and surfaces them to the registry.
/// Add new capabilities to flick by implementing this protocol and registering
/// the extension in AppDelegate.
protocol FlickExtension: AnyObject {
    var id: String { get }
    var name: String { get }

    /// Additive score boost applied to all results from this extension.
    /// Higher values surface this extension's commands above others when scores are close.
    var searchPriority: Double { get }

    /// Maximum results this extension may contribute to a single search pass.
    var maxSearchResults: Int { get }

    /// Commands shown on the home screen (empty query).
    func homeCommands() -> [any FlickCommand]

    /// Fuzzy search results with raw scores (priority boost applied by the registry).
    func search(query: String) -> [(command: any FlickCommand, score: Double)]

    /// Short-circuit search with an exact keyword dispatch (e.g. "g hello" → Google quicklink).
    /// Return non-nil to make the registry skip all other extensions for this query.
    func keywordDispatch(query: String) -> (any FlickCommand)?
}

// MARK: - Default implementations

extension FlickExtension {
    var searchPriority: Double { 0 }
    var maxSearchResults: Int { 6 }

    func keywordDispatch(query: String) -> (any FlickCommand)? { nil }

    /// Default search: fuzzy match all home-screen commands against query.
    func search(query: String) -> [(command: any FlickCommand, score: Double)] {
        homeCommands().compactMap { cmd in
            let s = FuzzyMatcher.bestScore(query: query, title: cmd.title, keywords: cmd.keywords)
            guard s > 0 else { return nil }
            return (cmd, s)
        }
    }
}
