//
//  NetworkRestResource.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation

/// An empty request type, for an endpoint that takes no parameters.
public struct EmptyRequest: Encodable, Sendable {
    public init() {}
}

/// An empty response type, for an endpoint whose body is ignored.
public struct EmptyResponse: Decodable, Sendable {
    public init() {}
}

/// HTTP methods supported by the network manager. Open-Meteo is read-only,
/// so only GET is needed.
public enum NetworkHTTPMethod: String, Codable, Sendable {
    case get = "GET"
}

/// One endpoint: its method, service, path, and two bespoke wire types.
///
/// A resource's `Request` is encoded as query items, and its `Response` is
/// decoded from JSON. Both types are private to the manager Impl that owns
/// the resource and mirror Open-Meteo's parameters and JSON field for field.
public protocol NetworkRestResource: Sendable {
    /// The parameters, encoded as query items.
    associatedtype Request: Encodable & Sendable

    /// The decoded response body.
    associatedtype Response: Decodable & Sendable

    var method: NetworkHTTPMethod { get }

    var service: NetworkService { get }

    /// The path after the service's base URL, including the version, such as
    /// `/v1/forecast`.
    var path: String { get }

    var timeoutInterval: TimeInterval { get }

    /// Turns a successful response's body into `Response`. JSON by default.
    func decodeResponse(from data: Data) throws -> Response
}

public extension NetworkRestResource {
    var method: NetworkHTTPMethod {
        .get
    }

    var timeoutInterval: TimeInterval {
        30
    }

    var url: URL? {
        URL(string: "\(service.baseUrl)\(path)")
    }

    func decodeResponse(from data: Data) throws -> Response {
        try JSONDecoder().decode(Response.self, from: data)
    }
}
