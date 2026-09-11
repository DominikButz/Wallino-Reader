import Foundation

public struct WallabagToken: Decodable, Sendable {
    public let accessToken: String
    public let expiresIn: Int
    public let tokenType: String
    public let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken
        case expiresIn
        case tokenType
        case refreshToken
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        expiresIn = (try? container.decode(Int.self, forKey: .expiresIn)) ?? 0
        tokenType = (try? container.decode(String.self, forKey: .tokenType)) ?? "Bearer"
        refreshToken = (try? container.decode(String.self, forKey: .refreshToken)) ?? ""
    }
}
