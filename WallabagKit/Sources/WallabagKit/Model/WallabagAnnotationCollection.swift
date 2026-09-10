import Foundation

public struct WallabagAnnotationCollection: Decodable, Sendable {
    public let total: Int
    public let rows: [WallabagAnnotation]
}
