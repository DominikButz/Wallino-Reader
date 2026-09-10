import Foundation

public enum WallabagAnnotationEndpoint: WallabagKitEndpoint {
    public typealias Object = WallabagAnnotation

    case get(entry: Int)
    case add(entry: Int, text: String, quote: String, ranges: [AnnotationRange])
    case update(annotation: Int, text: String)
    case delete(annotation: Int)

    public func method() -> HttpMethod {
        switch self {
        case .get:
            .get
        case .add:
            .post
        case .update:
            .put
        case .delete:
            .delete
        }
    }

    public func endpoint() -> String {
        switch self {
        case let .get(entry):
            "/api/annotations/\(entry).json"
        case let .add(entry, _, _, _):
            "/api/annotations/\(entry).json"
        case let .update(annotation, _):
            "/api/annotations/\(annotation).json"
        case let .delete(annotation):
            "/api/annotations/\(annotation).json"
        }
    }

    public func getBody() -> Data {
        switch self {
        case let .add(_, text, quote, ranges):
            let rangesArray = ranges.map { range -> [String: Any] in
                [
                    "start": range.start,
                    "startOffset": range.startOffset,
                    "end": range.end,
                    "endOffset": range.endOffset,
                ]
            }
            let parameters: WallabagKit.Parameters = [
                "text": text,
                "quote": quote,
                "ranges": rangesArray,
            ]
            // swiftlint:disable:next force_try
            return try! JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted)
        case let .update(_, text):
            let parameters: WallabagKit.Parameters = [
                "text": text,
            ]
            // swiftlint:disable:next force_try
            return try! JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted)
        default:
            return "".data(using: .utf8)!
        }
    }

    public func requireAuth() -> Bool {
        true
    }
}
