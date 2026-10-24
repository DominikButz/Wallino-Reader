import Foundation
import WebKit

public extension WKWebView {
    func load(content: String?, justify: Bool, themeStyleSheet: String? = nil) {
        guard let content = contentForWebView(content, justify: justify, themeStyleSheet: themeStyleSheet) else { return }
        loadHTMLString(content, baseURL: Bundle.main.bundleURL)
    }

    nonisolated func contentForWebView(_ content: String?, justify: Bool, themeStyleSheet: String? = nil) -> String? {
        do {
            guard let content else { return nil }
            let html = try String(contentsOfFile: Bundle.main.path(forResource: "article", ofType: "html")!)
            let justify = justify ? "justify.css" : ""
            let themeStyleSheet = themeStyleSheet.map {
                "<link rel=\"stylesheet\" href=\"\($0)\" media=\"all\" id=\"light-theme\">"
            } ?? ""

            return String(format: html, arguments: [themeStyleSheet, justify, content])
        } catch {
            fatalError("Unable to load article view")
        }
    }

    func fontSizePercent(_ fontSize: Double) {
        let javascript = "document.getElementsByTagName('body')[0].style.fontSize='\(fontSize)%'"
        evaluateJavaScript(javascript, completionHandler: nil)
    }
}
