//
//  URLRequest+Build.swift
//  Copyright © 2026 WeatherShmeather.
//

import Foundation
import NetworkModels

extension URLRequest {
    /// Builds a request from a resource. The request's parameters become
    /// query items in key order. An array becomes one comma-separated value,
    /// which is how Open-Meteo takes its variable lists, such as
    /// `hourly=temperature_2m,weather_code`. A `nil` parameter is left out.
    static func build<Resource: NetworkRestResource>(
        resource: Resource,
        with params: Resource.Request,
    ) throws(NetworkError) -> URLRequest {
        guard let baseUrl = resource.url else {
            throw .invalidRequestUrl(url: "\(resource.service.baseUrl)\(resource.path)")
        }

        let queryItems: [URLQueryItem]
        do {
            queryItems = try Self.queryItems(from: params)
        } catch {
            throw .encodableMapping(underlying: error)
        }

        var request = URLRequest(
            url: queryItems.isEmpty ? baseUrl : baseUrl.appending(queryItems: queryItems),
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: resource.timeoutInterval,
        )
        request.httpMethod = resource.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private static func queryItems(from params: some Encodable) throws -> [URLQueryItem] {
        let data = try JSONEncoder().encode(params)
        guard let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw EncodingError.invalidValue(
                params,
                EncodingError.Context(codingPath: [], debugDescription: "Request parameters must encode as an object"),
            )
        }

        return dictionary
            .sorted { $0.key < $1.key }
            .compactMap { key, value in
                if value is NSNull {
                    return nil
                }

                if let array = value as? [Any] {
                    return URLQueryItem(name: key, value: array.map(queryValue).joined(separator: ","))
                }

                return URLQueryItem(name: key, value: queryValue(value))
            }
    }

    private static func queryValue(_ value: Any) -> String {
        // JSONSerialization hands back booleans as NSNumber, so check the
        // boolean type explicitly or `true` would become "1".
        if let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() {
            return number.boolValue ? "true" : "false"
        }

        return String(describing: value)
    }
}
