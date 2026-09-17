import SwiftUI
import WebKit

struct HTMLViewerView: UIViewRepresentable {
    let fileName: String

    func makeUIView(context _: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground

        if let path = Bundle.main.path(forResource: fileName, ofType: "html"),
           let html = try? String(contentsOfFile: path, encoding: .utf8)
        {
            webView.loadHTMLString(html, baseURL: nil)
        }

        return webView
    }

    func updateUIView(_: WKWebView, context _: Context) {}
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
