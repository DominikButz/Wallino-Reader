import Foundation

public enum WallabagConfigEndpoint: WallabagKitEndpoint {
    public typealias Object = WallabagConfig

    case get

    public func method() -> HttpMethod {
        .get
    }

    public func endpoint() -> String {
        "/api/config"
    }

    public func getBody() -> Data {
        Data()
    }

    public func requireAuth() -> Bool {
        true
    }
}
