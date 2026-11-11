//
//  SearchPlacesResource.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation
import NetworkModels
import PlacesManager

/// `GET /v1/search` on Open-Meteo's geocoding API.
struct SearchPlacesResource: NetworkRestResource {
    typealias Request = SearchPlacesRequest
    typealias Response = SearchPlacesResponse
    let service: NetworkService = .geocoding
    let path = "/v1/search"
}

struct SearchPlacesRequest: Encodable, Sendable {
    let name: String
    let count: Int
    let language: String
    let format = "json"
}

/// Mirrors Open-Meteo's response. `results` is missing entirely when nothing matches.
struct SearchPlacesResponse: Decodable, Sendable {
    let results: [Result]?

    struct Result: Decodable, Sendable {
        let id: Int64
        let name: String
        let latitude: Double
        let longitude: Double
        let timezone: String?
        let country: String?
        let admin1: String?
    }
}

extension PlaceSearchResult {
    init(result: SearchPlacesResponse.Result) {
        self.init(
            id: result.id,
            name: result.name,
            region: result.admin1,
            country: result.country,
            latitude: result.latitude,
            longitude: result.longitude,
            timeZone: result.timezone.flatMap(TimeZone.init(identifier:)),
        )
    }
}
