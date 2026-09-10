import CoreData
import Factory
import Foundation
import Observation
import SharedLib
import WallabagKit

@Observable
final class AppSync {
    @ObservationIgnored
    @Injected(\.wallabagSession) private var session
    @ObservationIgnored
    @Injected(\.errorHandler) private var errorViewModel
    @ObservationIgnored
    @Injected(\.coreData) private var coreData
    @ObservationIgnored
    @CoreDataViewContext var coreDataContext: NSManagedObjectContext

    private(set) var inProgress = false
    private(set) var progress: Float = 0.0

    @ObservationIgnored
    private lazy var backgroundContext: NSManagedObjectContext = {
        let context = coreData.persistentContainer.newBackgroundContext()
        context.mergePolicy = NSOverwriteMergePolicy
        return context
    }()

    private var entriesSynced: [Int] = []
    private var tags: [Int: Tag] = [:]

    func requestSync() {
        progress = 0
        entriesSynced = []
        Task.detached(priority: .userInitiated) { [unowned self] in
            await synchronizeTags()
            await synchronizeEntries()
            purge()
            await synchronizeAnnotations()
            await MainActor.run {
                self.inProgress = false
            }
        }
        inProgress = true
    }
}

// MARK: - Entry

extension AppSync {
    func synchronizeEntries() async {
        let itemPerPages = WallabagUserDefaults.itemPerPageDuringSync
        let sequence = EntriesFetcher(session.kit, perPage: itemPerPages)
        do {
            for try await data in sequence {
                handleEntries(data.0)
                await MainActor.run {
                    self.progress = data.1
                }
                try backgroundContext.save()
            }
        } catch {
            errorViewModel.setLast(.wallabagKitError(error))
        }
    }

    private func handleEntries(_ wallabagEntries: [WallabagEntry]) {
        for wallabagEntry in wallabagEntries {
            entriesSynced.append(wallabagEntry.id)
            if let entry = try? backgroundContext.fetch(Entry.fetchOneById(wallabagEntry.id)).first {
                update(entry, with: wallabagEntry)
            } else {
                insert(wallabagEntry)
            }
        }
    }

    private func insert(_ wallabagEntry: WallabagEntry) {
        let entry = Entry(context: backgroundContext)
        entry.hydrate(from: wallabagEntry)
        applyTag(from: wallabagEntry, to: entry)
    }

    private func update(_ entry: Entry, with wallabagEntry: WallabagEntry) {
        entry.hydrate(from: wallabagEntry)
        applyTag(from: wallabagEntry, to: entry)
    }

    private func purge() {
        if entriesSynced.count == 0 {
            return
        }

        let fetchRequest = Entry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "NOT (id IN %@)", argumentArray: [entriesSynced])

        do {
            let entriesToDelete = try backgroundContext.fetch(fetchRequest)
            for entryToDelete in entriesToDelete {
                guard let entryToDelete = entryToDelete as? NSManagedObject else { fatalError() }

                backgroundContext.delete(entryToDelete)
            }
            if backgroundContext.hasChanges {
                try backgroundContext.save()
            }
        } catch {
            logger.error("Error in batch delete")
        }
    }

    func refresh(entry: Entry) {
        Task {
            try? await session.refresh(entry: entry)
        }
    }
}

// MARK: - Tag

extension AppSync {
    private func applyTag(from wallabagEntry: WallabagEntry, to entry: Entry) {
        let currentTags = entry.tags
        let newTagIds = Set(wallabagEntry.tags?.map { $0.id } ?? [])

        for wallabagTag in wallabagEntry.tags ?? [] {
            if !currentTags.contains(where: { $0.id == wallabagTag.id }) {
                if let tag = self.tags[wallabagTag.id] {
                    entry.tags.insert(tag)
                }
            }
        }

        for tag in currentTags {
            if !newTagIds.contains(tag.id) {
                entry.tags.remove(tag)
            }
        }
    }

    private func fetchTags() async throws -> [WallabagTag] {
        let request = session.kit.request(for: WallabagTagEndpoint.get, withAuth: true)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try session.kit.decoder.decode([WallabagTag].self, from: data)
    }

    private func synchronizeTags() async {
        do {
            for wallabagTag in try await fetchTags() {
                if let tag = try? backgroundContext.fetch(Tag.fetchOneById(wallabagTag.id)).first {
                    tags[tag.id] = tag
                } else {
                    let tag = Tag(context: backgroundContext)
                    tag.id = wallabagTag.id
                    tag.label = wallabagTag.label
                    tag.slug = wallabagTag.slug
                    tags[wallabagTag.id] = tag
                }
            }
            try backgroundContext.save()
        } catch _ {}
    }
}

// MARK: - Annotation

extension AppSync {
    private func synchronizeAnnotations() async {
        let entries = (try? backgroundContext.fetch(Entry.fetchRequestSorted())) ?? []

        for entry in entries {
            let annotations: [WallabagAnnotation]
            do {
                annotations = try await session.kit.fetchAnnotations(for: entry.id)
            } catch {
                continue
            }
            applyAnnotations(annotations, to: entry)
        }

        if backgroundContext.hasChanges {
            try? backgroundContext.save()
        }
    }

    private func applyAnnotations(_ wallabagAnnotations: [WallabagAnnotation], to entry: Entry) {
        let currentAnnotations = entry.annotations
        let newIds = Set(wallabagAnnotations.map { $0.id })

        for wallabagAnnotation in wallabagAnnotations {
            if let existing = currentAnnotations.first(where: { $0.id == wallabagAnnotation.id }) {
                existing.hydrate(from: wallabagAnnotation)
            } else {
                let annotation = Annotation(context: backgroundContext)
                annotation.hydrate(from: wallabagAnnotation)
                annotation.entry = entry
            }
        }

        let annotationsToDelete = currentAnnotations.filter { !newIds.contains($0.id) }
        for annotation in annotationsToDelete {
            backgroundContext.delete(annotation)
        }
    }
}
