//
//  NetworkManagerImplTests.swift
//  Copyright © 2026 WeatherShmeather.
//

import AppEnvironment
import AppEnvironmentTestHelpers
import Foundation
import Inject
import NetworkManager
import NetworkManagerImpl
import NetworkManagerTestHelpers
import Testing

private struct ThingRequest: Encodable, Sendable {
    let latitude: Double
    let hourly: [String]
    let pastDays: Int?
    let current: Bool

    enum CodingKeys: String, CodingKey {
        case latitude
        case hourly
        case pastDays = "past_days"
        case current
    }
}

private struct ThingResponse: Decodable, Sendable {
    let id: String
}

private struct GetThingResource: NetworkRestResource {
    typealias Request = ThingRequest
    typealias Response = ThingResponse
    let service: NetworkService = .forecast
    let path = "/v1/thing"
}

/// The requests the stub saw, for assertions after the call finishes.
private final class RequestBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [URLRequest] = []

    var requests: [URLRequest] {
        lock.withLock { stored }
    }

    func append(_ request: URLRequest) {
        lock.withLock { stored.append(request) }
    }
}

@MainActor
struct NetworkManagerImplTests {
    private let request = ThingRequest(latitude: 52.5, hourly: ["temperature_2m", "weather_code"], pastDays: nil, current: true)

    private func makeManager(
        box: RequestBox = RequestBox(),
        handler: @escaping @Sendable (URLRequest) throws -> (statusCode: Int, body: Data),
    ) -> NetworkManagerImpl {
        let session = StubURLProtocol.makeSession { request in
            box.append(request)
            return try handler(request)
        }
        let environment = AppEnvironment.test(urlSession: session)
        InjectionManager.register(AppEnvironment.self) { environment }
        InjectionManager.resetCurrentContainer()
        return NetworkManagerImpl()
    }

    @Test func buildsTheUrlFromTheServiceAndQueryItems() async throws {
        let box = RequestBox()
        let manager = makeManager(box: box) { _ in (200, Data(#"{"id":"a"}"#.utf8)) }

        let response = try await manager.request(resource: GetThingResource(), with: request)

        #expect(response.id == "a")
        let url = try #require(box.requests.first?.url)
        #expect(url.host() == "api.open-meteo.com")
        #expect(url.path() == "/v1/thing")
        // Sorted by key, arrays comma-joined, booleans spelled out, nil left out.
        #expect(url.query(percentEncoded: false) == "current=true&hourly=temperature_2m,weather_code&latitude=52.5")
    }

    @Test func nonSuccessStatusCarriesOpenMeteoReason() async {
        let manager = makeManager { _ in
            (400, Data(#"{"error":true,"reason":"Latitude must be in range"}"#.utf8))
        }

        do {
            _ = try await manager.request(resource: GetThingResource(), with: request)
            Issue.record("Expected a failure")
        } catch {
            guard case let .statusCode(code, _, reason) = error else {
                Issue.record("Unexpected error \(error)")
                return
            }

            #expect(code == 400)
            #expect(reason == "Latitude must be in range")
        }
    }

    @Test func undecodableBodyIsAMappingError() async {
        let manager = makeManager { _ in (200, Data("not json".utf8)) }

        do {
            _ = try await manager.request(resource: GetThingResource(), with: request)
            Issue.record("Expected a failure")
        } catch {
            guard case .decodableMapping = error else {
                Issue.record("Unexpected error \(error)")
                return
            }
        }
    }

    @Test func offlineIsAConnectivityFailure() async {
        let manager = makeManager { _ in throw URLError(.notConnectedToInternet) }

        do {
            _ = try await manager.request(resource: GetThingResource(), with: request)
            Issue.record("Expected a failure")
        } catch {
            #expect(error.isConnectivityFailure)
        }
    }
}
