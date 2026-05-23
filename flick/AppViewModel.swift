import AppKit
import Observation

@Observable @MainActor final class AppViewModel {
    var query: String = "" {
        didSet { if query != oldValue { search() } }
    }
    var results: [ResultItem] = []
    var selectedIndex: Int = 0

    weak var appScanner: AppScanner?
    weak var clipboardManager: ClipboardManager?
    weak var snippetManager: SnippetManager?
    weak var quicklinkManager: QuicklinkManager?
    weak var frecencyStore: FrecencyStore?
    weak var windowManager: WindowManager?

    func search() {
        guard !query.isEmpty else { results = []; selectedIndex = 0; return }
        results = []
        selectedIndex = 0
    }

    func runSelected() {
        guard results.indices.contains(selectedIndex) else { return }
        results[selectedIndex].run()
    }

    func moveUp() {
        selectedIndex = max(0, selectedIndex - 1)
    }

    func moveDown() {
        guard !results.isEmpty else { return }
        selectedIndex = min(results.count - 1, selectedIndex + 1)
    }
}
