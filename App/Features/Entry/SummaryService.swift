import Foundation
import FoundationModels

@available(iOS 26.0, macOS 26.0, *)
enum SummaryService {
    private static let excerptLimits = [6000, 3000, 1500, 700]

    static func summarize(content: String, title: String?) async throws -> String {
        var lastError: Error?
        for excerptLimit in excerptLimits {
            do {
                return try await generate(content: content, title: title, excerptLimit: excerptLimit)
            } catch {
                // Retry with a smaller excerpt; the model may have balked at the
                // article text (guardrails/refusal) or the prompt was too long.
                lastError = error
            }
        }
        if let lastError { throw lastError }
        return ""
    }

    private static func generate(content: String, title: String?, excerptLimit: Int) async throws -> String {
        // Summarizing is a content transformation: the source article may
        // discuss sensitive topics even though summarizing it is harmless.
        let model = SystemLanguageModel(useCase: .general, guardrails: .permissiveContentTransformations)
        let session = LanguageModelSession(model: model, instructions: instructions)
        let response = try await session.respond(to: prompt(content: content, title: title, excerptLimit: excerptLimit))
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static var instructions: String {
        "You summarize articles clearly and concisely. Write the summary in the same language as the article."
    }

    private static func prompt(content: String, title: String?, excerptLimit: Int) -> String {
        let excerpt = String(content.prefix(excerptLimit))
        var prompt = "Summarize the following article in one concise paragraph."
        if let title, !title.isEmpty {
            prompt += "\nTitle: \(title)"
        }
        prompt += "\nText: \(excerpt)"
        return prompt
    }
}
