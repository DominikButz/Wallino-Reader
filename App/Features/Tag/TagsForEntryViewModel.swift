import CoreData
import Factory
import Foundation

@Observable
final class TagsForEntryViewModel {
    @ObservationIgnored
    @Injected(\.wallabagSession) private var session

    var selectedTags: [Tag] = []
    var availableTags: [Tag] = []
    var isLoading = false

    @ObservationIgnored
    @CoreDataViewContext var coreDataContext: NSManagedObjectContext

    @MainActor
    func load(for entry: Entry) async {
        let allTags = (try? coreDataContext.fetch(Tag.fetchRequestSorted())) ?? []
        let entryTagIds = Set(entry.tags.map { $0.id })
        selectedTags = allTags.filter { entryTagIds.contains($0.id) }
        availableTags = allTags.filter { !entryTagIds.contains($0.id) }
    }

    func toggle(tag: Tag, for entry: Entry) async {
        defer {
            isLoading = false
        }
        isLoading = true
        if selectedTags.contains(where: { $0.id == tag.id }) {
            await delete(tag: tag, for: entry)
        } else {
            await add(tag: tag.label, for: entry)
        }
        await load(for: entry)
    }

    func add(tag: String, for entry: Entry) async {
        try? await session.add(tag: tag, for: entry)
        await load(for: entry)
    }

    private func delete(tag: Tag, for entry: Entry) async {
        try? await session.delete(tag: tag, for: entry)
    }
}
