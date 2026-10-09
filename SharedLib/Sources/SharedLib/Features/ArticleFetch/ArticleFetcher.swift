import Foundation

/// Result of fetching an article's HTML from the device.
public struct FetchedArticle {
    /// Title scraped from `og:title` or the `<title>` tag, if any.
    public let title: String?
    /// The raw HTML of the page, ready to be handed to wallabag as `content`.
    public let html: String

    public init(title: String?, html: String) {
        self.title = title
        self.html = html
    }
}

/// Detects wallabag's "content could not be retrieved" placeholder so the app
/// can fall back to fetching the article on the device.
public enum ArticleContent {
    public static func isFetchingError(_ content: String?) -> Bool {
        guard let content, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return true
        }

        let markers = [
            "can't retrieve contents",
            "unable to retrieve full-text content",
            "errors_during_fetching",
        ]

        return markers.contains { content.localizedCaseInsensitiveContains($0) }
    }
}

/// Fetches an article's HTML directly from the device, using a browser-like
/// User-Agent. Wallabag can then run its own extraction on the provided HTML,
/// which sidesteps server-side fetching problems (anti-bot walls, paywalls,
/// stale site configurations).
public struct ArticleFetcher {
    public enum FetchError: Error {
        case invalidURL
        case decodingFailed
        case emptyResponse
    }

    private let session: URLSession

    public init(session: URLSession? = nil) {
        self.session = session ?? ArticleFetcher.makeSession()
    }

    public func fetch(url: String) async throws -> FetchedArticle {
        guard let target = URL(string: url.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = target.scheme?.lowercased(), scheme == "http" || scheme == "https"
        else {
            throw FetchError.invalidURL
        }

        var request = URLRequest(url: target)
        request.timeoutInterval = 30
        request.setValue(ArticleFetcher.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue(Locale.preferredLanguages.joined(separator: ","), forHTTPHeaderField: "Accept-Language")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, !(200 ..< 400).contains(httpResponse.statusCode) {
            throw FetchError.emptyResponse
        }

        guard !data.isEmpty else {
            throw FetchError.emptyResponse
        }

        let html = responseTextEncoding(from: response).flatMap { String(data: data, encoding: $0) }
            ?? String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)

        guard let html, !html.isEmpty else {
            throw FetchError.decodingFailed
        }

        return FetchedArticle(title: ArticleFetcher.extractTitle(from: html), html: html)
    }

    // MARK: - Helpers

    private static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        return URLSession(configuration: configuration)
    }

    private func responseTextEncoding(from response: URLResponse) -> String.Encoding? {
        guard let httpResponse = response as? HTTPURLResponse,
              let name = httpResponse.textEncodingName
        else {
            return nil
        }

        return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringConvertIANACharSetNameToEncoding(name as CFString)))
    }

    static func extractTitle(from html: String) -> String? {
        if let ogTitle = firstMatch(in: html, pattern: "<meta[^>]+(?:property|name)=[\"']og:title[\"'][^>]+content=[\"']([^\"']+)[\"']"),
           let decoded = decodeEntities(ogTitle), !decoded.isEmpty {
            return decoded
        }

        if let metaTitle = firstMatch(in: html, pattern: "<meta[^>]+content=[\"']([^\"']+)[\"'][^>]+(?:property|name)=[\"']og:title[\"']"),
           let decoded = decodeEntities(metaTitle), !decoded.isEmpty {
            return decoded
        }

        if let title = firstMatch(in: html, pattern: "<title[^>]*>(.*?)</title>"),
           let decoded = decodeEntities(title), !decoded.isEmpty {
            return decoded
        }

        return nil
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let matchRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }

        return String(text[matchRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeEntities(_ text: String) -> String? {
        let decoded = text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&#8217;", with: "'")
            .replacingOccurrences(of: "&#8216;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return decoded.isEmpty ? nil : decoded
    }
}
