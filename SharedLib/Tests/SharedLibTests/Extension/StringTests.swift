import XCTest

class StringTests: XCTestCase {
    func testDateWithWrongFormatReturnNil() {
        XCTAssertNil("".date)
    }

    func testDateWithGoodFormatReturnDate() {
        let date = "2016-11-10T17:34:20+0100".date

        XCTAssertNotNil(date)

        let components = Calendar.current.dateComponents([.hour, .minute, .second, .day, .month, .year], from: date!)

        XCTAssertEqual(2016, components.year)
        XCTAssertEqual(11, components.month)
        XCTAssertEqual(10, components.day)
    }

    func testUcFirst() {
        let string = "test"

        XCTAssertEqual("Test", string.ucFirst)
    }

    func testLcFirst() {
        let string = "Test"

        XCTAssertEqual("test", string.lcFirst)
    }

    func testWithoutHTML() {
        XCTAssertEqual("hello world", "<p>hello world</p>".withoutHTML)
    }

    func testSpeakable() {
        let speakable = "<p>hello world</p><p>Second</p>".speakable
        XCTAssertEqual(2, speakable.count)
    }

    func testURL() {
        XCTAssertNil("".url)
        XCTAssertTrue("https://app.wallabag.it".url != nil)
    }

    func testIsValidURLFalse() {
        XCTAssertFalse("app".isValidURL)
        XCTAssertFalse("https://".isValidURL)
    }

    func testIsValidURL() {
        XCTAssertFalse("app".isValidURL)
        XCTAssertTrue("https://app.wallabag.it".isValidURL)
    }

    func testIsValidURLWithPort() {
        XCTAssertFalse("app".isValidURL)
        XCTAssertTrue("https://app.wallabag.it:9000".isValidURL)
    }

    func testIsValidURLWithPortAndPath() {
        XCTAssertFalse("app".isValidURL)
        XCTAssertTrue("https://app.wallabag.it:9000/wallabag".isValidURL)
    }

    func testDetectedURLsFromPlainText() {
        let text = """
        Liebe Leserin, lieber Leser,

        Ihnen wurde ein interessanter Artikel aus der DieZeit-App empfohlen.

        ————

        https://epaper.zeit.de/article/74821acfca2910591efdae6f601b99c5bd769b8829bedd46aec703bceb56d524

        © Die inhaltlichen Rechte bleiben dem Verlag vorbehalten.
        """

        XCTAssertEqual(
            ["https://epaper.zeit.de/article/74821acfca2910591efdae6f601b99c5bd769b8829bedd46aec703bceb56d524"],
            text.detectedURLs.map(\.absoluteString)
        )
    }

    func testDetectedURLsFromMultipleURLs() {
        let text = "First https://a.example.com/x, second https://b.example.org/y?q=1. Thanks!"

        XCTAssertEqual(
            ["https://a.example.com/x", "https://b.example.org/y?q=1"],
            text.detectedURLs.map(\.absoluteString)
        )
    }

    func testDetectedURLsRemovesDuplicates() {
        let text = "https://a.example.com/x and again https://a.example.com/x"

        XCTAssertEqual(["https://a.example.com/x"], text.detectedURLs.map(\.absoluteString))
    }

    func testDetectedURLsNormalizesSchemeLessDomainToHTTPS() {
        XCTAssertEqual(["https://www.example.com"], "Look at www.example.com now".detectedURLs.map(\.absoluteString))
    }

    func testDetectedURLsIgnoresNonWebLinks() {
        XCTAssertTrue("Mail me at john.doe@example.com".detectedURLs.isEmpty)
        XCTAssertTrue("mailto:john.doe@example.com".detectedURLs.isEmpty)
    }

    func testDetectedURLsWithoutURLReturnsEmpty() {
        XCTAssertTrue("Just some text without any link".detectedURLs.isEmpty)
    }

    func testMD5() {
        if #available(iOS 13.0, *) {
            XCTAssertEqual("098f6bcd4621d373cade4e832627b4f6", "test".md5)
        } else {
            // Fallback on earlier versions
        }
    }

    func testInt() {
        XCTAssertEqual(2, "2".int)
    }
}
