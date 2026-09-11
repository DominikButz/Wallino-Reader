import CoreData
import Factory
import SafariServices
import SwiftUI
import WallabagKit
import WebKit

#if os(iOS)
    struct WebView: UIViewRepresentable {
        var entry: Entry
        @EnvironmentObject var appSetting: AppSetting
        @Binding var progress: Double
        var annotationEditor: AnnotationEditorViewModel

        func makeCoordinator() -> Coordinator {
            Coordinator(self, appSetting: appSetting)
        }

        class Coordinator: NSObject, WKNavigationDelegate, UIScrollViewDelegate, WKScriptMessageHandler {
            @CoreDataViewContext var context: NSManagedObjectContext
            var appSetting: AppSetting

            private var webView: WebView
            weak var wkWebView: WKWebView?

            init(_ webView: WebView, appSetting: AppSetting) {
                self.webView = webView
                self.appSetting = appSetting
                super.init()
            }

            func attach(_ webView: WKWebView) {
                wkWebView = webView
                self.webView.annotationEditor.webView = webView
            }

            func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
                guard message.name == "annotation",
                      let body = message.body as? [String: Any],
                      let type = body["type"] as? String
                else {
                    return
                }

                switch type {
                case "showAdd":
                    let quote = body["quote"] as? String ?? ""
                    let ranges = parseRanges(body["ranges"])
                    webView.annotationEditor.presentAdd(quote: quote, ranges: ranges, entryId: webView.entry.id)
                case "showEdit":
                    let id = intValue(body["id"])
                    let text = body["text"] as? String ?? ""
                    let quote = body["quote"] as? String ?? ""
                    webView.annotationEditor.presentEdit(id: id, quote: quote, text: text)
                default:
                    break
                }
            }

            func displayAnnotations(in webView: WKWebView) {
                var annotations: [[String: Any]] = []

                for annotation in self.webView.entry.annotations {
                    let ranges = annotation.rangesArray
                    guard !ranges.isEmpty else {
                        continue
                    }

                    let rangesJSON = ranges.map { range -> [String: Any] in
                        [
                            "start": range.start,
                            "startOffset": range.startOffset,
                            "end": range.end,
                            "endOffset": range.endOffset,
                        ]
                    }

                    annotations.append([
                        "id": annotation.id,
                        "text": annotation.text ?? "",
                        "ranges": rangesJSON,
                    ])
                }

                guard !annotations.isEmpty,
                      let data = try? JSONSerialization.data(withJSONObject: annotations),
                      let json = String(data: data, encoding: .utf8)
                else {
                    return
                }

                webView.evaluateJavaScript("window.__wallinoDisplayAnnotations(\(json))")
            }

            private func parseRanges(_ value: Any?) -> [AnnotationRange] {
                guard let rawRanges = value as? [[String: Any]] else {
                    return []
                }

                return rawRanges.compactMap { raw in
                    guard let start = raw["start"] as? String,
                          let end = raw["end"] as? String
                    else {
                        return nil
                    }

                    return AnnotationRange(
                        start: start,
                        startOffset: intValue(raw["startOffset"]),
                        end: end,
                        endOffset: intValue(raw["endOffset"])
                    )
                }
            }

            private func intValue(_ value: Any?) -> Int {
                if let number = value as? NSNumber {
                    return number.intValue
                }
                if let string = value as? String, let parsed = Int(string) {
                    return parsed
                }
                return 0
            }

            func webViewToLastPosition(in webView: WKWebView) {
                let position = self.webView.entry.screenPositionForWebView
                if position > 0 {
                    // Check if content is actually loaded by verifying contentSize
                    if webView.scrollView.contentSize.height > webView.bounds.height {
                        webView.scrollView.setContentOffset(
                            CGPoint(x: 0.0, y: position),
                            animated: true
                        )
                    } else {
                        // Content not ready yet, try again after a minimal delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            self.webViewToLastPosition(in: webView)
                        }
                    }
                }
            }

            func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
                webView.fontSizePercent(appSetting.webFontSizePercent)
                displayAnnotations(in: webView)
                self.webViewToLastPosition(in: webView)
            }

            func webView(_: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
                guard let urlTarget = navigationAction.request.url else {
                    decisionHandler(.cancel)
                    return
                }

                let urlAbsolute = urlTarget.absoluteString

                if urlAbsolute.hasPrefix(Bundle.main.bundleURL.absoluteString) || urlAbsolute == "about:blank" {
                    decisionHandler(.allow)
                    return
                }

                if navigationAction.targetFrame?.isMainFrame == false {
                    decisionHandler(.allow)
                    return
                }

                let safariController = SFSafariViewController(url: urlTarget)
                safariController.modalPresentationStyle = .overFullScreen

                UIApplication.shared.open(urlTarget, options: [:], completionHandler: nil)
                decisionHandler(.cancel)
            }

            func scrollViewDidScroll(_ scrollView: UIScrollView) {
                let scrollableHeight = scrollView.contentSize.height - scrollView.bounds.height
                if scrollableHeight > 0 {
                    webView.progress = scrollView.contentOffset.y / scrollableHeight
                } else {
                    webView.progress = 0
                }
            }

            func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
                context.perform {
                    self.webView.entry.screenPosition = Float(scrollView.contentOffset.y)
                    try? self.context.save()
                }
            }
        }

        func makeUIView(context: Context) -> WKWebView {
            AnnotationEditMenu.install()

            let userContentController = WKUserContentController()
            userContentController.add(context.coordinator, name: "annotation")

            let configuration = WKWebViewConfiguration()
            configuration.userContentController = userContentController

            let webView = WKWebView(frame: .zero, configuration: configuration)
            webView.navigationDelegate = context.coordinator
            webView.scrollView.delegate = context.coordinator
            webView.isOpaque = false
            webView.backgroundColor = .clear
            webView.scrollView.backgroundColor = .clear
            webView.scrollView.contentInsetAdjustmentBehavior = .always

            context.coordinator.attach(webView)

            webView.load(content: entry.titleHtml + (entry.content ?? ""), justify: UserDefaults.standard.bool(forKey: "justifyArticle"))

            return webView
        }

        func updateUIView(_ webView: WKWebView, context _: Context) {
            webView.fontSizePercent(appSetting.webFontSizePercent)
        }
    }
