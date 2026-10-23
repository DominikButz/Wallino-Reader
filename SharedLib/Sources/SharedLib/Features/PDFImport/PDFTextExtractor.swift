import Foundation
import PDFKit
import Vision

/// Extracts readable text from a PDF on the device and returns it as an HTML
/// fragment, so it can be handed to wallabag as an entry's `content`.
///
/// The extraction uses the PDF's embedded text layer. Pages without any
/// extractable text (for example scans) are run through Vision OCR instead.
public struct PDFTextExtractor {
    public enum ExtractError: Error {
        case unreadable
        case empty
        case noText
    }

    public struct Result: Sendable {
        /// Title from the PDF metadata, if any.
        public let title: String?
        /// The extracted text as an HTML fragment (a sequence of `<p>` elements).
        public let html: String
        /// Total number of pages in the document.
        public let pageCount: Int
        /// `true` when the text was cut off at the extractor's length limit.
        public let truncated: Bool
        /// Character count of the complete extracted text, regardless of truncation.
        public let totalCharacterCount: Int
        /// Character count of the text contained in `html`.
        public let importedCharacterCount: Int

        public init(
            title: String?,
            html: String,
            pageCount: Int,
            truncated: Bool,
            totalCharacterCount: Int,
            importedCharacterCount: Int
        ) {
            self.title = title
            self.html = html
            self.pageCount = pageCount
            self.truncated = truncated
            self.totalCharacterCount = totalCharacterCount
            self.importedCharacterCount = importedCharacterCount
        }
    }

    /// Called with (current page, page count) while the document is converted.
    public typealias ProgressHandler = (Int, Int) -> Void

    private let maxHTMLLength: Int
    private let maxOCRPages: Int

    public init(maxHTMLLength: Int = 400_000, maxOCRPages: Int = 50) {
        self.maxHTMLLength = maxHTMLLength
        self.maxOCRPages = maxOCRPages
    }

    public func extract(from url: URL, progress: ProgressHandler? = nil) throws -> Result {
        guard let document = PDFDocument(url: url) else {
            throw ExtractError.unreadable
        }

        let pageCount = document.pageCount
        guard pageCount > 0 else {
            throw ExtractError.empty
        }

        var paragraphs: [String] = []
        var importedCharacterCount = 0
        var totalCharacterCount = 0
        var truncated = false
        var ocrPages = 0

        for index in 0 ..< pageCount {
            if Task.isCancelled {
                throw CancellationError()
            }

            progress?(index + 1, pageCount)

            guard let page = document.page(at: index) else { continue }
            let pageBounds = page.bounds(for: .mediaBox)

            var lines = PDFTextExtractor.textLines(from: page, pageBounds: pageBounds)
            if PDFTextExtractor.visibleCharacterCount(of: lines) < 30 {
                if ocrPages < maxOCRPages, let ocrLines = PDFTextExtractor.ocrLines(from: page, pageBounds: pageBounds) {
                    ocrPages += 1
                    lines = ocrLines
                }
            }

            for paragraph in PDFTextExtractor.paragraphs(from: lines, pageBounds: pageBounds) {
                totalCharacterCount += paragraph.count
                let html = "<p>\(PDFTextExtractor.escapeHTML(paragraph))</p>"

                if truncated || importedCharacterCount + paragraph.count > maxHTMLLength {
                    truncated = true
                    continue
                }

                paragraphs.append(html)
                importedCharacterCount += paragraph.count
            }
        }

        progress?(pageCount, pageCount)

        let html = paragraphs.joined()
        guard !html.isEmpty else {
            throw ExtractError.noText
        }

        return Result(
            title: PDFTextExtractor.metadataTitle(from: document),
            html: html,
            pageCount: pageCount,
            truncated: truncated,
            totalCharacterCount: totalCharacterCount,
            importedCharacterCount: importedCharacterCount
        )
    }

    // MARK: - Text layer

    struct Line {
        let text: String
        let bounds: CGRect
    }

    static func textLines(from page: PDFPage, pageBounds: CGRect) -> [Line] {
        guard let selection = page.selection(for: pageBounds) else { return [] }

        return selection.selectionsByLine().compactMap { lineSelection in
            guard let text = lineSelection.string?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty
            else {
                return nil
            }

            return Line(text: text, bounds: lineSelection.bounds(for: page))
        }
    }

