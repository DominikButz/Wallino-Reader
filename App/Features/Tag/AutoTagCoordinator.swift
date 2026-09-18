import CoreData
import Foundation
import SharedLib

@available(iOS 26.0, macOS 26.0, *)
final class AutoTagCoordinator {
    @CoreDataViewContext var coreDataContext: NSManagedObjectContext

    /// Auto-tags a freshly added entry when it has no tags yet.
    @MainActor
    func autoTagNewEntry(_ entry: Entry) async {
        guard WallabagUserDefaults.autoTagNewEntry, AutoTagService.isAvailable else { return }
        guard entry.tags.isEmpty else { return }

        if case .failed = await AutoTagViewModel().autoTag(entry: entry) {
            enqueue(entry.id)
        }
    }

    /// Processes entries that were added without tags (e.g. from the share
    /// extension) and are waiting to be auto-tagged.
    @MainActor
    func processPendingEntries() async {
        let pending = WallabagUserDefaults.pendingAutoTagEntryIds
        guard !pending.isEmpty else { return }

        guard WallabagUserDefaults.autoTagNewEntry else {
            WallabagUserDefaults.pendingAutoTagEntryIds = []
            return
        }

        guard AutoTagService.isAvailable else {
            // Keep waiting while Apple Intelligence is still preparing its model;
            // drop the queue only when the feature can never run.
            if !AutoTagService.isTemporarilyUnavailable {
                WallabagUserDefaults.pendingAutoTagEntryIds = []
            }
            return
        }

        let viewModel = AutoTagViewModel()
        var remaining: [Int] = []
        for id in pending {
            guard let entry = try? coreDataContext.fetch(Entry.fetchOneById(id)).first else {
                // Not synced yet — keep it around for the next run.
                remaining.append(id)
                continue
            }
            guard entry.tags.isEmpty else { continue }

            if case .failed = await viewModel.autoTag(entry: entry) {
                // Keep it around and retry on the next run.
                remaining.append(id)
            }
        }

        WallabagUserDefaults.pendingAutoTagEntryIds = remaining
    }

    private func enqueue(_ id: Int) {
        var pending = WallabagUserDefaults.pendingAutoTagEntryIds
        guard !pending.contains(id) else { return }
        pending.append(id)
        WallabagUserDefaults.pendingAutoTagEntryIds = pending
    }
}
