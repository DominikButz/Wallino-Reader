import AppIntents
import CoreData
import Factory
import Foundation
import SharedLib

@available(iOS 18.0, macOS 15.0, *)
struct EntryEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Entry")

    static var defaultQuery = EntryEntityQuery()

    let id: Int

    @Property var title: String
    @Property var url: URL?
    @Property var domainName: String?
    @Property var content: String
    @Property var isArchived: Bool
    @Property var isStarred: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(domainName ?? "")",
            image: .init(systemName: "doc.text")
        )
    }

    init(entry: Entry) {
        id = entry.id
        title = entry.title ?? ""
        url = entry.url.flatMap(URL.init(string:))
        domainName = entry.domainName
        content = String((entry.content?.withoutHTML ?? "").prefix(12000))
        isArchived = entry.isArchived
        isStarred = entry.isStarred
    }
}

@available(iOS 18.0, macOS 15.0, *)
struct EntryEntityQuery: EntityQuery {
    func entities(for identifiers: [EntryEntity.ID]) async throws -> [EntryEntity] {
        let context = Container.shared.coreData().viewContext
        let request = NSFetchRequest<Entry>(entityName: "Entry")
        request.predicate = NSPredicate(format: "id IN %@", identifiers)
        return try await context.perform {
            try context.fetch(request).map { EntryEntity(entry: $0) }
        }
    }

    func suggestedEntities() async throws -> [EntryEntity] {
        let context = Container.shared.coreData().viewContext
        let request = Entry.fetchRequestSorted()
        request.fetchLimit = 20
        return try await context.perform {
            try context.fetch(request).map { EntryEntity(entry: $0) }
        }
    }
}
