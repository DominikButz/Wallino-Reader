import Foundation
import Observation
import SharedLib
import WallabagKit

@MainActor
@Observable
final class ShareViewModel {
    let urls: [String]
    let title: String?
    let contentHTML: String?

    var isRead = false
    var isStarred = false

    var availableTags: [WallabagTag] = []
    var selectedTags: [String] = []
    var newTagLabel = ""
    var search = ""

    var isLoading = false
    var errorMessage: String?

    private let kit: WallabagKit
    private let onComplete: () -> Void
    private let onCancel: () -> Void

    init(
        urls: [String],
        title: String?,
        contentHTML: String?,
        onComplete: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.urls = urls
        self.title = title
        self.contentHTML = contentHTML
        self.onComplete = onComplete
        self.onCancel = onCancel

        kit = WallabagKit(host: WallabagUserDefaults.host)
        kit.clientId = WallabagUserDefaults.clientId
        kit.clientSecret = WallabagUserDefaults.clientSecret
        kit.username = WallabagUserDefaults.login
        kit.password = WallabagUserDefaults.password
    }

    var selectableTags: [WallabagTag] {
        let available = availableTags.filter { !selectedTags.contains($0.label) }
        guard !search.isEmpty else { return available }
        return available.filter { $0.label.localizedCaseInsensitiveContains(search) }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await ensureAuthenticated()
            availableTags = try await kit.fetchTags()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggle(_ tag: WallabagTag) {
        if let index = selectedTags.firstIndex(of: tag.label) {
            selectedTags.remove(at: index)
        } else {
            selectedTags.append(tag.label)
        }
    }

    func addNewTag() {
        let label = newTagLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else { return }

        if !selectedTags.contains(label) {
            selectedTags.append(label)
        }
        newTagLabel = ""
    }

    func save() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await ensureAuthenticated()
            var createdEntryIds: [Int] = []
            for url in urls {
                let entry: WallabagEntry = try await kit.send(
                    to: WallabagEntryEndpoint.add(
                        url: url,
                        title: title,
                        content: contentHTML,
                        tags: selectedTags,
                        starred: isStarred,
                        archived: isRead
                    )
                )
                createdEntryIds.append(entry.id)
            }
            enqueuePendingAutoTagIfNeeded(createdEntryIds)
            onComplete()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// When the person did not pick any tag and auto-tagging is enabled, remember
    /// the new entries so the main app can tag them once it is opened. The model
    /// is not run here to keep the extension's memory usage low.
    private func enqueuePendingAutoTagIfNeeded(_ entryIds: [Int]) {
        guard selectedTags.isEmpty, WallabagUserDefaults.autoTagNewEntry, !entryIds.isEmpty else { return }
        var pending = WallabagUserDefaults.pendingAutoTagEntryIds
        pending.append(contentsOf: entryIds.filter { !pending.contains($0) })
        WallabagUserDefaults.pendingAutoTagEntryIds = pending
    }

    func cancel() {
        onCancel()
    }

    private func ensureAuthenticated() async throws {
        if kit.accessToken == nil {
            _ = try await kit.requestTokenAsync()
        }
    }
}
