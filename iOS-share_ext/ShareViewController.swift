import SharedLib
import SwiftUI
import UIKit
import UniformTypeIdentifiers

@objc(ShareViewController)
class ShareViewController: UIViewController {
    private let extError = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "App maybe not configured"])
    private var didStart = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        guard !didStart else { return }
        didStart = true

        guard WallabagUserDefaults.registred else {
            present(error: .unregistredApp)
            return
        }

        Task {
            do {
                let payload = try await extractSharedPayload()
                embedShareView(with: payload)
            } catch let error as ShareExtensionError {
                present(error: error)
            } catch {
                present(error: .retrievingURL)
            }
        }
    }

    private func embedShareView(with payload: SharedPayload) {
        let viewModel = ShareViewModel(
            payload: payload,
            onComplete: { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            },
            onCancel: { [weak self] in
                self?.extensionContext?.cancelRequest(withError: self?.extError ?? NSError(domain: "", code: 0))
            }
        )

        let hostingController = UIHostingController(rootView: ShareView(viewModel: viewModel))
        addChild(hostingController)
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
    }

    private func present(error: ShareExtensionError) {
        let alertController = UIAlertController(title: NSLocalizedString("Error", comment: ""), message: error.localizedDescription, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Ok", comment: ""), style: .cancel) { [weak self] _ in
            self?.extensionContext?.cancelRequest(withError: self?.extError ?? NSError(domain: "", code: 0))
        })
        present(alertController, animated: true)
    }

    private func extractSharedPayload() async throws -> SharedPayload {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem else {
            throw ShareExtensionError.retrievingURL
        }

        let attachments = item.attachments ?? []
        let sharedTitle = fallbackTitle(from: item)

        if let payload = try await fileURLPayload(from: attachments, sharedTitle: sharedTitle) {
            return payload
        }
        if let payload = try await pdfAttachmentPayload(from: attachments, sharedTitle: sharedTitle) {
            return payload
        }
        if let payload = try await javaScriptPayload(from: attachments, sharedTitle: sharedTitle) {
            return payload
        }
        if let payload = try await urlPayload(from: attachments, sharedTitle: sharedTitle) {
            return payload
        }
        if let payload = try await plainTextPayload(from: attachments, sharedTitle: sharedTitle) {
            return payload
        }

        throw ShareExtensionError.retrievingURL
    }

    /// A PDF shared from the Files app or another document app arrives as a
    /// file URL attachment.
    private func fileURLPayload(from attachments: [NSItemProvider], sharedTitle: String?) async throws -> SharedPayload? {
        guard let attachment = attachments.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }),
              let loaded = try? await loadItem(from: attachment, typeIdentifier: UTType.fileURL.identifier),
              let fileURL = SharedItemParser.fileURL(from: loaded)
        else {
            return nil
        }

        // Providers do not always keep the file extension, so the attachment's
        // declared type counts as well. The copied file is validated anyway.
        let claimsPDF = attachment.hasItemConformingToTypeIdentifier(UTType.pdf.identifier)
        guard claimsPDF || PDFImportFile.isPDF(fileURL) else {
            throw ShareExtensionError.unsupportedFile
        }

        return try await pdfPayload(from: fileURL, sharedTitle: sharedTitle, claimsPDF: claimsPDF)
    }

    /// Some apps hand over the PDF data instead of a file URL.
    private func pdfAttachmentPayload(from attachments: [NSItemProvider], sharedTitle: String?) async throws -> SharedPayload? {
        guard let attachment = attachments.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) }),
              let loaded = try? await loadItem(from: attachment, typeIdentifier: UTType.pdf.identifier)
        else {
            return nil
        }

        if let fileURL = SharedItemParser.fileURL(from: loaded) {
            return try await pdfPayload(from: fileURL, sharedTitle: sharedTitle, claimsPDF: true)
        }

        guard let data = SharedItemParser.data(from: loaded) else {
            return nil
        }

        do {
            let localURL = try PDFImportFile.writeTemporaryFile(from: data)
            return .pdf(url: localURL, fileName: sharedTitle ?? "PDF", title: sharedTitle)
        } catch {
            throw ShareExtensionError.unsupportedFile
        }
    }

    private func javaScriptPayload(from attachments: [NSItemProvider], sharedTitle: String?) async throws -> SharedPayload? {
        guard let attachment = attachments.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.propertyList.identifier) }),
              let loaded = try? await loadItem(from: attachment, typeIdentifier: UTType.propertyList.identifier),
              let dictionary = loaded as? NSDictionary,
              let results = dictionary[NSExtensionJavaScriptPreprocessingResultsKey] as? NSDictionary,
              let href = results["href"] as? String
        else {
            return nil
        }

        if let fileURL = SharedItemParser.fileURL(fromString: href) {
            return try await pdfPayload(from: fileURL, sharedTitle: sharedTitle)
        }

        let pageTitle = (results["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = pageTitle?.isEmpty == false ? pageTitle : sharedTitle
        return .links(urls: [href], title: title, contentHTML: results["contentHTML"] as? String)
    }

    private func urlPayload(from attachments: [NSItemProvider], sharedTitle: String?) async throws -> SharedPayload? {
        guard let attachment = attachments.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }),
              let loaded = try? await loadItem(from: attachment, typeIdentifier: UTType.url.identifier),
              let urlString = SharedItemParser.urlString(from: loaded)
        else {
            return nil
        }

        if let fileURL = SharedItemParser.fileURL(fromString: urlString) {
            return try await pdfPayload(from: fileURL, sharedTitle: sharedTitle)
        }

        return .links(urls: [urlString], title: sharedTitle, contentHTML: nil)
    }

    /// Many apps (e.g. newspaper apps) export the shared article as plain text in
    /// which the URL is embedded rather than as a URL attachment.
    private func plainTextPayload(from attachments: [NSItemProvider], sharedTitle: String?) async throws -> SharedPayload? {
        guard let attachment = attachments.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }),
              let loaded = try? await loadItem(from: attachment, typeIdentifier: UTType.plainText.identifier),
              let text = loaded as? String
        else {
            return nil
        }

        if let fileURL = SharedItemParser.fileURL(inText: text) {
            return try await pdfPayload(from: fileURL, sharedTitle: sharedTitle)
        }

        let urls = text.detectedURLs.map(\.absoluteString)
        guard !urls.isEmpty else { return nil }

        return .links(urls: urls, title: sharedTitle, contentHTML: nil)
    }

    private func pdfPayload(from url: URL, sharedTitle: String?, claimsPDF: Bool = false) async throws -> SharedPayload {
        guard claimsPDF || PDFImportFile.isPDF(url) else {
            throw ShareExtensionError.unsupportedFile
        }

        let fileName = url.lastPathComponent.isEmpty ? (sharedTitle ?? "PDF") : url.lastPathComponent
        let title = sharedTitle ?? url.deletingPathExtension().lastPathComponent

        do {
            let localURL = try PDFImportFile.copyToTemporaryDirectory(from: url)
            return .pdf(url: localURL, fileName: fileName, title: title)
        } catch {
            throw ShareExtensionError.unreadableFile
        }
    }

    private func fallbackTitle(from item: NSExtensionItem) -> String? {
        guard let rawTitle = item.attributedContentText?.string else {
            return nil
        }

        let title = rawTitle
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard !title.isEmpty, title.count <= 200 else {
            return nil
        }

        return title
    }

    private func loadItem(from attachment: NSItemProvider, typeIdentifier: String) async throws -> NSSecureCoding? {
        try await withCheckedThrowingContinuation { continuation in
            attachment.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: item)
                }
            }
        }
    }
}

