@testable import WallabagKit
import XCTest

final class WallabagKitTests: XCTestCase {
    func testAddEntryBodyIncludesAllProvidedFields() throws {
        let endpoint = WallabagEntryEndpoint.add(
            url: "https://example.com/article",
            title: "A title",
            content: "<p>Hello</p>",
            tags: ["news", "swift"],
            starred: true,
            archived: false
        )

        let json = try body(of: endpoint)

        XCTAssertEqual(json["url"] as? String, "https://example.com/article")
        XCTAssertEqual(json["title"] as? String, "A title")
        XCTAssertEqual(json["content"] as? String, "<p>Hello</p>")
        XCTAssertEqual(json["tags"] as? String, "news,swift")
        XCTAssertEqual(json["starred"] as? Int, 1)
        XCTAssertEqual(json["archive"] as? Int, 0)
    }

    func testAddEntryBodyOmitsEmptyContentAndTitle() throws {
        let endpoint = WallabagEntryEndpoint.add(
            url: "https://example.com/article",
            title: nil,
            content: "",
            tags: [],
            starred: false,
            archived: true
        )

        let json = try body(of: endpoint)

        XCTAssertNil(json["title"])
        XCTAssertNil(json["content"])
        XCTAssertNil(json["tags"])
        XCTAssertEqual(json["archive"] as? Int, 1)
    }

    func testUpdateEntryBodyCarriesContent() throws {
        let endpoint = WallabagEntryEndpoint.update(id: 42, parameters: ["content": "<p>x</p>", "title": "T"])

        XCTAssertEqual(endpoint.method(), .patch)
        XCTAssertEqual(endpoint.endpoint(), "/api/entries/42.json")
        XCTAssertEqual(try body(of: endpoint)["content"] as? String, "<p>x</p>")
    }

    private func body(of endpoint: some WallabagKitEndpoint) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: endpoint.getBody()) as? [String: Any])
    }
}
