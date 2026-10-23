import CoreGraphics
import CoreText
import XCTest

@testable import SharedLib

/// Builds small PDF files for testing `PDFTextExtractor`.
enum PDFTestFactory {
    struct PlacedLine {
        let text: String
        let x: CGFloat
        let baseline: CGFloat
        let fontSize: CGFloat

        init(_ text: String, x: CGFloat, baseline: CGFloat, fontSize: CGFloat = 12) {
            self.text = text
            self.x = x
            self.baseline = baseline
            self.fontSize = fontSize
        }
    }

    enum Failure: Error {
        case couldNotCreatePDF
    }

    static let pageWidth: CGFloat = 612
    static let pageHeight: CGFloat = 792

    /// Creates a PDF where every page contains the given lines as real text.
    static func makeTextPDF(pages: [[PlacedLine]]) throws -> URL {
        try makePDF(pages: pages, asImages: false)
    }

    /// Creates a PDF whose pages only contain a bitmap rendering of the given
    /// lines, so the document has no extractable text layer.
    static func makeScannedPDF(pages: [[PlacedLine]]) throws -> URL {
        try makePDF(pages: pages, asImages: true)
    }

    private static func makePDF(pages: [[PlacedLine]], asImages: Bool) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pdf-test-\(UUID().uuidString)")
            .appendingPathExtension("pdf")

        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        guard let consumer = CGDataConsumer(url: url as CFURL),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else {
            throw Failure.couldNotCreatePDF
        }

        for lines in pages {
            context.beginPage(mediaBox: &mediaBox)

            if asImages {
                draw(lines: lines, asImageIn: context)
            } else {
                draw(lines: lines, in: context)
            }

            context.endPage()
        }

        context.closePDF()
        return url
    }

    private static func draw(lines: [PlacedLine], in context: CGContext) {
        for line in lines {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: CTFontCreateWithName("Helvetica" as CFString, line.fontSize, nil),
            ]
            let attributedString = NSAttributedString(string: line.text, attributes: attributes)
            let textLine = CTLineCreateWithAttributedString(attributedString)
            context.textPosition = CGPoint(x: line.x, y: line.baseline)
            CTLineDraw(textLine, context)
        }
    }

    /// Renders the lines into a bitmap and stamps that bitmap onto the page.
    private static func draw(lines: [PlacedLine], asImageIn context: CGContext) {
        let scale: CGFloat = 2
        let width = Int(pageWidth * scale)
        let height = Int(pageHeight * scale)
        guard let bitmap = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return
        }

        bitmap.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        bitmap.fill(CGRect(x: 0, y: 0, width: width, height: height))
        bitmap.saveGState()
        bitmap.scaleBy(x: scale, y: scale)
        draw(lines: lines, in: bitmap)
        bitmap.restoreGState()

        guard let image = bitmap.makeImage() else { return }
        context.draw(image, in: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
    }
}

final class PDFTextExtractorTests: XCTestCase {
    private func extract(_ url: URL, maxHTMLLength: Int = 400_000) throws -> PDFTextExtractor.Result {
        try PDFTextExtractor(maxHTMLLength: maxHTMLLength, maxOCRPages: 0).extract(from: url)
    }

    func testExtractsParagraphsInReadingOrder() throws {
        let url = try PDFTestFactory.makeTextPDF(pages: [[
            .init("First paragraph line one", x: 72, baseline: 700),
            .init("line two", x: 72, baseline: 684),
            .init("Second paragraph", x: 72, baseline: 640),
        ]])
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try extract(url)

        XCTAssertEqual(1, result.pageCount)
        XCTAssertNil(result.title)
        XCTAssertFalse(result.truncated)
        XCTAssertEqual(
            "<p>First paragraph line one line two</p><p>Second paragraph</p>",
            result.html
        )
        XCTAssertEqual(result.totalCharacterCount, result.importedCharacterCount)
    }

    func testTwoColumnPageIsReadColumnByColumn() throws {
        let url = try PDFTestFactory.makeTextPDF(pages: [[
            .init("Left column one", x: 72, baseline: 700),
            .init("Right column one", x: 322, baseline: 700),
            .init("Left column two", x: 72, baseline: 684),
            .init("Right column two", x: 322, baseline: 684),
            .init("Left column three", x: 72, baseline: 668),
            .init("Right column three", x: 322, baseline: 668),
            .init("Left column four", x: 72, baseline: 652),
            .init("Right column four", x: 322, baseline: 652),
        ]])
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try extract(url)

        XCTAssertEqual(
            "<p>Left column one Left column two Left column three Left column four</p>" +
                "<p>Right column one Right column two Right column three Right column four</p>",
            result.html
        )
    }

