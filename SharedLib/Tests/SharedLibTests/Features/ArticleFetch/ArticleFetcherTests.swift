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
}
