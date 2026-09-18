import Foundation
import SharedLib

@available(iOS 26.0, macOS 26.0, *)
@Observable
final class SummaryViewModel {
    var summary = ""
    var isLoading = false
    var errorMessage: String?

    var hasSummary: Bool {
        !summary.isEmpty
    }

    @MainActor
    func summarize(entry: Entry) async {
        isLoading = true
        summary = ""
        errorMessage = nil
        defer { isLoading = false }

        let content = entry.content?.withoutHTML ?? ""
        do {
            summary = try await SummaryService.summarize(content: content, title: entry.title)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
