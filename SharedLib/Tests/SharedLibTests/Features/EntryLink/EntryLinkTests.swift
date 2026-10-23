import XCTest

@testable import SharedLib

final class EntryLinkTests: XCTestCase {
    func testNormalizedHostAcceptsDomainVariants() {
        XCTAssertEqual("faz.net", EntryLink.normalizedHost("faz.net"))
        XCTAssertEqual("faz.net", EntryLink.normalizedHost("https://faz.net"))
        XCTAssertEqual("faz.net", EntryLink.normalizedHost("http://faz.net"))
        XCTAssertEqual("www.faz.net", EntryLink.normalizedHost("www.faz.net"))
        XCTAssertEqual("faz.net", EntryLink.normalizedHost("HTTPS://FAZ.NET/path"))
        XCTAssertEqual("faz.net", EntryLink.normalizedHost("faz.net:8080"))
        XCTAssertEqual("faz.net", EntryLink.normalizedHost("faz.net."))
    }

    func testNormalizedHostRejectsInvalidInput() {
        XCTAssertNil(EntryLink.normalizedHost(""))
        XCTAssertNil(EntryLink.normalizedHost("   "))
        XCTAssertNil(EntryLink.normalizedHost("https://"))
        XCTAssertNil(EntryLink.normalizedHost("not a domain"))
    }

    func testFakeURLUsesTheDomainAndKind() {
        XCTAssertTrue(EntryLink.fakeURL(domainName: "faz.net", kind: .pdf).hasPrefix("https://faz.net/pdf/"))
        XCTAssertTrue(EntryLink.fakeURL(domainName: "faz.net", kind: .text).hasPrefix("https://faz.net/text/"))
    }

    func testFakeURLFallsBackToWallinoLocal() {
        XCTAssertTrue(EntryLink.fakeURL(domainName: "", kind: .pdf).hasPrefix("https://wallino.local/pdf/"))
        XCTAssertTrue(EntryLink.fakeURL(domainName: "not a domain", kind: .text).hasPrefix("https://wallino.local/text/"))
    }

    func testFakeURLsAreUnique() {
        XCTAssertNotEqual(
            EntryLink.fakeURL(domainName: "faz.net", kind: .pdf),
            EntryLink.fakeURL(domainName: "faz.net", kind: .pdf)
        )
    }

    func testTitleUsesTheEditedValue() {
        XCTAssertEqual("Edited", EntryLink.title("  Edited  ", fallback: "Detected"))
    }

    func testTitleFallsBackWhenEmpty() {
        XCTAssertEqual("Detected", EntryLink.title("   ", fallback: " Detected "))
        XCTAssertEqual("", EntryLink.title("", fallback: ""))
    }
}
