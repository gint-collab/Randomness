//
//  HTTPClient.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/9/26.
//

import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case statusCode(Int)
    case decoding(Error)
    case underlying(Error)

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
protocol EndpointProtocol {
    var baseURL: URL { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var queryItems: [URLQueryItem] { get }
    var headers: [String: String] { get }
    var body: Data? { get }
}

extension EndpointProtocol {
    var method: HTTPMethod { .get }
    var queryItems: [URLQueryItem] { [] }
    var headers: [String: String] { ["Accept": "application/json"] }
    var body: Data? { nil }

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
protocol HTTPClientProtocol: Sendable {
    nonisolated func request<T: Decodable & Sendable>(_ endpoint: EndpointProtocol, as type: T.Type) async throws -> T
}

extension HTTPClientProtocol {
    nonisolated func request<T: Decodable & Sendable>(_ endpoint: EndpointProtocol) async throws -> T {
        try await request(endpoint, as: T.self)
    }
}

/// `URLSession` backed implementation.
struct HTTPClient: HTTPClientProtocol {
    private let session: URLSession
    private let decoder: JSONDecoder

    /// Non-caching session: these endpoints return random payloads for the same
    /// URL, so a cached response would make pull-to-refresh look like a no-op.
    private static let defaultSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }()

    init(session: URLSession = HTTPClient.defaultSession, decoder: JSONDecoder = JSONDecoder()) {
        self.session = session
        self.decoder = decoder
    }

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
