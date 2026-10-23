import Foundation

public enum WallabagTagEndpoint: WallabagKitEndpoint {
    public typealias Object = WallabagTag

    case get

    public func method() -> HttpMethod {
        .get
    }

    public func endpoint() -> String {
        "/api/tags"
    }

    public func getBody() -> Data {
        Data()
    }

    public func requireAuth() -> Bool {
        true
    }
}
