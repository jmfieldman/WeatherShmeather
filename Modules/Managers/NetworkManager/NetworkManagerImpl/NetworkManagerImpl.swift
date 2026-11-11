//
//  NetworkManagerImpl.swift
//  Copyright © 2026 WeatherShmeather.
//

import AppEnvironment
import CocoaEx
import Foundation
import Inject
import Logging
import NetworkManager
import NetworkModels

@MainActor
public final class NetworkManagerImpl: NetworkManager {
    private let appEnvironment: AppEnvironment = Inject()

    /// The network log exists for the admin screen, which App Store builds
    /// can't reach, so they keep no record of their traffic in memory.
    private var networkLogger: NetworkLogger? {
        appEnvironment.app.runEnvironment == .appStore ? nil : .shared
    }

    public init() {}

    public func request<Resource: NetworkRestResource>(
        resource: Resource,
        with params: Resource.Request,
    ) async throws(NetworkError) -> Resource.Response {
        let requestId = UUID().lowercaseUUIDString
        networkLogger?.addOutstanding(
            request: NetworkLog(
                id: requestId,
                service: resource.service.rawValue,
                path: resource.path,
                method: resource.method.rawValue,
            ),
            requestId: requestId,
        )

        do {
            let urlRequest = try URLRequest.build(resource: resource, with: params)
            networkLogger?.setParams(urlRequest.url?.query(percentEncoded: false), requestId: requestId)

            let (data, response) = try await perform(urlRequest)
            networkLogger?.resolveOutstanding(
                requestId: requestId,
                statusCode: response.statusCode,
                responseBody: String(data: data, encoding: .utf8),
                error: nil,
            )
            return try decode(resource: resource, from: data, response: response)
        } catch {
            networkLogger?.resolveOutstanding(
                requestId: requestId,
                statusCode: error.statusCode,
                responseBody: nil,
                error: error.debugDescription,
            )
            Log(.network, .warning, "\(resource.service.rawValue)\(resource.path) failed: \(error.debugDescription)")
            throw error
        }
    }

    private func perform(_ urlRequest: URLRequest) async throws(NetworkError) -> (Data, HTTPURLResponse) {
        let data: Data
        let urlResponse: URLResponse
        do {
            (data, urlResponse) = try await appEnvironment.urlSession.data(for: urlRequest)
        } catch {
            throw .underlying(error: error)
        }

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw .unexpectedResponse(response: urlResponse)
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            throw .statusCode(
                code: httpResponse.statusCode,
                response: httpResponse,
                reason: OpenMeteoErrorBody.reason(from: data),
            )
        }

        return (data, httpResponse)
    }

    private func decode<Resource: NetworkRestResource>(
        resource: Resource,
        from data: Data,
        response: HTTPURLResponse,
    ) throws(NetworkError) -> Resource.Response {
        do {
            return try resource.decodeResponse(from: data)
        } catch {
            throw .decodableMapping(underlying: error, response: response)
        }
    }
}

/// Open-Meteo's error body: `{"error": true, "reason": "…"}`.
private struct OpenMeteoErrorBody: Decodable {
    let reason: String

    static func reason(from data: Data) -> String? {
        try? JSONDecoder().decode(Self.self, from: data).reason
    }
}
