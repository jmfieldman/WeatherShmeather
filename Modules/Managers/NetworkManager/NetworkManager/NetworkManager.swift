//
//  NetworkManager.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation
@_exported import NetworkModels

/// Every HTTP request goes through here. A caller builds a
/// `NetworkRestResource` and its request, and gets back the decoded response
/// or a `NetworkError`. The implementation composes URL building, the
/// `URLSession` call, status checking, and decoding, and records each call in
/// the in-app network log.
@MainActor
public protocol NetworkManager: AnyObject, Sendable {
    func request<Resource: NetworkRestResource>(
        resource: Resource,
        with request: Resource.Request,
    ) async throws(NetworkError) -> Resource.Response
}

public extension NetworkManager {
    /// A request with no parameters.
    func request<Resource: NetworkRestResource>(
        resource: Resource,
    ) async throws(NetworkError) -> Resource.Response where Resource.Request == EmptyRequest {
        try await request(resource: resource, with: EmptyRequest())
    }
}
