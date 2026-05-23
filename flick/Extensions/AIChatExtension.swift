import AppKit

@MainActor final class AIChatExtension: FlickExtension {
    let id = "ai-chat"
    let name = "AI Chat"
    var searchPriority: Double { 8 }
    var maxSearchResults: Int { 1 }

    private let rootCommand: AIChatCommand

    init(onActivate: @escaping (String) -> Void) {
        rootCommand = AIChatCommand(initialPrompt: "", onActivate: onActivate)
    }

    func homeCommands() -> [any FlickCommand] { [rootCommand] }

    // "ai <text>" or "ask <text>" → enter chat pre-loaded with that first message
    func keywordDispatch(query: String) -> (any FlickCommand)? {
        let lower = query.lowercased()
        guard lower.hasPrefix("ai ") || lower.hasPrefix("ask ") else { return nil }
        let prompt = String(query.drop(while: { !$0.isWhitespace }))
            .trimmingCharacters(in: .whitespaces)
        return AIChatCommand(initialPrompt: prompt, onActivate: rootCommand.onActivate)
    }
}

@MainActor final class AIChatCommand: FlickCommand {
    let id: String
    let title: String
    let subtitle: String?
    let icon: NSImage? = NSImage(systemSymbolName: "brain", accessibilityDescription: nil)
    let keywords = ["ai", "ask", "chat", "assistant", "intelligence"]
    let category = "AI"
    let actionLabel = "Start AI Chat"
    let sectionTitle = "Suggested"
    let onActivate: (String) -> Void

    private let initialPrompt: String

    init(initialPrompt: String, onActivate: @escaping (String) -> Void) {
        self.initialPrompt = initialPrompt
        self.onActivate = onActivate
        self.id = "ai-chat-\(initialPrompt.hashValue)"
        self.title = initialPrompt.isEmpty ? "Ask AI" : "Ask AI: \(initialPrompt)"
        self.subtitle = initialPrompt.isEmpty ? "On-device · private" : nil
    }

    func run() { onActivate(initialPrompt) }
}
