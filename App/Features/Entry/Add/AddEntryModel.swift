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
            for detectedURL in urls {
                try await session.addEntry(url: detectedURL.absoluteString)
            }
            addedCount = urls.count
            succeeded = true
            try await Task.sleep(for: .seconds(3))
        } catch {}
    }
}
