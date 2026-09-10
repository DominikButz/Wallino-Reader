import CoreData
import Foundation
import SharedLib
import WallabagKit

class Annotation: NSManagedObject, Identifiable {}

extension Annotation {
    @nonobjc class func fetchRequestSorted() -> NSFetchRequest<Annotation> {
        let fetchRequest = NSFetchRequest<Annotation>(entityName: "Annotation")
        let sortDescriptor = NSSortDescriptor(key: "id", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        return fetchRequest
    }

    @nonobjc class func fetchOneById(_ id: Int) -> NSFetchRequest<Annotation> {
        let fetchRequest = NSFetchRequest<Annotation>(entityName: "Annotation")
        fetchRequest.predicate = NSPredicate(format: "id == %ld", id)
        return fetchRequest
    }

    @NSManaged dynamic var id: Int
    @NSManaged dynamic var text: String?
    @NSManaged dynamic var quote: String?
    @NSManaged dynamic var ranges: Data?
    @NSManaged dynamic var createdAt: Date?
    @NSManaged dynamic var updatedAt: Date?
    @NSManaged dynamic var entry: Entry?
}

extension Annotation {
    var rangesArray: [AnnotationRange] {
        get {
            guard let ranges, let decoded = try? JSONDecoder().decode([AnnotationRange].self, from: ranges) else {
                return []
            }
            return decoded
        }
        set {
            ranges = try? JSONEncoder().encode(newValue)
        }
    }

    func hydrate(from annotation: WallabagAnnotation) {
        id = annotation.id
        text = annotation.text
        quote = annotation.quote
        rangesArray = annotation.ranges ?? []
        createdAt = annotation.createdAt.flatMap { Date.fromISOString($0) }
        updatedAt = annotation.updatedAt.flatMap { Date.fromISOString($0) }
    }
}
