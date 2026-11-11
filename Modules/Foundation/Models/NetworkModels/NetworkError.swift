//
//  NetworkError.swift
//  Copyright © 2026 WeatherShmeather.
//

import Common
import CommonResources
import Foundation

public enum NetworkError: Error, Sendable, CustomDebugStringConvertible {
    /// The request URL couldn't be built.
    case invalidRequestUrl(url: String)

    /// The request's parameters couldn't be encoded as query items.
    case encodableMapping(underlying: Error)

    /// A successful response couldn't be decoded.
    case decodableMapping(underlying: Error, response: HTTPURLResponse)

    /// The response had a non-2xx status. `reason` is Open-Meteo's
    /// `{"error": true, "reason": "…"}` message, when the body has one.
    case statusCode(code: Int, response: HTTPURLResponse, reason: String?)

    /// The response wasn't an HTTP response.
    case unexpectedResponse(response: URLResponse)

    /// `URLSession` failed, such as with no connection.
    case underlying(error: Error)

    public var statusCode: Int? {
        switch self {
        case let .statusCode(code, _, _):
            code
        case let .decodableMapping(_, response):
            response.statusCode
        case let .unexpectedResponse(response):
            (response as? HTTPURLResponse)?.statusCode
        case .invalidRequestUrl, .encodableMapping, .underlying:
            nil
        }
    }

    /// True when the request never reached the server because the device
    /// is offline or the connection dropped.
    public var isConnectivityFailure: Bool {
        guard case let .underlying(error) = self, let urlError = error as? URLError else {
            return false
        }

        return [
            .notConnectedToInternet,
            .networkConnectionLost,
            .timedOut,
            .cannotFindHost,
            .cannotConnectToHost,
            .dataNotAllowed,
        ].contains(urlError.code)
    }

    public var debugDescription: String {
        switch self {
        case let .invalidRequestUrl(url):
            "Invalid request URL: \(url)"
        case let .encodableMapping(underlying):
            "Failed to encode request: \(underlying)"
        case let .decodableMapping(underlying, _):
            "Failed to decode response: \(underlying)"
        case let .statusCode(code, _, reason):
            "HTTP status \(code): \(reason ?? "no reason")"
        case let .unexpectedResponse(response):
            "Unexpected response: \(response)"
        case let .underlying(error):
            "Underlying error: \(error)"
        }
    }
}

extension NetworkError: ErrorDialogProviding {
    public var errorTitle: String {
        .Common.networkError
    }

    public var errorBody: String {
        if isConnectivityFailure {
            return .Common.networkErrorOffline
        }

        if let statusCode, statusCode >= 500 {
            return .Common.networkErrorServer
        }

        return .Common.networkErrorUnexpected
    }
}
