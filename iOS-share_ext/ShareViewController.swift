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
                let item = try await extractSharedItem()
                embedShareView(with: item)
            } catch {
                present(error: .retrievingURL)
            }
        }
    }

    private func embedShareView(with item: (url: String, title: String?, content: String?)) {
        let viewModel = ShareViewModel(
            url: item.url,
            title: item.title,
            contentHTML: item.content,
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

    private func extractSharedItem() async throws -> (url: String, title: String?, content: String?) {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem else {
            throw ShareExtensionError.retrievingURL
        }

        let attachments = item.attachments ?? []

        if let attachment = attachments.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.propertyList.identifier) }),
           let loaded = try? await loadItem(from: attachment, typeIdentifier: UTType.propertyList.identifier),
           let dictionary = loaded as? NSDictionary,
           let results = dictionary[NSExtensionJavaScriptPreprocessingResultsKey] as? NSDictionary,
           let href = results["href"] as? String {
            return (href, results["title"] as? String, results["contentHTML"] as? String)
        }

        if let attachment = attachments.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }),
           let loaded = try? await loadItem(from: attachment, typeIdentifier: UTType.url.identifier),
           let url = (loaded as? NSURL)?.absoluteString {
            return (url, nil, nil)
        }

        throw ShareExtensionError.retrievingURL
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