#endif

#if os(macOS)
    struct WebView: NSViewRepresentable {
        var entry: Entry
        @EnvironmentObject var appSetting: AppSetting
        @Binding var progress: Double

        func makeNSView(context: Context) -> WKWebView {
            let webView = WKWebView(frame: .zero)
            webView.navigationDelegate = context.coordinator
            webView.load(content: entry.titleHtml + (entry.content ?? ""), justify: false)

            return webView
        }

        func updateNSView(_ nsView: WKWebView, context _: Context) {
            nsView.fontSizePercent(appSetting.webFontSizePercent)
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(self, appSetting: appSetting)
        }

        class Coordinator: NSObject, WKNavigationDelegate {
            @CoreDataViewContext var context: NSManagedObjectContext
            var appSetting: AppSetting

            private var webView: WebView

            init(_ webView: WebView, appSetting: AppSetting) {
                self.webView = webView
                self.appSetting = appSetting
                super.init()
            }

            func webViewToLastPosition() {
                /*    DispatchQueue.main.async {
                     self.webView.wkWebView.scrollView.setContentOffset(CGPoint(x: 0.0, y: self.webView.entry.screenPositionForWebView), animated: true)
                 }*/
            }

            func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
                webViewToLastPosition()
                webView.fontSizePercent(appSetting.webFontSizePercent)
            }

            func webView(_: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
                guard let urlTarget = navigationAction.request.url else {
                    decisionHandler(.cancel)
                    return
                }

                let urlAbsolute = urlTarget.absoluteString

                if urlAbsolute.hasPrefix(Bundle.main.bundleURL.absoluteString) || urlAbsolute == "about:blank" {
                    decisionHandler(.allow)
                    return
                }

                if navigationAction.targetFrame?.isMainFrame == false {
                    decisionHandler(.allow)
                    return
                }

                /* let safariController = SFSafariViewController(url: urlTarget)
                 safariController.modalPresentationStyle = .overFullScreen

                 UIApplication.shared.open(urlTarget, options: [:], completionHandler: nil)
                 */
                decisionHandler(.cancel)
            }

            /*
             func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
             context.perform {
             self.webView.entry.screenPosition = Float(scrollView.contentOffset.y)
             try? self.context.save()
             }
             }*/
        }
    }

#endif

//struct WebView_Previews: PreviewProvider {
//    static var entry: Entry = {
//        let entry = Entry()
//        entry.title = "Test"
//        entry.content = "<p>Nice Content</p>"
//        return entry
//    }()
//
//    static var previews: some View {
//        Group {
//            WebView(
//                entry: entry, progress: .constant(0.5)
//            ).environmentObject(AppSetting())
//            .colorScheme(.light)
//            WebView(
//                entry: entry, progress: .constant(0.5)
//            ).environmentObject(AppSetting())
//            .colorScheme(.dark)
//        }
//    }
//}
