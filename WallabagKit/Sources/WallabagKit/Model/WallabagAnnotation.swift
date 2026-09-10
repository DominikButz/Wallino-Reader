import Foundation

public struct WallabagAnnotation: Decodable, Sendable {
    public let id: Int
    public let text: String?
    public let quote: String?
    public let ranges: [AnnotationRange]?
    public let createdAt: String?
    public let updatedAt: String?
    public let user: String?
    public let annotatorSchemaVersion: String?
}
