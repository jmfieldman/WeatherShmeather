//
//  StubURLProtocol.swift
//  Copyright © 2026 WeatherShmeather.
//

import CocoaEx
import Foundation

/// Serves a `URLSession`'s requests from a closure instead of the network. Each
/// session gets its own closure, so tests running in parallel can't collide.
public final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    public typealias Handler = @Sendable (URLRequest) throws -> (statusCode: Int, body: Data)

    private static let idHeader = "X-Stub-Session-Id"
    private static let handlers = StubHandlers()

    public static func makeSession(handler: @escaping Handler) -> URLSession {
        let id = UUID().lowercaseUUIDString
        handlers.set(handler, for: id)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        configuration.httpAdditionalHeaders = [idHeader: id]
        return URLSession(configuration: configuration)
    }

    /// `URLSession` moves a request's body into a stream before a protocol sees it.
    public static func body(of request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else {
                break
            }

            data.append(buffer, count: count)
        }
        return data
    }

    override public class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override public class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override public func startLoading() {
        guard
            let id = request.value(forHTTPHeaderField: Self.idHeader),
            let handler = Self.handlers.handler(for: id),
            let url = request.url
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }

        do {
            let (statusCode, body) = try handler(request)
            let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override public func stopLoading() {}
}

private final class StubHandlers: @unchecked Sendable {
    private let lock = NSLock()
    private var handlers: [String: StubURLProtocol.Handler] = [:]

    func set(_ handler: @escaping StubURLProtocol.Handler, for id: String) {
        lock.withLock { handlers[id] = handler }
    }

    func handler(for id: String) -> StubURLProtocol.Handler? {
        lock.withLock { handlers[id] }
    }
}
