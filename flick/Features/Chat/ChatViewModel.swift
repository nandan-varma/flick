import FoundationModels
import AppKit

struct ChatMessage {
    enum Role { case user, assistant }
    let role: Role
    var text: String
    var isStreaming: Bool
}

@Observable @MainActor final class ChatViewModel {
    var messages: [ChatMessage] = []
    var isStreaming: Bool = false
    private(set) var session: LanguageModelSession?
    private let aiService: AIService

    init(aiService: AIService) {
        self.aiService = aiService
    }

    func reset() {
        messages = []
        isStreaming = false
        session = try? aiService.makeSession(
            instructions: "You are a helpful assistant built into flick, a macOS launcher. Be concise and direct."
        )
        if session == nil && !aiService.isAvailable {
            messages = [ChatMessage(
                role: .assistant,
                text: aiService.unavailabilityReason.isEmpty
                    ? AIError.notAvailable.errorDescription!
                    : "Apple Intelligence is not available: \(aiService.unavailabilityReason)\n\nEnable it in System Settings → Apple Intelligence & Siri.",
                isStreaming: false
            )]
        }
    }

    func send(_ prompt: String) async {
        let trimmed = prompt.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard let session, !session.isResponding else { return }

        messages.append(ChatMessage(role: .user, text: trimmed, isStreaming: false))
        messages.append(ChatMessage(role: .assistant, text: "", isStreaming: true))
        isStreaming = true

        do {
            let stream = session.streamResponse(to: trimmed)
            for try await partial in stream {
                messages[messages.count - 1].text = partial.content
            }
        } catch {
            messages[messages.count - 1].text = "Error: \(error.localizedDescription)"
        }

        messages[messages.count - 1].isStreaming = false
        isStreaming = false
    }
}
