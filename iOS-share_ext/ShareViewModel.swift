import Foundation
import Observation
import SharedLib
import WallabagKit

/// What the share sheet received from the host app.
enum SharedPayload {
    case links(urls: [String], title: String?, contentHTML: String?)
    case pdf(url: URL, fileName: String, title: String?)
}

@MainActor
@Observable
final class ShareViewModel {
    /// Extracted PDF content that waits for the user's confirmation because the
    /// document is longer than the import limit.
    struct PendingTruncation {
        let html: String
        let importedCharacterCount: Int
        let totalCharacterCount: Int
    }

    let payload: SharedPayload

    var pageTitle: String?
    var contentHTML: String?
    var urls: [String]

    var pdfFileName: String?
    var pdfPageCount = 0
    var pdfError: String?
    var isConvertingPDF = false
    var pdfProgressPage = 0
    var pdfProgressTotal = 0
    var entryTitle = ""
    var domainName = ""
    var showTruncationConfirmation = false
    var pendingTruncation: PendingTruncation?

    private var pdfContent: String?
    private var pdfFallbackTitle = ""

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
        payload: SharedPayload,
        onComplete: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.payload = payload
        self.onComplete = onComplete
        self.onCancel = onCancel

        switch payload {
        case let .links(urls, title, contentHTML):
            self.urls = urls
            pageTitle = title
            self.contentHTML = contentHTML
        case let .pdf(_, fileName, title):
            urls = []
            pageTitle = title
            pdfFileName = fileName
        }

        kit = WallabagKit(host: WallabagUserDefaults.host)
        kit.clientId = WallabagUserDefaults.clientId
        kit.clientSecret = WallabagUserDefaults.clientSecret
        kit.username = WallabagUserDefaults.login
        kit.password = WallabagUserDefaults.password
    }

    var isPDF: Bool {
        if case .pdf = payload {
            return true
        }
        return false
    }

    var canAdd: Bool {
        guard !isConvertingPDF, !showTruncationConfirmation else { return false }
        guard isPDF else { return true }
        return pdfContent != nil
    }

    var selectableTags: [WallabagTag] {
        let available = availableTags.filter { !selectedTags.contains($0.label) }
        guard !search.isEmpty else { return available }
        return available.filter { $0.label.localizedCaseInsensitiveContains(search) }
    }

    func load() async {
        if case let .pdf(url, _, title) = payload {
            await convertPDF(at: url, fallbackTitle: title ?? url.deletingPathExtension().lastPathComponent)
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await ensureAuthenticated()
            availableTags = try await kit.fetchTags()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - PDF

    private func convertPDF(at url: URL, fallbackTitle: String) async {
        isConvertingPDF = true
        pdfProgressPage = 1
        pdfProgressTotal = 1
        defer { isConvertingPDF = false }

        do {
            let progress = SharePDFProgress { [weak self] page, total in
                self?.pdfProgressPage = page
                self?.pdfProgressTotal = total
            }

            // The share extension has less memory headroom than the app, so the
            // number of OCR converted pages is kept lower.
            let result = try await Task.detached(priority: .userInitiated) {
                try PDFTextExtractor(maxOCRPages: 25).extract(from: url) { page, total in
                    progress.report(page: page, total: total)
                }
            }.value

            pdfPageCount = result.pageCount
            pdfFallbackTitle = result.title ?? fallbackTitle
            if entryTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                entryTitle = pdfFallbackTitle
            }

            if result.truncated {
                pendingTruncation = PendingTruncation(
                    html: result.html,
                    importedCharacterCount: result.importedCharacterCount,
                    totalCharacterCount: result.totalCharacterCount
                )
                showTruncationConfirmation = true
            } else {
                pdfContent = result.html
            }
        } catch {
            pdfContent = nil
            pdfError = ShareViewModel.importErrorMessage(for: error)
            deleteTemporaryPDF()
        }
    }

    func confirmTruncatedImport() {
        showTruncationConfirmation = false
        guard let pending = pendingTruncation else { return }
        pendingTruncation = nil

        let notice = "The remaining PDF text was not imported.".localized
        pdfContent = pending.html + "<p><em>\(notice)</em></p>"
    }

    func cancelTruncatedImport() {
        showTruncationConfirmation = false
        pendingTruncation = nil
        pdfContent = nil
        pdfError = "The PDF was not imported.".localized
        deleteTemporaryPDF()
    }

    private static func importErrorMessage(for error: Error) -> String {
        switch error {
        case PDFImportFile.ImportError.notAPDF:
            return "Only PDF files can be imported".localized
        case PDFTextExtractor.ExtractError.empty:
            return "The PDF has no pages".localized
        case PDFTextExtractor.ExtractError.noText:
            return "No text could be extracted from the PDF".localized
        default:
            return "Could not read the PDF".localized
        }
    }

    private func deleteTemporaryPDF() {
        guard case let .pdf(url, _, _) = payload else { return }
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Tags

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

    // MARK: - Save

    func save() async {
        guard canAdd else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            try await ensureAuthenticated()
            var createdEntryIds: [Int] = []

            switch payload {
            case let .links(urls, _, _):
                for url in urls {
                    var entry: WallabagEntry = try await kit.send(
                        to: WallabagEntryEndpoint.add(
                            url: url,
                            title: pageTitle,
                            content: contentHTML,
                            tags: selectedTags,
                            starred: isStarred,
                            archived: isRead
                        )
                    )

                    // Wallabag could not retrieve the article server-side (anti-bot
                    // wall, paywall, ...): fetch it on the device and push the HTML.
                    if ArticleContent.isUnusable(entry.content),
                       let repaired = await repairedEntry(entry, fallbackURL: url) {
                        entry = repaired
                    }

                    createdEntryIds.append(entry.id)
                }
            case let .pdf(url, _, _):
                guard let content = pdfContent else { return }

                let entry: WallabagEntry = try await kit.send(
                    to: WallabagEntryEndpoint.add(
                        url: EntryLink.fakeURL(domainName: domainName, kind: .pdf),
                        title: EntryLink.title(entryTitle, fallback: pdfFallbackTitle),
                        content: content,
                        tags: selectedTags,
                        starred: isStarred,
                        archived: isRead
                    )
                )

                createdEntryIds.append(entry.id)
                try? FileManager.default.removeItem(at: url)
            }

            enqueuePendingAutoTagIfNeeded(createdEntryIds)
            onComplete()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Fetches the article on the device and PATCHes the entry content. Returns
    /// `nil` when the device fetch or the update failed.
    private func repairedEntry(_ entry: WallabagEntry, fallbackURL: String) async -> WallabagEntry? {
        guard let article = try? await ArticleFetcher().fetch(url: entry.url ?? fallbackURL) else {
            return nil
        }

        var parameters: WallabagKit.Parameters = ["content": article.html]
        if let title = article.title, !title.isEmpty {
            parameters["title"] = title
        }

        return try? await kit.send(to: WallabagEntryEndpoint.update(id: entry.id, parameters: parameters))
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
        deleteTemporaryPDF()
        onCancel()
    }

    private func ensureAuthenticated() async throws {
        if kit.accessToken == nil {
            _ = try await kit.requestTokenAsync()
        }
    }
}

/// Forwards PDF conversion progress from a background task to the main actor.
private final class SharePDFProgress: @unchecked Sendable {
    private let handler: @MainActor (Int, Int) -> Void

    init(_ handler: @escaping @MainActor (Int, Int) -> Void) {
        self.handler = handler
    }

    func report(page: Int, total: Int) {
        Task { @MainActor in
            handler(page, total)
        }
    }
}
