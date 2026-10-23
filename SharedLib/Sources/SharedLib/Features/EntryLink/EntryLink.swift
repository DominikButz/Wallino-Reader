import Foundation

/// Builds the placeholder links and titles for entries that are created from
/// local content (pasted text, imported PDFs) instead of a web page.
///
/// Wallabag does not accept `domain_name` on create or update; the server derives
/// it from the entry URL host. The app (and the share extension) therefore send a
/// fake URL whose host carries the domain the person entered.
public enum EntryLink {
    public enum Kind: String {
        case text
        case pdf
    }

    public static func normalizedHost(_ input: String) -> String? {
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

    public static func fakeURL(domainName: String, kind: Kind) -> String {
        let host = normalizedHost(domainName) ?? "wallino.local"
        return "https://\(host)/\(kind.rawValue)/\(UUID().uuidString)"
    }

    /// The entry title: whatever the person entered, or the detected title when
    /// the field was left empty.
    public static func title(_ title: String, fallback: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }
}
