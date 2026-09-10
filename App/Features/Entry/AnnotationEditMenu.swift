import UIKit
import WebKit

enum AnnotationEditMenu {
    static func install() {
        installOnce
    }

    private static let installOnce: Void = {
        guard let contentViewClass = NSClassFromString("WKContentView") else {
            return
        }

        let selector = NSSelectorFromString("buildMenuWithBuilder:")
        guard let method = class_getInstanceMethod(contentViewClass, selector) else {
            return
        }

        let originalIMP = method_getImplementation(method)

        let block: @convention(block) (AnyObject, AnyObject) -> Void = { contentView, builderObject in
            let original = unsafeBitCast(originalIMP, to: (@convention(c) (AnyObject, Selector, AnyObject) -> Void).self)
            original(contentView, selector, builderObject)

            guard let builder = builderObject as? UIMenuBuilder else {
                return
            }

            let action = UIAction(title: NSLocalizedString("Add annotation", bundle: .main, value: "Add annotation", comment: "")) { _ in
                triggerAnnotation(from: contentView)
            }

            let menu = UIMenu(title: "", options: .displayInline, children: [action])
            builder.insertChild(menu, atEndOfMenu: .standardEdit)
        }

        blockHolder = block
        method_setImplementation(method, imp_implementationWithBlock(block))
    }()

    private static var blockHolder: (@convention(block) (AnyObject, AnyObject) -> Void)?

    private static func triggerAnnotation(from contentView: AnyObject) {
        guard let webView = findWebView(from: contentView) else {
            return
        }

        webView.evaluateJavaScript("window.__wallinoAnnotateSelection()")
    }

    private static func findWebView(from responder: AnyObject) -> WKWebView? {
        var current: UIResponder? = responder as? UIResponder
        while let r = current {
            if let webView = r as? WKWebView {
                return webView
            }
            current = r.next
        }
        return nil
    }
}
