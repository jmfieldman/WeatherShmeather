//
//  MockNetworkManager.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation
import NetworkManager

/// Answers requests from per-resource stubs and records what was asked.
@MainActor
public final class MockNetworkManager: NetworkManager {
    public private(set) var requestedPaths: [String] = []
    private var stubs: [ObjectIdentifier: Any] = [:]
    private var delays: [ObjectIdentifier: Duration] = [:]

    public init() {}

    public func stub<Resource: NetworkRestResource>(
        _ type: Resource.Type,
        handler: @escaping (Resource, Resource.Request) throws(NetworkError) -> Resource.Response,
    ) {
        stubs[ObjectIdentifier(type)] = handler
    }

    /// Holds this resource's responses back, to test one landing after another.
    public func delay(_ type: (some NetworkRestResource).Type, by duration: Duration) {
        delays[ObjectIdentifier(type)] = duration
    }

    public func request<Resource: NetworkRestResource>(
        resource: Resource,
        with params: Resource.Request,
    ) async throws(NetworkError) -> Resource.Response {
        if let delay = delays[ObjectIdentifier(Resource.self)] {
            try? await Task.sleep(for: delay)
        }

        requestedPaths.append(resource.path)

        typealias Handler = (Resource, Resource.Request) throws(NetworkError) -> Resource.Response
        guard let handler = stubs[ObjectIdentifier(Resource.self)] as? Handler else {
            fatalError("No stub for \(Resource.self)")
        }

        return try handler(resource, params)
    }
}
