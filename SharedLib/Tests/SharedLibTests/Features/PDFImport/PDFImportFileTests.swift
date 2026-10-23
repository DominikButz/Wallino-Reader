import XCTest

@testable import SharedLib

final class PDFImportFileTests: XCTestCase {
    func testIsPDFRecognizesPDFFiles() throws {
        let url = try PDFTestFactory.makeTextPDF(pages: [[
            .init("A page with enough text to be a valid PDF", x: 72, baseline: 700),
        ]])
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(PDFImportFile.isPDF(url))
        XCTAssertFalse(PDFImportFile.isPDF(url.deletingPathExtension().appendingPathExtension("txt")))
    }

    func testIsPDFRejectsNonFileURLs() {
        XCTAssertFalse(PDFImportFile.isPDF(URL(string: "https://example.com/paper.pdf")!))
    }

    func testCopyToTemporaryDirectoryCopiesTheFile() throws {
        let url = try PDFTestFactory.makeTextPDF(pages: [[
            .init("A page with enough text to be a valid PDF", x: 72, baseline: 700),
        ]])
        defer { try? FileManager.default.removeItem(at: url) }

        let copy = try PDFImportFile.copyToTemporaryDirectory(from: url)
        defer { try? FileManager.default.removeItem(at: copy) }

        XCTAssertNotEqual(url, copy)
        XCTAssertTrue(FileManager.default.fileExists(atPath: copy.path))
        XCTAssertTrue(try Data(contentsOf: copy).starts(with: Data("%PDF".utf8)))
    }

    func testCopyRejectsAFileThatOnlyLooksLikeAPDF() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("not-really-\(UUID().uuidString).pdf")
        try "plain text, no pdf header".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try PDFImportFile.copyToTemporaryDirectory(from: url)) { error in
            XCTAssertEqual(error as? PDFImportFile.ImportError, .notAPDF)
        }
    }

    func testCopyRejectsNonPDFFiles() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("notes-\(UUID().uuidString).txt")
        try "some notes".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try PDFImportFile.copyToTemporaryDirectory(from: url)) { error in
            XCTAssertEqual(error as? PDFImportFile.ImportError, .notAPDF)
        }
    }

    func testWriteTemporaryFileWritesPDFData() throws {
        let source = try PDFTestFactory.makeTextPDF(pages: [[
            .init("A page with enough text to be a valid PDF", x: 72, baseline: 700),
        ]])
        defer { try? FileManager.default.removeItem(at: source) }

        let data = try Data(contentsOf: source)
        let url = try PDFImportFile.writeTemporaryFile(from: data)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertEqual(data.count, try Data(contentsOf: url).count)
    }

    func testWriteTemporaryFileRejectsGarbage() {
        XCTAssertThrowsError(try PDFImportFile.writeTemporaryFile(from: Data("garbage".utf8))) { error in
            XCTAssertEqual(error as? PDFImportFile.ImportError, .notAPDF)
        }
    }
}
