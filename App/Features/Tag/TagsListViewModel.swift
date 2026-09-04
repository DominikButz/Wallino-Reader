import CoreData
import Foundation

@Observable
final class TagsListViewModel {
    struct TagWithCount: Identifiable {
        let tag: Tag
        let entryCount: Int

        var id: Int { tag.id }
        var label: String { tag.label }
    }

    var tags: [TagWithCount] = []
    var search: String = ""

    var filteredTags: [TagWithCount] {
        guard !search.isEmpty else { return tags }
        return tags.filter { $0.label.localizedCaseInsensitiveContains(search) }
    }

    @ObservationIgnored
    @CoreDataViewContext var coreDataContext: NSManagedObjectContext

    @MainActor
    func load() {
        let fetchedTags = (try? coreDataContext.fetch(Tag.fetchRequestSorted())) ?? []
        tags = fetchedTags.map { tag in
            let fetchRequest = Entry.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "ANY tags == %@", tag)
            let count = (try? coreDataContext.count(for: fetchRequest)) ?? 0
            return TagWithCount(tag: tag, entryCount: count)
        }
    }
}
