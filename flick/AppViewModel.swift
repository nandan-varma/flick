import AppKit
import FoundationModels
import Observation

enum LauncherMode { case search, chat }

@Observable @MainActor final class AppViewModel {
    var query: String = "" {
        didSet { if query != oldValue { search() } }
    }
    var results: [any FlickCommand] = []
    var selectedIndex: Int = 0
    var calculatorResult: String? = nil
    var isHomeScreen: Bool = true
    var mode: LauncherMode = .search
    var chatViewModel: ChatViewModel?

    // Inline AI (auto-generated when query has "ai " prefix)
    var inlineAIResponse: String? = nil
    var inlineAIStreaming: Bool = false
    private var aiGenerationTask: Task<Void, Never>? = nil

    var registry: CommandRegistry?

    func enterChatMode(initialPrompt: String = "") {
        cancelInlineAI()
        chatViewModel?.reset()
        mode = .chat
        if !initialPrompt.isEmpty {
            Task { await chatViewModel?.send(initialPrompt) }
        }
    }

    func exitChatMode() {
        mode = .search
    }

    func search() {
        guard mode == .search else { return }

        let q = query.trimmingCharacters(in: .whitespaces)

        guard !q.isEmpty else {
            cancelInlineAI()
            calculatorResult = nil
            loadHomeScreen()
            return
        }

        // Inline AI: auto-generate when query starts with "ai "
        let lower = q.lowercased()
        if lower.hasPrefix("ai ") {
            let prompt = String(q.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            if !prompt.isEmpty {
                startInlineAI(prompt: prompt)
            }
        } else {
            cancelInlineAI()
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

    // MARK: - Inline AI

    private func startInlineAI(prompt: String) {
        aiGenerationTask?.cancel()
        inlineAIResponse = nil
        inlineAIStreaming = false

        aiGenerationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            // Debounce: wait 1s before firing so rapid keystrokes don't each trigger generation
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }

            self.inlineAIStreaming = true

            guard let session = try? AIService.shared.makeSession(
                instructions: "Answer concisely in plain text. No markdown headers or bullet points unless essential."
            ) else {
                self.inlineAIStreaming = false
                self.inlineAIResponse = "Apple Intelligence is not available."
                return
            }

            do {
                let stream = session.streamResponse(to: prompt)
                for try await partial in stream {
                    guard !Task.isCancelled else { return }
                    self.inlineAIResponse = partial.content
                }
            } catch {
                guard !Task.isCancelled else { return }
                self.inlineAIResponse = self.inlineAIResponse ?? "Error: \(error.localizedDescription)"
            }
            if !Task.isCancelled {
                self.inlineAIStreaming = false
            }
        }
    }

    func cancelInlineAI() {
        aiGenerationTask?.cancel()
        aiGenerationTask = nil
        inlineAIResponse = nil
        inlineAIStreaming = false
    }

    func copyInlineAIResponse() {
        guard let text = inlineAIResponse else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    // MARK: - Selection

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
