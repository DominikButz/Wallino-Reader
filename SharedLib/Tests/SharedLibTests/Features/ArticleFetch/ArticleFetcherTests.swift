@testable import SharedLib
import XCTest

final class ArticleFetcherTests: XCTestCase {
    // MARK: - isFetchingError

    func testNilContentIsFetchingError() {
        XCTAssertTrue(ArticleContent.isFetchingError(nil))
    }

    func testEmptyContentIsFetchingError() {
        XCTAssertTrue(ArticleContent.isFetchingError(""))
        XCTAssertTrue(ArticleContent.isFetchingError("   \n"))
    }

    func testWallabagErrorMessageIsFetchingError() {
        let content = """
        wallabag can't retrieve contents for this article. Please \
        <a href="https://doc.wallabag.org/en/user/errors_during_fetching.html#how-can-i-help-to-fix-that">troubleshoot this issue</a>.
        """
        XCTAssertTrue(ArticleContent.isFetchingError(content))
    }

    func testGrabyDefaultErrorMessageIsFetchingError() {
        XCTAssertTrue(ArticleContent.isFetchingError("[unable to retrieve full-text content]"))
    }

    func testDocLinkMarkerIsFetchingError() {
        XCTAssertTrue(ArticleContent.isFetchingError("<a href=\"https://doc.wallabag.org/en/user/errors_during_fetching.html\">help</a>"))
    }

    func testRealContentIsNotFetchingError() {
        XCTAssertFalse(ArticleContent.isFetchingError("<p>Chinas Exportmotor ist ein Zeichen der Schwäche.</p>"))
    }

    // MARK: - Title extraction

    func testExtractsOpenGraphTitle() {
        let html = """
        <html><head>
        <meta property="og:title" content="Logan Wright: Chinas Technologiepolitik">
        <title>Some other title | FAZ</title>
        </head><body></body></html>
        """
        XCTAssertEqual("Logan Wright: Chinas Technologiepolitik", ArticleFetcher.extractTitle(from: html))
    }

    func testExtractsOpenGraphTitleWhenContentComesFirst() {
        let html = "<meta content=\"Content first\" name=\"og:title\">"
        XCTAssertEqual("Content first", ArticleFetcher.extractTitle(from: html))
    }

    func testExtractsTitleTagAsFallback() {
        let html = "<html><head><title>Plain title</title></head></html>"
        XCTAssertEqual("Plain title", ArticleFetcher.extractTitle(from: html))
    }

    func testDecodesHtmlEntitiesInTitle() {
        let html = "<title>Tom &amp; Jerry &quot;Quotes&quot;</title>"
        XCTAssertEqual("Tom & Jerry \"Quotes\"", ArticleFetcher.extractTitle(from: html))
    }

    func testReturnsNilWithoutTitle() {
        XCTAssertNil(ArticleFetcher.extractTitle(from: "<html><body><p>No head</p></body></html>"))
    }

    // MARK: - Shell detection

    func testJavaScriptShellIsUnusable() {
        XCTAssertTrue(ArticleContent.isUnusable(javaScriptShell))
        XCTAssertTrue(ArticleContent.isLikelyJavaScriptShell(javaScriptShell))
    }

    func testJavaScriptShellHasNoVisibleText() {
        XCTAssertEqual("", ArticleContent.visibleText(from: javaScriptShell))
    }

    func testVisibleTextIgnoresScriptsAndTags() {
        let html = """
        <html><body><p>Hello <strong>world</strong></p><script>var text = "hidden";</script></body></html>
        """
        XCTAssertEqual("Hello world", ArticleContent.visibleText(from: html))
    }

    func testRealContentIsUsable() {
        XCTAssertFalse(ArticleContent.isUnusable("<p>Chinas Exportmotor ist ein Zeichen der Schwäche.</p>"))
    }

    func testFetchThrowsNoReadableContentForJavaScriptShell() async {
        MockURLProtocol.responseData = Data(javaScriptShell.utf8)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let fetcher = ArticleFetcher(session: URLSession(configuration: configuration))

        do {
            _ = try await fetcher.fetch(url: "https://example.com/article")
            XCTFail("Expected noReadableContent")
        } catch ArticleFetcher.FetchError.noReadableContent {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchReturnsReadableContent() async throws {
        MockURLProtocol.responseData = Data("<html><body><p>This is a long enough article body for the fetcher to accept.</p></body></html>".utf8)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let fetcher = ArticleFetcher(session: URLSession(configuration: configuration))

        let article = try await fetcher.fetch(url: "https://example.com/article")
        XCTAssertTrue(article.html.contains("long enough article body"))
    }

    private var javaScriptShell: String {
        """
        <html><head>
        <title>PressReader.com - Digital Newspaper & Magazine Subscriptions</title>
        <script>window.serviceUrl = "https://ingress.pressreader.com/services/";</script>
        </head><body>
        <div id="page-skeleton"><svg><path d="M0 0"></path></svg></div>
        <script src="https://r.prcdn.co/scripts/rc/3.73.4-rc0001/app.build.min.js"></script>
        </body></html>
        """
    }
}

private final class MockURLProtocol: URLProtocol {
    static var responseData = Data()

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url,
              let response = HTTPURLResponse(
                  url: url,
                  statusCode: 200,
                  httpVersion: "HTTP/1.1",
                  headerFields: ["Content-Type": "text/html; charset=utf-8"]
              )
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
