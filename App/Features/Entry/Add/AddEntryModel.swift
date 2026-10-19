import Factory
import Foundation
import HTMLEntities
import Observation
import SharedLib
import SwiftUI

enum AddEntryMode: String, CaseIterable, Identifiable {
    case url
    case text

    var id: String { rawValue }
}

@Observable
final class AddEntryModel {
    @ObservationIgnored
    @Injected(\.wallabagSession) private var session

    var mode: AddEntryMode = .url
    var input: String = ""
    var domainName: String = ""
    var submitting: Bool = false
    var succeeded: Bool = false
    var addedCount: Int = 0

    @MainActor
    func addEntry() async {
        let input = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let domain = domainName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        defer {
            submitting = false
            succeeded = false
            self.input = ""
            self.domainName = ""
        }

        submitting = true
        do {
            var addedEntries: [Entry] = []

            switch mode {
            case .url:
                let urls = input.detectedURLs
                guard !urls.isEmpty else { return }
                for detectedURL in urls {
                    let entry = try await session.addEntry(url: detectedURL.absoluteString)
                    addedEntries.append(entry)
                }
                addedCount = urls.count
            case .text:
                let textEntry = AddEntryModel.textEntry(from: input)
                let entry = try await session.addEntry(
                    title: textEntry.title,
                    content: textEntry.content,
                    url: AddEntryModel.textEntryURL(domainName: domain)
                )
                addedEntries.append(entry)
                addedCount = 1
            }

            succeeded = true
            await autoTag(addedEntries)
            try await Task.sleep(for: .seconds(3))
        } catch {}
    }

    static func textEntry(from text: String) -> (title: String, content: String) {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let lines = normalized.components(separatedBy: "\n")
        let title = lines.first?.trimmingCharacters(in: .whitespaces) ?? ""
        let body = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        let contentSource = body.isEmpty ? title : body

        var paragraphs: [String] = []
        var current: [String] = []
        for line in contentSource.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if !current.isEmpty {
                    paragraphs.append(current.joined(separator: "\n"))
                    current = []
                }
            } else {
                current.append(trimmed)
            }
        }

        if !current.isEmpty {
            paragraphs.append(current.joined(separator: "\n"))
        }

        let content = paragraphs
            .map { paragraph in
                let escaped = paragraph.htmlEscape().replacingOccurrences(of: "\n", with: "<br>")
                return "<p>\(escaped)</p>"
            }
            .joined()

        return (title, content)
    }

    static func normalizedDomainHost(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let components = URLComponents(string: candidate),
              var host = components.host?.trimmingCharacters(in: .whitespacesAndNewlines),
              !host.isEmpty,
              !host.contains(where: { $0.isWhitespace })
        else {
            return nil
        }

        host = host.lowercased()
        while host.hasSuffix(".") {
            host.removeLast()
        }

        return host.isEmpty ? nil : host
    }

    static func textEntryURL(domainName: String) -> String {
        let host = normalizedDomainHost(domainName) ?? "wallino.local"
        return "https://\(host)/text/\(UUID().uuidString)"
    }

    private func autoTag(_ entries: [Entry]) async {
        guard #available(iOS 26.0, macOS 26.0, *) else { return }
        let coordinator = AutoTagCoordinator()
        for entry in entries {
            await coordinator.autoTagNewEntry(entry)
        }
    }
}
