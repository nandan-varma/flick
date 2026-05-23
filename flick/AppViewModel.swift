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

    var clipboardManager: ClipboardManager?
    var snippetManager: SnippetManager?
    var quicklinkManager: QuicklinkManager?
    var frecencyStore: FrecencyStore?
    var windowManager: WindowManager?

    func search() {
        guard !query.isEmpty else {
            results = []
            calculatorResult = nil
            selectedIndex = 0
            return
        }

        let q = query

        if CalculatorEngine.isExpression(q), let value = CalculatorEngine.evaluate(q) {
            calculatorResult = value
            results = []
            selectedIndex = 0
            return
        }
        calculatorResult = nil

        if q.lowercased().hasPrefix("clipboard") {
            results = (clipboardManager?.entries ?? []).map { .clip($0) }
            selectedIndex = 0
            return
        }

        if q.hasPrefix("snip:") {
            results = (snippetManager?.matching(query: q) ?? []).map { .snippet($0) }
            selectedIndex = 0
            return
        }

        if let (link, remainder) = quicklinkManager?.match(query: q) {
            results = [.quicklink(link, query: remainder)]
            selectedIndex = 0
            return
        }

        let frecency = frecencyStore
        let appResults: [ResultItem] = cachedApps
            .compactMap { entry -> (AppEntry, Double)? in
                let fuzzy = FuzzyMatcher.score(query: q, against: entry.name)
                guard fuzzy > 0 else { return nil }
                let frec = frecency?.score(for: entry.bundleID) ?? 0
                return (entry, fuzzy * (1.0 + frec))
            }
            .sorted { $0.1 > $1.1 }
            .prefix(6)
            .map { .app($0.0) }

        let windowResults: [ResultItem] = (windowManager?.matching(query: q) ?? []).map { .windowAction($0) }
        let cmdResults: [ResultItem] = SystemCommandRegistry.matching(query: q).map { .command($0) }

        results = appResults + windowResults + cmdResults
        selectedIndex = 0
    }

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
