import Foundation
import FoundationModels

@MainActor final class AIService {
    static let shared = AIService()
    private init() {}

    var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    var unavailabilityReason: String {
        if case .unavailable(let reason) = SystemLanguageModel.default.availability {
            return String(describing: reason)
        }
        return ""
    }

    func makeSession(instructions: String = "You are a concise, helpful assistant.") throws -> LanguageModelSession {
        guard isAvailable else { throw AIError.notAvailable }
        return LanguageModelSession(instructions: instructions)
    }

    func prewarm() async {
        guard isAvailable else { return }
        guard !Task.isCancelled else { return }
        guard let session = try? makeSession() else { return }
        guard !Task.isCancelled else { return }
        session.prewarm()
    }
}

enum AIError: LocalizedError {
    case notAvailable
    var errorDescription: String? {
        "Apple Intelligence is not available. Enable it in System Settings → Apple Intelligence & Siri."
    }
}