/// Turns the loosely typed items an `NSItemProvider` hands over into URLs, strings
/// and data.
enum SharedItemParser {
    static func fileURL(from loaded: NSSecureCoding?) -> URL? {
        if let url = loaded as? URL, url.isFileURL {
            return url
        }
        if let url = loaded as? NSURL, url.isFileURL {
            return url as URL
        }
        return nil
    }

    static func urlString(from loaded: NSSecureCoding?) -> String? {
        if let url = loaded as? NSURL {
            return url.absoluteString
        }
        if let url = loaded as? URL {
            return url.absoluteString
        }
        return loaded as? String
    }

    static func data(from loaded: NSSecureCoding?) -> Data? {
        if let data = loaded as? Data {
            return data
        }
        return (loaded as? NSData) as Data?
    }

    /// Returns the file URL of a string that starts with `file://`.
    static func fileURL(fromString string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("file://"), let url = URL(string: trimmed), url.isFileURL else {
            return nil
        }
        return url
    }

    /// Finds a `file://` URL inside shared plain text.
    static func fileURL(inText text: String) -> URL? {
        for token in text.components(separatedBy: .whitespacesAndNewlines) {
            let trimmed = token.trimmingCharacters(in: CharacterSet(charactersIn: "\"'<>,;()[]"))
            if let url = fileURL(fromString: trimmed) {
                return url
            }
        }
        return nil
    }
}