    func testFullWidthBlockIsNotSplitIntoColumns() throws {
        let url = try PDFTestFactory.makeTextPDF(pages: [[
            .init("A heading that spans the full width of the page", x: 72, baseline: 700),
            .init("Left column text one", x: 72, baseline: 640),
            .init("Right column text one", x: 322, baseline: 640),
            .init("Left column text two", x: 72, baseline: 624),
            .init("Right column text two", x: 322, baseline: 624),
        ]])
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try extract(url)

        XCTAssertTrue(result.html.hasPrefix("<p>A heading that spans the full width of the page</p>"))
        XCTAssertTrue(result.html.contains("<p>Left column text one Left column text two</p>"))
        XCTAssertTrue(result.html.contains("<p>Right column text one Right column text two</p>"))
    }

    func testHyphenatedLineBreaksAreJoined() throws {
        let url = try PDFTestFactory.makeTextPDF(pages: [[
            .init("The inter-", x: 72, baseline: 700),
            .init("national committee", x: 72, baseline: 684),
        ]])
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try extract(url)

        XCTAssertEqual("<p>The international committee</p>", result.html)
    }

    func testHTMLOfThePDFTextIsEscaped() throws {
        let url = try PDFTestFactory.makeTextPDF(pages: [[
            .init("Usage of <script> & \"quotes\"", x: 72, baseline: 700),
            .init("more text so the page is not treated as empty", x: 72, baseline: 684),
        ]])
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try extract(url)

        XCTAssertTrue(result.html.contains("Usage of &lt;script&gt; &amp; &quot;quotes&quot;"))
        XCTAssertFalse(result.html.contains("<script>"))
    }

    func testLongDocumentIsTruncated() throws {
        let lines = (0 ..< 10).map { index in
            PDFTestFactory.PlacedLine("Paragraph number \(index) with some filler text", x: 72, baseline: 740 - CGFloat(index) * 40)
        }
        let url = try PDFTestFactory.makeTextPDF(pages: [lines])
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try extract(url, maxHTMLLength: 60)

        XCTAssertTrue(result.truncated)
        XCTAssertGreaterThan(result.totalCharacterCount, result.importedCharacterCount)
        XCTAssertTrue(result.html.contains("Paragraph number 0"))
        XCTAssertFalse(result.html.contains("Paragraph number 9"))
    }

    func testImageOnlyPageWithoutOCRFails() throws {
        let url = try PDFTestFactory.makeScannedPDF(pages: [[
            .init("Scanned headline", x: 72, baseline: 700, fontSize: 24),
            .init("Scanned body text without any text layer", x: 72, baseline: 660, fontSize: 18),
        ]])
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try extract(url)) { error in
            XCTAssertEqual(error as? PDFTextExtractor.ExtractError, .noText)
        }
    }

    func testScannedPageIsReadWithOCR() throws {
        let url = try PDFTestFactory.makeScannedPDF(pages: [[
            .init("Scanned headline", x: 72, baseline: 700, fontSize: 24),
            .init("Scanned body text without any text layer", x: 72, baseline: 660, fontSize: 18),
        ]])
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try PDFTextExtractor(maxOCRPages: 5).extract(from: url)

        XCTAssertTrue(result.html.localizedCaseInsensitiveContains("Scanned headline"))
        XCTAssertTrue(result.html.localizedCaseInsensitiveContains("Scanned body text"))
    }

    func testUnreadableFileThrows() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("not-a-pdf.pdf")
        try? "no pdf at all".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try extract(url)) { error in
            XCTAssertEqual(error as? PDFTextExtractor.ExtractError, .unreadable)
        }
    }

    func testProgressIsReportedPerPage() throws {
        let url = try PDFTestFactory.makeTextPDF(pages: [
            [.init("Page one text with enough characters to be extracted", x: 72, baseline: 700)],
            [.init("Page two text with enough characters to be extracted", x: 72, baseline: 700)],
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        var reported: [(Int, Int)] = []
        _ = try PDFTextExtractor(maxOCRPages: 0).extract(from: url) { page, total in
            reported.append((page, total))
        }

        XCTAssertEqual(3, reported.count)
        XCTAssertEqual(1, reported.first?.0)
        XCTAssertEqual(2, reported.first?.1)
    }
}
