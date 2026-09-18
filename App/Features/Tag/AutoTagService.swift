import Foundation
import FoundationModels

@available(iOS 26.0, macOS 26.0, *)
@Generable
struct AutoTagSuggestion {
    @Guide(description: "Up to two concise tag names.")
    @Guide(.maximumCount(2))
    var tags: [String]
}

@available(iOS 26.0, macOS 26.0, *)
enum AutoTagService {
    private static let maxContentCharacters = 2000
    private static let maxTagListCharacters = 1000

    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    /// True while Apple Intelligence is still preparing its model. The feature
    /// should be retried later instead of treating it as permanently unavailable.
    static var isTemporarilyUnavailable: Bool {
        if case let .unavailable(reason) = SystemLanguageModel.default.availability {
            return reason == .modelNotReady
        }
        return false
    }

    static func suggestTags(content: String, existingTags: [String]) async throws -> [String] {
        var lastError: Error?
        for excerptLimit in excerptLimits {
            do {
                return try await generate(content: content, existingTags: existingTags, excerptLimit: excerptLimit)
            } catch {
                // Retry with a smaller excerpt; the model may have balked at the
                // article text (guardrails/refusal) or the prompt was too long.
                lastError = error
            }
        }
        if let lastError { throw lastError }
        return []
    }

    private static let excerptLimits = [maxContentCharacters, 800, 400, 150]

    private static func generate(content: String, existingTags: [String], excerptLimit: Int) async throws -> [String] {
        // Tagging is a content transformation: the source article may discuss
        // sensitive topics (finance, health, …) even though producing tag names
        // is harmless, so use the permissive guardrail mode to avoid false
        // "May contain sensitive content" refusals.
        let model = SystemLanguageModel(useCase: .general, guardrails: .permissiveContentTransformations)
        let session = LanguageModelSession(model: model, instructions: instructions)
        let response = try await session.respond(
            to: prompt(content: content, existingTags: existingTags, excerptLimit: excerptLimit),
            generating: AutoTagSuggestion.self
        )

        var seen = Set<String>()
        return Array(
            response.content.tags
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
                .prefix(2)
        )
    }

    private static var instructions: String {
        "You suggest up to two concise, reusable tags for a saved article. Prefer the provided existing tags. Return only tag names."
    }

    private static func prompt(content: String, existingTags: [String], excerptLimit: Int) -> String {
        let excerpt = String(content.prefix(excerptLimit))
        let tags = String(existingTags.joined(separator: ", ").prefix(maxTagListCharacters))
        return """
        Suggest up to two tag names, reflecting the text's topic(s). Here is a list of existing tags: \(tags). If none of them fits, you may suggest up to two new tag names in the predominant language of the existing tags. If the provided tag list is empty, use the language of the text. Prefer the existing tags before suggesting new tags.  Avoid suggesting new combined tag names such as 'german economy', rather pick or suggest two tags, such as 'germany' and 'economy'. 
        Text: \(excerpt)
        """
    }
}
