import Foundation

public struct AnnotationRange: Codable, Hashable, Sendable {
    public var start: String
    public var startOffset: Int
    public var end: String
    public var endOffset: Int

    public init(start: String, startOffset: Int, end: String, endOffset: Int) {
        self.start = start
        self.startOffset = startOffset
        self.end = end
        self.endOffset = endOffset
    }

    enum CodingKeys: String, CodingKey {
        case start
        case startOffset
        case end
        case endOffset
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        start = (try? container.decode(String.self, forKey: .start)) ?? ""
        end = (try? container.decode(String.self, forKey: .end)) ?? ""
        startOffset = Self.decodeOffset(container, key: .startOffset)
        endOffset = Self.decodeOffset(container, key: .endOffset)
    }

    private static func decodeOffset(_ container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Int {
        if let value = try? container.decode(Int.self, forKey: key) {
            return value
        }
        if let string = try? container.decode(String.self, forKey: key), let value = Int(string) {
            return value
        }
        return 0
    }
}
