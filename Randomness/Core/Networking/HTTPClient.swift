//
//  HTTPClient.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/9/26.
//
//  The app's networking layer, in three pieces:
//
//  1. `EndpointProtocol` — a declarative description of a single request, which
//     knows how to turn itself into a `URLRequest`.
//  2. `HTTPClientProtocol` — the seam the rest of the app depends on, so services
//     can be unit tested with `MockHTTPClient` instead of real traffic.
//  3. `HTTPClient` — the `URLSession` backed implementation that performs the
//     request, validates the response and decodes the payload.
//
//  Every failure surfaces as a `NetworkError`, so callers never have to reason
//  about raw `URLError`s or `DecodingError`s.
//

import Foundation

/// HTTP verbs supported by `EndpointProtocol`.
///
/// The raw value is written straight into `URLRequest.httpMethod`.
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

/// Every error the networking layer can produce.
///
/// `HTTPClient` funnels all failures into these cases so callers can present a
/// message via `errorDescription` without inspecting the underlying framework error.
enum NetworkError: LocalizedError {
    /// The endpoint's components could not be assembled into a valid `URL`.
    case invalidURL
    /// The response was not an `HTTPURLResponse`.
    case invalidResponse
    /// The request completed but returned a non-2xx status code.
    case statusCode(Int)
    /// The body could not be decoded into the requested type.
    case decoding(Error)
    /// The transport itself failed, e.g. no connectivity or a timeout.
    case underlying(Error)

    /// A user-facing description, suitable for display in an alert.
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The request URL is invalid."
        case .invalidResponse: return "The server returned an invalid response."
        case .statusCode(let code): return "Request failed with status code \(code)."
        case .decoding: return "Unable to read the server response."
        case .underlying(let error): return error.localizedDescription
        }
    }
}

/// Describes a single API request.
///
/// Conforming types are usually enums — one case per route — which keeps every
/// URL for a given API in one place and lets tests match on the case rather than
/// on a string. Only `baseURL` and `path` are required; the remaining
/// requirements have sensible defaults.
protocol EndpointProtocol {
    /// Scheme and host, e.g. `https://api.thecatapi.com`.
    var baseURL: URL { get }
    /// Path appended to `baseURL`, e.g. `v1/images/search`.
    var path: String { get }
    /// HTTP verb. Defaults to `.get`.
    var method: HTTPMethod { get }
    /// Query string items. Defaults to none.
    var queryItems: [URLQueryItem] { get }
    /// Header fields. Defaults to `Accept: application/json`.
    var headers: [String: String] { get }
    /// Request body. Defaults to `nil`.
    var body: Data? { get }
}

extension EndpointProtocol {
    /// Defaults to a `GET` request.
    var method: HTTPMethod { .get }
    /// Defaults to no query string.
    var queryItems: [URLQueryItem] { [] }
    /// Defaults to requesting JSON.
    var headers: [String: String] { ["Accept": "application/json"] }
    /// Defaults to an empty body.
    var body: Data? { nil }

    /// Assembles the endpoint into a `URLRequest`.
    ///
    /// `queryItems` are only attached when non-empty, which avoids a stray `?`
    /// on URLs that take no parameters.
    ///
    /// - Returns: A request carrying the endpoint's method, headers and body.
    /// - Throws: `NetworkError.invalidURL` if the components cannot form a valid URL.
    func urlRequest() throws -> URLRequest {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )
        if !queryItems.isEmpty { components?.queryItems = queryItems }

        guard let url = components?.url else { throw NetworkError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        return request
    }
}

/// Abstraction over the network layer, allowing mocks in tests and previews.
///
/// Services depend on this rather than on `HTTPClient` directly, so a test can
/// inject `MockHTTPClient` and drive them entirely offline.
protocol HTTPClientProtocol: Sendable {
    /// Performs `endpoint` and decodes the response body.
    ///
    /// - Parameters:
    ///   - endpoint: Request to perform.
    ///   - type: Type to decode the response body into.
    /// - Returns: The decoded value.
    /// - Throws: `NetworkError` describing the transport, status or decoding failure.
    nonisolated func request<T: Decodable & Sendable>(_ endpoint: EndpointProtocol, as type: T.Type) async throws -> T
}

extension HTTPClientProtocol {
    /// Convenience overload that infers the decoded type from the call site,
    /// e.g. `let joke: ChuckNorrisJoke = try await client.request(.random)`.
    ///
    /// - Parameter endpoint: Request to perform.
    /// - Returns: The decoded value.
    /// - Throws: `NetworkError` describing the transport, status or decoding failure.
    nonisolated func request<T: Decodable & Sendable>(_ endpoint: EndpointProtocol) async throws -> T {
        try await request(endpoint, as: T.self)
    }
}

/// `URLSession` backed implementation.
struct HTTPClient: HTTPClientProtocol {
    /// Session used to perform requests; injectable so tests can supply a
    /// `URLProtocol` stub.
    private let session: URLSession
    /// Decoder applied to every response body.
    private let decoder: JSONDecoder

    /// Non-caching session: these endpoints return random payloads for the same
    /// URL, so a cached response would make pull-to-refresh look like a no-op.
    private static let defaultSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }()

    /// Creates a client.
    ///
    /// - Parameters:
    ///   - session: Session used for requests. Defaults to a shared ephemeral,
    ///     cache-free session.
    ///   - decoder: Decoder for response bodies. Supply a configured decoder to
    ///     change key or date strategies.
    init(session: URLSession = HTTPClient.defaultSession, decoder: JSONDecoder = JSONDecoder()) {
        self.session = session
        self.decoder = decoder
    }

    /// Performs `endpoint`, validates the response and decodes the body.
    ///
    /// The request bypasses the cache so repeated calls to the same random
    /// endpoint return fresh content.
    ///
    /// - Parameters:
    ///   - endpoint: Request to perform.
    ///   - type: Type to decode the response body into.
    /// - Returns: The decoded value.
    /// - Throws: `NetworkError.underlying` if the transport fails,
    ///   `NetworkError.invalidResponse` if the response is not HTTP,
    ///   `NetworkError.statusCode` for a non-2xx status, or
    ///   `NetworkError.decoding` if the body does not match `type`.
    nonisolated func request<T: Decodable & Sendable>(_ endpoint: EndpointProtocol, as type: T.Type) async throws -> T {
        var request = try endpoint.urlRequest()
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw NetworkError.underlying(error)
        }

        guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw NetworkError.statusCode(http.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decoding(error)
        }
    }
}
