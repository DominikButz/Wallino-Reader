import Foundation
import UniformTypeIdentifiers

/// Prepares a PDF that was picked in the Files app or shared from another app so
/// it can be read after its security-scoped access has been released.
public enum PDFImportFile {
    public enum ImportError: Error {
        /// The file does not look like a PDF.
        case notAPDF
        /// The file could not be read or copied.
        case unreadable
    }

    /// `true` when the URL is a file URL that claims to be a PDF.
    public static func isPDF(_ url: URL) -> Bool {
        guard url.isFileURL else { return false }

        if let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .pdf) {
            return true
        }

        return url.pathExtension.lowercased() == "pdf"
    }

    /// Copies the given file (which may be security scoped) into a temporary
    /// file and verifies that it actually is a PDF.
    public static func copyToTemporaryDirectory(from url: URL) throws -> URL {
        let accessingSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if accessingSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("wallino-pdf-\(UUID().uuidString)")
            .appendingPathExtension("pdf")

        var coordinationError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readableURL in
            do {
                try FileManager.default.copyItem(at: readableURL, to: destination)
            } catch {
                copyError = error
            }
        }

        if let coordinationError {
            throw coordinationError
        }
        if let copyError {
            throw copyError
        }

        guard hasPDFHeader(destination) else {
            try? FileManager.default.removeItem(at: destination)
            throw ImportError.notAPDF
        }

        return destination
    }

    /// Writes PDF data that an app handed over directly (instead of a file URL)
    /// to a temporary file.
    public static func writeTemporaryFile(from data: Data) throws -> URL {
        guard hasPDFHeader(data) else {
            throw ImportError.notAPDF
        }

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("wallino-pdf-\(UUID().uuidString)")
            .appendingPathExtension("pdf")
        try data.write(to: destination, options: .atomic)
        return destination
    }

    private static func hasPDFHeader(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }

        guard let data = try? handle.read(upToCount: 1024) else { return false }
        return hasPDFHeader(data)
    }

    private static func hasPDFHeader(_ data: Data) -> Bool {
        data.prefix(1024).range(of: Data("%PDF".utf8)) != nil
    }
}
