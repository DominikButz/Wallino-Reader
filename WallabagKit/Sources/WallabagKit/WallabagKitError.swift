//
//  WallabagKitError.swift
//  wallabag
//
//  Created by Marinel Maxime on 13/10/2019.
//

import Foundation

public enum WallabagKitError: Error {
    case authenticationRequired
    case serverError
    case invalidApiEndpoint
    case jsonError(json: WallabagJsonError)
    case decodingJSON
    case invalidToken
    case wrap(error: Error)
}

extension WallabagKitError {
    public var isAuthenticationFailure: Bool {
        switch self {
        case .authenticationRequired, .invalidToken:
            return true
        case let .jsonError(json):
            return ["access_denied", "invalid_token", "invalid_grant", "expired_token"].contains(json.error)
        default:
            return false
        }
    }
}

public struct WallabagJsonError: Decodable {
    public let error: String
    public let errorDescription: String
}
