@testable import Wallino_Reader
import XCTest

final class AddEntryModelTests: XCTestCase {
    func testTextEntryUsesFirstLineAsTitle() {
        let text = """
        Article title
        First paragraph line one
        line two

        Second paragraph
        """

        let result = AddEntryModel.textEntry(from: text)

        XCTAssertEqual("Article title", result.title)
        XCTAssertEqual("<p>First paragraph line one<br>line two</p><p>Second paragraph</p>", result.content)
    }

    func testTextEntryEscapesHTML() {
        let result = AddEntryModel.textEntry(from: "Title\n<script>alert(\"x\")</script>")

        XCTAssertEqual("Title", result.title)
        XCTAssertTrue(result.content.contains("&#x3C;script&#x3E;"))
        XCTAssertFalse(result.content.contains("<script>"))
    }

    func testTextEntrySingleLineFallsBackToContent() {
        let result = AddEntryModel.textEntry(from: "Just one line")

        XCTAssertEqual("Just one line", result.title)
        XCTAssertEqual("<p>Just one line</p>", result.content)
    }

    func testTextEntryNormalizesWindowsLineEndings() {
        let result = AddEntryModel.textEntry(from: "Title\r\n\r\nBody")

        XCTAssertEqual("Title", result.title)
        XCTAssertEqual("<p>Body</p>", result.content)
    }

    func testTextEntryTrimsLeadingAndTrailingWhitespace() {
        let result = AddEntryModel.textEntry(from: "  Title  \n\n  Body  ")

        XCTAssertEqual("Title", result.title)
        XCTAssertEqual("<p>Body</p>", result.content)
    }

    func testNormalizedDomainHostAcceptsDomainVariants() {
        XCTAssertEqual("faz.net", AddEntryModel.normalizedDomainHost("faz.net"))
        XCTAssertEqual("faz.net", AddEntryModel.normalizedDomainHost("https://faz.net"))
        XCTAssertEqual("faz.net", AddEntryModel.normalizedDomainHost("http://faz.net"))
        XCTAssertEqual("www.faz.net", AddEntryModel.normalizedDomainHost("www.faz.net"))
        XCTAssertEqual("faz.net", AddEntryModel.normalizedDomainHost("HTTPS://FAZ.NET/path"))
        XCTAssertEqual("faz.net", AddEntryModel.normalizedDomainHost("faz.net:8080"))
    }

    func testNormalizedDomainHostRejectsInvalidInput() {
        XCTAssertNil(AddEntryModel.normalizedDomainHost(""))
        XCTAssertNil(AddEntryModel.normalizedDomainHost("   "))
        XCTAssertNil(AddEntryModel.normalizedDomainHost("https://"))
        XCTAssertNil(AddEntryModel.normalizedDomainHost("not a domain"))
    }

    func testTextEntryURLFallsBackToWallinoLocal() {
        let url = AddEntryModel.textEntryURL(domainName: "")

        XCTAssertTrue(url.hasPrefix("https://wallino.local/text/"))
    }

    func testTextEntryURLUsesPublisherDomain() {
        let url = AddEntryModel.textEntryURL(domainName: "https://www.faz.net")

        XCTAssertTrue(url.hasPrefix("https://www.faz.net/text/"))
    }

    func testTextEntryURLsAreUnique() {
        XCTAssertNotEqual(
            AddEntryModel.textEntryURL(domainName: "faz.net"),
            AddEntryModel.textEntryURL(domainName: "faz.net")
        )
    }

    func testPdfEntryURLFallsBackToWallinoLocal() {
        let url = AddEntryModel.pdfEntryURL(domainName: "")

        XCTAssertTrue(url.hasPrefix("https://wallino.local/pdf/"))
    }

    func testPdfEntryURLUsesPublisherDomain() {
        let url = AddEntryModel.pdfEntryURL(domainName: "https://www.faz.net")

        XCTAssertTrue(url.hasPrefix("https://www.faz.net/pdf/"))
    }

    func testPdfEntryURLsAreUnique() {
        XCTAssertNotEqual(
            AddEntryModel.pdfEntryURL(domainName: "faz.net"),
            AddEntryModel.pdfEntryURL(domainName: "faz.net")
        )
    }

    func testPdfEntryTitleUsesTheEditedTitle() {
        XCTAssertEqual("Edited title", AddEntryModel.pdfEntryTitle("  Edited title  ", fallback: "Detected title"))
    }

    func testPdfEntryTitleFallsBackToTheDetectedTitle() {
        XCTAssertEqual("Detected title", AddEntryModel.pdfEntryTitle("   ", fallback: " Detected title "))
        XCTAssertEqual("Detected title", AddEntryModel.pdfEntryTitle("", fallback: "Detected title"))
    }
}
