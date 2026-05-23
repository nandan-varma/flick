import AppKit
import Observation

@Observable @MainActor final class AppViewModel {
    var query: String = "" {
        didSet { if query != oldValue { search() } }
    }
    var results: [any FlickCommand] = []
    var selectedIndex: Int = 0
    var calculatorResult: String? = nil
    var isHomeScreen: Bool = true

    var registry: CommandRegistry?

    func search() {
        let q = query.trimmingCharacters(in: .whitespaces)

        guard !q.isEmpty else {
            calculatorResult = nil
            loadHomeScreen()
            return
        }

        // Calculator: evaluated before extensions so math is always surfaced first.
        if CalculatorEngine.isExpression(q), let value = CalculatorEngine.evaluate(q) {
            calculatorResult = value
            isHomeScreen = false
            results = []
            selectedIndex = 0
            return
        }
        calculatorResult = nil

        let found = registry?.search(query: q) ?? []
        if found.isEmpty {
            loadHomeScreen()
        } else {
            results = found
            isHomeScreen = false
            selectedIndex = 0
        }
    }

    private func loadHomeScreen() {
        results = registry?.homeCommands() ?? []
        isHomeScreen = true
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
        results[selectedIndex].run()
    }

    func moveUp() { selectedIndex = max(0, selectedIndex - 1) }

    func moveDown() {
        guard !results.isEmpty else { return }
        selectedIndex = min(results.count - 1, selectedIndex + 1)
    }
}