    private static func metadataTitle(from document: PDFDocument) -> String? {
        let title = document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    // MARK: - Reading order

    static func paragraphs(from lines: [Line], pageBounds: CGRect) -> [String] {
        guard !lines.isEmpty else { return [] }

        let sorted = lines.sorted { lhs, rhs in
            if abs(lhs.bounds.midY - rhs.bounds.midY) > 0.5 * max(lhs.bounds.height, rhs.bounds.height) {
                return lhs.bounds.midY > rhs.bounds.midY
            }
            return lhs.bounds.minX < rhs.bounds.minX
        }

        var blocks: [[Line]] = []
        var block: [Line] = []
        var previous: Line?

        let averageHeight = sorted.reduce(0) { $0 + $1.bounds.height } / CGFloat(max(sorted.count, 1))
        let gapThreshold = max(averageHeight * 0.6, 4)

        for line in sorted {
            if let previous, previous.bounds.minY - line.bounds.maxY > gapThreshold {
                blocks.append(block)
                block = []
            }
            block.append(line)
            previous = line
        }

        if !block.isEmpty {
            blocks.append(block)
        }

        return blocks.flatMap { columns(from: $0, pageBounds: pageBounds) }.map(text(for:))
    }

    /// Splits a vertical block of lines into two columns when the page layout
    /// looks like a two column article. Returns a single column otherwise.
    static func columns(from block: [Line], pageBounds: CGRect) -> [[Line]] {
        guard block.count >= 4, pageBounds.width > 0 else { return [block] }

        let midX = pageBounds.midX
        let left = block.filter { $0.bounds.midX < midX }
        let right = block.filter { $0.bounds.midX >= midX }
        guard left.count >= 2, right.count >= 2 else { return [block] }

        let maxColumnWidth = 0.6 * pageBounds.width
        guard width(of: left) <= maxColumnWidth, width(of: right) <= maxColumnWidth else {
            return [block]
        }

        let leftRange = verticalRange(of: left)
        let rightRange = verticalRange(of: right)
        let overlap = min(leftRange.maxY, rightRange.maxY) - max(leftRange.minY, rightRange.minY)
        let minColumnHeight = min(leftRange.maxY - leftRange.minY, rightRange.maxY - rightRange.minY)
        guard minColumnHeight > 0, overlap > 0.5 * minColumnHeight else { return [block] }

        return [left, right]
    }

    static func text(for lines: [Line]) -> String {
        var text = ""

        for line in lines {
            if text.isEmpty {
                text = line.text
            } else if text.hasSuffix("-"), text.count > 1, line.text.first?.isLowercase == true {
                text.removeLast()
                text += line.text
            } else {
                text += " " + line.text
            }
        }

        return text
    }

    static func visibleCharacterCount(of lines: [Line]) -> Int {
        lines.reduce(0) { $0 + $1.text.count }
    }

    // MARK: - OCR

    static func ocrLines(from page: PDFPage, pageBounds: CGRect) -> [Line]? {
        guard let image = render(page: page, pageBounds: pageBounds) else { return nil }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = recognitionLanguages(for: request)
        if #available(iOS 16.0, macOS 13.0, *) {
            request.automaticallyDetectsLanguage = true
        }

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        guard (try? handler.perform([request])) != nil else { return nil }

        let lines: [Line] = (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first,
                  !candidate.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                return nil
            }

            let box = observation.boundingBox
            let bounds = CGRect(
                x: pageBounds.minX + box.minX * pageBounds.width,
                y: pageBounds.minY + box.minY * pageBounds.height,
                width: box.width * pageBounds.width,
                height: box.height * pageBounds.height
            )

            return Line(text: candidate.string, bounds: bounds)
        }

        return lines.isEmpty ? nil : lines
    }

    private static func render(page: PDFPage, pageBounds: CGRect) -> CGImage? {
        let scale: CGFloat = 2
        let width = max(Int(pageBounds.width * scale), 1)
        let height = max(Int(pageBounds.height * scale), 1)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.saveGState()
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -pageBounds.minX, y: -pageBounds.minY)
        page.draw(with: .mediaBox, to: context)
        context.restoreGState()

        return context.makeImage()
    }

    private static func recognitionLanguages(for request: VNRecognizeTextRequest) -> [String] {
        let preferred = Locale.preferredLanguages
        var supported: [String] = []
        if #available(iOS 15.0, macOS 12.0, *) {
            supported = (try? request.supportedRecognitionLanguages()) ?? []
        }

        let matched = preferred.filter { preferredLanguage in
            let prefix = preferredLanguage.prefix(2).lowercased()
            return supported.contains { $0.lowercased().hasPrefix(prefix) }
        }

        guard matched.isEmpty else { return matched }
        if supported.contains("en-US") {
            return ["en-US"]
        }
        return supported.isEmpty ? ["en-US"] : [supported[0]]
    }

    // MARK: - HTML

    static func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

// MARK: - Column helpers

private extension PDFTextExtractor {
    static func width(of lines: [Line]) -> CGFloat {
        (lines.map(\.bounds.maxX).max() ?? 0) - (lines.map(\.bounds.minX).min() ?? 0)
    }

    static func verticalRange(of lines: [Line]) -> (minY: CGFloat, maxY: CGFloat) {
        let minY = lines.map(\.bounds.minY).min() ?? 0
        let maxY = lines.map(\.bounds.maxY).max() ?? 0
        return (minY, maxY)
    }
}
