import CoreData
import Factory
import Foundation
import SharedLib

@available(iOS 26.0, macOS 26.0, *)
@Observable
final class AutoTagViewModel {
    enum Outcome {
        case added([String])
        case noTags
        case failed(String)
    }

    static func localizedMessage(for outcome: Outcome) -> String {
        switch outcome {
        case let .added(tags):
            let format = NSLocalizedString("Added tags: %@", bundle: .main, value: "Added tags: %@", comment: "")
            return String(format: format, tags.joined(separator: ", "))
        case .noTags:
            return NSLocalizedString("No tags suggested", bundle: .main, value: "No tags suggested", comment: "")
        case let .failed(reason):
            let base = NSLocalizedString("Auto-tagging failed", bundle: .main, value: "Auto-tagging failed", comment: "")
            return reason.isEmpty ? base : "\(base): \(reason)"
        }
    }

    @ObservationIgnored
    @Injected(\.wallabagSession) private var session

    @ObservationIgnored
    @CoreDataViewContext var coreDataContext: NSManagedObjectContext

    var isGenerating = false

    @MainActor
    func autoTag(entry: Entry) async -> Outcome {
        isGenerating = true
        defer { isGenerating = false }

        let existingTags = (try? coreDataContext.fetch(Tag.fetchRequestSorted()))?.map(\.label) ?? []
        let content = entry.content?.withoutHTML ?? ""

        let suggestions: [String]
        do {
            suggestions = try await AutoTagService.suggestTags(content: content, existingTags: existingTags)
        } catch {
            logger.error("Auto-tag: generation failed: \(String(describing: error))")
            return .failed(error.localizedDescription)
        }

        guard !suggestions.isEmpty else { return .noTags }

        let currentTags = Array(entry.tags)
        for tag in currentTags {
            do {
                try await session.delete(tag: tag, for: entry)
            } catch {
                logger.error("Auto-tag: could not remove tag '\(tag.label)': \(String(describing: error))")
            }
        }

        var added: [String] = []
        var lastError: Error?
        for suggestion in suggestions {
            do {
                try await session.add(tag: suggestion, for: entry)
                added.append(suggestion)
            } catch {
                lastError = error
                logger.error("Auto-tag: could not add tag '\(suggestion)': \(String(describing: error))")
            }
        }

        if added.isEmpty {
            return .failed(lastError?.localizedDescription ?? "")
        }
        return .added(added)
    }
}
