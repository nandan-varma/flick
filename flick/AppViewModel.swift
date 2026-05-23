import AppKit
import Observation

@Observable @MainActor final class AppViewModel {
    var query: String = "" {
        didSet { if query != oldValue { search() } }
    }
    var results: [ResultItem] = []
    var selectedIndex: Int = 0
    var calculatorResult: String? = nil
    var cachedApps: [AppEntry] = []
    // True while showing the home screen (no active query) — used by WindowController
    // to decide whether to render section headers.
    var isHomeScreen: Bool = true

    var clipboardManager: ClipboardManager?
    var snippetManager: SnippetManager?
    var quicklinkManager: QuicklinkManager?
    var frecencyStore: FrecencyStore?
    var windowManager: WindowManager?

    func search() {
        let q = query.trimmingCharacters(in: .whitespaces)

        guard !q.isEmpty else {
            calculatorResult = nil
            showHomeScreen()
            return
        }

        // Inline calculator
        if CalculatorEngine.isExpression(q), let value = CalculatorEngine.evaluate(q) {
            calculatorResult = value
            isHomeScreen = false
            results = []
            selectedIndex = 0
            return
        }
        calculatorResult = nil

        // Clipboard-only mode: "clip …"
        if q.lowercased().hasPrefix("clip") {
            let term = String(q.dropFirst(4)).trimmingCharacters(in: .whitespaces)
            let entries = clipboardManager?.entries ?? []
            if term.isEmpty {
                results = Array(entries.prefix(8).map { .clip($0) })
            } else {
                results = entries
                    .filter { FuzzyMatcher.score(query: term, against: $0.text) > 0 }
                    .prefix(8)
                    .map { .clip($0) }
            }
            isHomeScreen = false
            selectedIndex = 0
            return
        }

        // Snippet-only mode: "snip: …"
        if q.hasPrefix("snip:") {
            results = (snippetManager?.matching(query: q) ?? []).map { .snippet($0) }
            isHomeScreen = false
            selectedIndex = 0
            return
        }

        // Quicklink keyword-prefix dispatch: "g hello world" → Google search
        if let (link, remainder) = quicklinkManager?.match(query: q), !remainder.isEmpty {
            results = [.quicklink(link, query: remainder)]
            isHomeScreen = false
            selectedIndex = 0
            return
        }

        // Unified fuzzy search
        let found = unifiedSearch(query: q)
        if found.isEmpty {
            showHomeScreen()
        } else {
            results = found
            isHomeScreen = false
            selectedIndex = 0
        }
    }

    // MARK: - Home screen

    private func showHomeScreen() {
        let store = frecencyStore
        let sorted = cachedApps
            .map { ($0, store?.score(for: $0.bundleID) ?? 0.0) }
            .sorted { $0.1 > $1.1 }

        let topApps = sorted.prefix(5).map { ResultItem.app($0.0) }
        let recentClips = (clipboardManager?.entries ?? []).prefix(3).map { ResultItem.clip($0) }
        let links = (quicklinkManager?.quicklinks ?? []).map { ResultItem.quicklink($0, query: "") }

        results = Array(topApps) + Array(recentClips) + links
        isHomeScreen = true
        selectedIndex = 0
    }

    // MARK: - Unified fuzzy search

    private func unifiedSearch(query q: String) -> [ResultItem] {
        var scored: [(item: ResultItem, score: Double)] = []

        // Apps — highest base priority
        let store = frecencyStore
        for entry in cachedApps {
            let fuzzy = FuzzyMatcher.score(query: q, against: entry.name)
            guard fuzzy > 0 else { continue }
            let frec = store?.score(for: entry.bundleID) ?? 0
            scored.append((.app(entry), fuzzy * (1 + frec) + 10))
        }

        // System commands
        for cmd in SystemCommandRegistry.all {
            let s = bestScore(query: q, name: cmd.name, keywords: cmd.keywords)
            guard s > 0 else { continue }
            scored.append((.command(cmd), s + 5))
        }

        // Window actions
        for action in WindowAction.allCases {
            let s = bestScore(query: q, name: action.name, keywords: action.keywords)
            guard s > 0 else { continue }
            scored.append((.windowAction(action), s + 4))
        }

        // Quicklinks — shows them with empty query so Enter just opens the base URL
        for link in (quicklinkManager?.quicklinks ?? []) {
            let s = bestScore(query: q, name: link.name, keywords: [link.keyword])
            guard s > 0 else { continue }
            scored.append((.quicklink(link, query: ""), s + 3))
        }

        // Snippets
        for snippet in (snippetManager?.snippets ?? []) {
            let s = bestScore(query: q, name: snippet.name, keywords: [snippet.keyword])
            guard s > 0 else { continue }
            scored.append((.snippet(snippet), s + 2))
        }

        scored.sort { $0.score > $1.score }

        // Cap per-category totals while preserving score order
        var appCount = 0, cmdCount = 0, windowCount = 0, linkCount = 0, snippetCount = 0
        var output: [ResultItem] = []
        for entry in scored {
            switch entry.item {
            case .app:
                guard appCount < 6 else { continue }
                appCount += 1
            case .command:
                guard cmdCount < 4 else { continue }
                cmdCount += 1
            case .windowAction:
                guard windowCount < 4 else { continue }
                windowCount += 1
            case .quicklink:
                guard linkCount < 4 else { continue }
                linkCount += 1
            case .snippet:
                guard snippetCount < 4 else { continue }
                snippetCount += 1
            case .clip:
                continue
            }
            output.append(entry.item)
        }
        return output
    }

    private func bestScore(query: String, name: String, keywords: [String]) -> Double {
        let nameScore = FuzzyMatcher.score(query: query, against: name)
        let kwScore = keywords.map { FuzzyMatcher.score(query: query, against: $0) }.max() ?? 0
        return max(nameScore, kwScore)
    }

    // MARK: - Actions

    func runSelected() {
        if let value = calculatorResult {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(value, forType: .string)
            calculatorResult = nil
            return
        }
        guard results.indices.contains(selectedIndex) else { return }
        execute(results[selectedIndex])
    }

    func execute(_ item: ResultItem) {
        switch item {
        case .app(let entry):
            frecencyStore?.record(bundleID: entry.bundleID)
            NSWorkspace.shared.openApplication(at: entry.path, configuration: .init())
        case .clip(let entry):
            clipboardManager?.paste(entry: entry)
        case .snippet(let snippet):
            snippetManager?.paste(snippet: snippet)
        case .quicklink(let link, let queryStr):
            quicklinkManager?.open(quicklink: link, query: queryStr)
        case .command(let cmd):
            cmd.run()
        case .windowAction(let action):
            windowManager?.apply(action)
        }
    }

    func moveUp() {
        selectedIndex = max(0, selectedIndex - 1)
    }

    func moveDown() {
        guard !results.isEmpty else { return }
        selectedIndex = min(results.count - 1, selectedIndex + 1)
    }
}
