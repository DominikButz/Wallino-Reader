import SwiftUI
import WebKit

struct HTMLViewerView: UIViewRepresentable {
    let fileName: String
    @Environment(\.palette) private var palette

    func makeUIView(context _: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.isOpaque = false
        updateBackground(of: webView)

        if let path = Bundle.main.path(forResource: fileName, ofType: "html"),
           let html = try? String(contentsOfFile: path, encoding: .utf8) {
            webView.loadHTMLString(html, baseURL: nil)
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context _: Context) {
        updateBackground(of: webView)
    }

    /// The documents ship their own colors, this keeps the bounce area themed.
    private func updateBackground(of webView: WKWebView) {
        let background = UIColor(palette.background)
        webView.backgroundColor = background
        webView.scrollView.backgroundColor = background
    }
}

struct HTMLViewerContainerView: View {
    let fileName: String
    let navTitle: String

    var body: some View {
        HTMLViewerView(fileName: fileName)
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
    }
}
