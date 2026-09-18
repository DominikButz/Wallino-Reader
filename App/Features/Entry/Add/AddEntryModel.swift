import Factory
import Foundation
import Observation
import SharedLib
import SwiftUI

@Observable
final class AddEntryModel {
    @ObservationIgnored
    @Injected(\.wallabagSession) private var session

    var url: String = ""
    var submitting: Bool = false
    var succeeded: Bool = false
    var addedCount: Int = 0

    @MainActor
    func addEntry() async {
        let urls = url.detectedURLs
        guard !urls.isEmpty else { return }

        defer {
            submitting = false
            succeeded = false
            url = ""
        }

        submitting = true
        do {
            var addedEntries: [Entry] = []
            for detectedURL in urls {
                let entry = try await session.addEntry(url: detectedURL.absoluteString)
                addedEntries.append(entry)
            }
            addedCount = urls.count
            succeeded = true
            await autoTag(addedEntries)
            try await Task.sleep(for: .seconds(3))
        } catch {}
    }

    private func autoTag(_ entries: [Entry]) async {
        guard #available(iOS 26.0, macOS 26.0, *) else { return }
        let coordinator = AutoTagCoordinator()
        for entry in entries {
            await coordinator.autoTagNewEntry(entry)
        }
    }
}
