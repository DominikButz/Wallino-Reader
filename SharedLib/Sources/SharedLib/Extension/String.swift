import CryptoKit
import Foundation

public extension String {
    var date: Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"

        return dateFormatter.date(from: self)
    }

    var ucFirst: String {
        let first = String(prefix(1))

        return first.uppercased() + String(dropFirst())
    }

    var lcFirst: String {
        let first = String(prefix(1))

        return first.lowercased() + String(dropFirst())
    }

    var withoutHTML: String {
        replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
    }

    var speakable: [String] {
        replacingOccurrences(of: "<p[^>]+>", with: "<p>", options: .regularExpression, range: nil).components(separatedBy: "<p>").filter { $0.count > 0 }
    }

    var localized: String {
        NSLocalizedString(self, comment: "")
    }

    var url: URL? {
        URL(string: self)
    }

    var md5: String {
        Insecure.MD5.hash(data: data(using: .utf8)!).map {
            String(format: "%02hhx", $0)
        }.joined()
    }

    var NSString: NSString {
        self as NSString
    }

    /**
     * Check if string is valid URL
     */
    var isValidURL: Bool {
        let regEx = "((https|http)://)((\\w|-)+)(([.]|[/]|[:\\d+])((\\w|-)+))+"
        let predicate = NSPredicate(format: "SELF MATCHES %@", argumentArray: [regEx])
        return predicate.evaluate(with: self)
    }

    /**
     * Extracts the web URLs (http/https) contained in the string.
     *
     * Many apps share an article as free text (e.g. "read this: https://…")
     * instead of exposing a bare URL, so the whole text may be pasted into the
     * "Add entry" field. Everything that is not a web link (mail addresses,
     * phone numbers, plain text) is ignored. Domains without a scheme
     * (e.g. "www.example.com") are normalized to https.
     */
    var detectedURLs: [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }

        let range = NSRange(startIndex..., in: self)
        var seen = Set<String>()
        return detector.matches(in: self, options: [], range: range).compactMap { match -> URL? in
            guard let url = match.url else { return nil }

            let detected: URL
            switch url.scheme?.lowercased() {
            case "http", "https":
                let matchedText = (self as NSString).substring(with: match.range)
                detected = matchedText.contains("://") ? url : (URL(string: "https://\(matchedText)") ?? url)
            default:
                return nil
            }

            guard seen.insert(detected.absoluteString).inserted else { return nil }
            return detected
        }
    }

    var int: Int? {
        Int(self)
    }
}
