import Factory
import Foundation
import HTMLEntities
import Observation
import SharedLib
import SwiftUI

enum AddEntryMode: String, CaseIterable, Identifiable {
    case url
    case text
    case pdf

    var id: String { rawValue }
}

@Observable
final class AddEntryModel {
    /// Extraction result of an overlong PDF that still waits for the user's
    /// confirmation before it becomes the entry's content.
    struct PendingTruncation {
        let html: String
        let importedCharacterCount: Int
        let totalCharacterCount: Int
    }

    @ObservationIgnored
    @Injected(\.wallabagSession) private var session

    var mode: AddEntryMode = .url
    var input: String = ""
    var domainName: String = ""
    var submitting: Bool = false
    var succeeded: Bool = false
    var addedCount: Int = 0

    var pdfFileName: String?
    var pdfTitle: String = ""
    var pdfFallbackTitle: String = ""
    var pdfContent: String?
    var pdfPageCount: Int = 0
    var pdfImporting: Bool = false
    var pdfProgressPage: Int = 0
    var pdfProgressTotal: Int = 0
    var pdfError: String?
    var pendingTruncation: PendingTruncation?
    var showTruncationConfirmation: Bool = false

    var canSubmit: Bool {
        switch mode {
        case .url, .text:
            return !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .pdf:
            return pdfContent != nil && !pdfImporting && !showTruncationConfirmation
        }
    }

    /// `true` once the PDF is converted and the entry title can be edited.
    var pdfTitleReady: Bool {
        !pdfImporting && pdfError == nil && (pdfContent != nil || pendingTruncation != nil)
    }

    @MainActor
    func addEntry() async {
        let input = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let domain = domainName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSubmit else { return }

        defer {
            submitting = false
            succeeded = false
        }

        submitting = true
        do {
            var addedEntries: [Entry] = []

            switch mode {
            case .url:
                let urls = input.detectedURLs
                guard !urls.isEmpty else { return }
                for detectedURL in urls {
                    let entry = try await session.addEntry(url: detectedURL.absoluteString)
                    addedEntries.append(entry)
                }
                addedCount = urls.count
            case .text:
                let textEntry = AddEntryModel.textEntry(from: input)
                let entry = try await session.addEntry(
                    title: textEntry.title,
                    content: textEntry.content,
                    url: AddEntryModel.textEntryURL(domainName: domain)
                )
                addedEntries.append(entry)
                addedCount = 1
            case .pdf:
                guard let content = pdfContent else { return }
                let entry = try await session.addEntry(
                    title: AddEntryModel.pdfEntryTitle(pdfTitle, fallback: pdfFallbackTitle),
                    content: content,
                    url: AddEntryModel.pdfEntryURL(domainName: domain)
                )
                addedEntries.append(entry)
                addedCount = 1
            }

            succeeded = true
            await autoTag(addedEntries)
            clearInput()
            try await Task.sleep(for: .seconds(3))
        } catch {}
    }

    // MARK: - PDF import

    /// Reads the picked PDF on the device and turns it into HTML. When the PDF
    /// is too long, the content only becomes available after the user confirmed
    /// the truncated import.
    @MainActor
    func importPDF(from url: URL) async {
        clearPDF()
        pdfFileName = url.lastPathComponent
        pdfImporting = true
        defer { pdfImporting = false }

        do {
            let localURL = try PDFImportFile.copyToTemporaryDirectory(from: url)
            defer { try? FileManager.default.removeItem(at: localURL) }

            let progress = PDFImportProgress { [weak self] page, total in
                self?.pdfProgressPage = page
                self?.pdfProgressTotal = total
            }
            pdfProgressPage = 1
            pdfProgressTotal = 1

            let result = try await Task.detached(priority: .userInitiated) {
                try PDFTextExtractor().extract(from: localURL) { page, total in
                    progress.report(page: page, total: total)
                }
            }.value

            pdfPageCount = result.pageCount
            pdfFallbackTitle = result.title ?? url.deletingPathExtension().lastPathComponent
            pdfTitle = pdfFallbackTitle

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
            pdfError = AddEntryModel.importErrorMessage(for: error)
        }
    }

    @MainActor
    func confirmTruncatedImport() {
        showTruncationConfirmation = false
        guard let pending = pendingTruncation else { return }
        pendingTruncation = nil

        let notice = "The remaining PDF text was not imported.".localized.htmlEscape()
        pdfContent = pending.html + "<p><em>\(notice)</em></p>"
    }

    @MainActor
    func cancelTruncatedImport() {
        showTruncationConfirmation = false
        pendingTruncation = nil
        clearPDF()
    }

    @MainActor
    func clearPDF() {
        pdfFileName = nil
        pdfTitle = ""
        pdfFallbackTitle = ""
        pdfContent = nil
        pdfPageCount = 0
        pdfError = nil
        pdfProgressPage = 0
        pdfProgressTotal = 0
        pendingTruncation = nil
        showTruncationConfirmation = false
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

    @MainActor
    private func clearInput() {
        input = ""
        domainName = ""
        clearPDF()
    }

    // MARK: - Text import

    static func textEntry(from text: String) -> (title: String, content: String) {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let lines = normalized.components(separatedBy: "\n")
        let title = lines.first?.trimmingCharacters(in: .whitespaces) ?? ""
        let body = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        let contentSource = body.isEmpty ? title : body

        var paragraphs: [String] = []
        var current: [String] = []
        for line in contentSource.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if !current.isEmpty {
                    paragraphs.append(current.joined(separator: "\n"))
                    current = []
                }
            } else {
                current.append(trimmed)
            }
        }

        if !current.isEmpty {
            paragraphs.append(current.joined(separator: "\n"))
        }

        let content = paragraphs
            .map { paragraph in
                let escaped = paragraph.htmlEscape().replacingOccurrences(of: "\n", with: "<br>")
                return "<p>\(escaped)</p>"
            }
            .joined()

        return (title, content)
    }

    static func normalizedDomainHost(_ input: String) -> String? {
        EntryLink.normalizedHost(input)
    }

    static func textEntryURL(domainName: String) -> String {
        EntryLink.fakeURL(domainName: domainName, kind: .text)
    }

    static func pdfEntryURL(domainName: String) -> String {
        EntryLink.fakeURL(domainName: domainName, kind: .pdf)
    }

    /// The entry title of a PDF import: whatever the user entered, or the title
    /// detected from the PDF when the field was left empty.
    static func pdfEntryTitle(_ title: String, fallback: String) -> String {
        EntryLink.title(title, fallback: fallback)
    }

    private func autoTag(_ entries: [Entry]) async {
        guard #available(iOS 26.0, macOS 26.0, *) else { return }
        let coordinator = AutoTagCoordinator()
        for entry in entries {
            await coordinator.autoTagNewEntry(entry)
        }
    }
}

/// Forwards PDF conversion progress from a background task to the main actor.
private final class PDFImportProgress: @unchecked Sendable {
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
