import Foundation

#if os(iOS)
    import UIKit
    import WebKit

    @MainActor
    final class EntryPDFGenerator: NSObject, WKNavigationDelegate {
        private enum PDFError: Error {
            case missingTemplate
        }

        private var webView: WKWebView?
        private var continuation: CheckedContinuation<Data, Error>?

        func generatePDF(articleHTML: String) async throws -> Data {
            guard let templateURL = Bundle.main.url(forResource: "article-pdf", withExtension: "html"),
                  let template = try? String(contentsOf: templateURL)
            else {
                throw PDFError.missingTemplate
            }

            let html = template.replacingOccurrences(of: "%@", with: articleHTML)

            return try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation

                let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: Self.pageWidth, height: Self.pageHeight))
                webView.overrideUserInterfaceStyle = .light
                webView.navigationDelegate = self
                webView.loadHTMLString(html, baseURL: Bundle.main.bundleURL)
                self.webView = webView
            }
        }

        func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self, let continuation = self.continuation else { return }
                self.continuation = nil
                continuation.resume(returning: Self.renderPDF(webView: webView))
            }
        }

        func webView(_: WKWebView, didFail _: WKNavigation!, withError error: Error) {
            continuation?.resume(throwing: error)
            continuation = nil
        }

        func webView(_: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError error: Error) {
            continuation?.resume(throwing: error)
            continuation = nil
        }

        private static let pageWidth: CGFloat = 595.2
        private static let pageHeight: CGFloat = 841.8

        private static func renderPDF(webView: WKWebView) -> Data {
            let printRenderer = A4PrintPageRenderer()
            printRenderer.addPrintFormatter(webView.viewPrintFormatter(), startingAtPageAt: 0)

            let pdfData = NSMutableData()
            UIGraphicsBeginPDFContextToData(pdfData, printRenderer.paperRect, nil)

            let numberOfPages = printRenderer.numberOfPages
            for pageIndex in 0 ..< numberOfPages {
                UIGraphicsBeginPDFPage()
                printRenderer.drawPage(at: pageIndex, in: UIGraphicsGetPDFContextBounds())
            }

            UIGraphicsEndPDFContext()
            return pdfData as Data
        }
    }

    private final class A4PrintPageRenderer: UIPrintPageRenderer {
        override var paperRect: CGRect {
            CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        }

        override var printableRect: CGRect {
            paperRect.insetBy(dx: 40, dy: 40)
        }
    }
#endif
