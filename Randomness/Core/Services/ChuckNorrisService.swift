//
//  ChuckNorrisService.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/9/26.
//
//  Everything needed to fetch a random Chuck Norris joke from
//  https://api.chucknorris.io: the decoded model, the service abstraction, the
//  endpoint definition and the concrete `HTTPClientProtocol` backed implementation.
//

import Foundation

/// A single joke returned by the Chuck Norris API.
nonisolated struct ChuckNorrisJoke: Decodable, Hashable, Identifiable, Sendable {
    /// Stable identifier assigned by the API, used directly as the `Identifiable` id.
    let id: String
    /// The joke text itself.
    let value: String
    /// Optional avatar image accompanying the joke, decoded from `icon_url`.
    let iconURL: String?

    /// Maps the API's snake-cased `icon_url` onto `iconURL`.
    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case value
        case iconURL = "icon_url"
    }
}

/// Abstraction over the Chuck Norris API.
///
/// Views depend on this rather than on `ChuckNorrisService` directly, so previews
/// and tests can substitute a deterministic double.
protocol ChuckNorrisServiceProtocol {
    /// Fetches a random joke.
    ///
    /// - Returns: A freshly decoded joke.
    /// - Throws: `NetworkError` if the request or decoding fails.
    func randomJoke() async throws -> ChuckNorrisJoke
}

/// Routes exposed by `https://api.chucknorris.io`.
///
/// One case per endpoint, so the base URL and paths live in a single place and
/// tests can assert on the case rather than on a URL string. Inherits `GET`,
/// `Accept: application/json` and an empty body from `EndpointProtocol`.
enum ChuckNorrisEndpoint: EndpointProtocol {
    /// `GET /jokes/random` — returns one random joke.
    case random

    /// Scheme and host for every Chuck Norris route.
    var baseURL: URL { URL(string: "https://api.chucknorris.io")! }

    /// Path appended to `baseURL` for each case.
    var path: String {
        switch self {
        case .random: return "jokes/random"
        }
    }
}

/// `HTTPClientProtocol` backed implementation of `ChuckNorrisServiceProtocol`.
struct ChuckNorrisService: ChuckNorrisServiceProtocol {
    /// Transport used for every request; injected so tests can supply a mock.
    private let client: HTTPClientProtocol

    /// Creates a service.
    ///
    /// - Parameter client: Transport used to perform requests. Pass
    ///   `MockHTTPClient` in tests to stay offline.
    init(client: HTTPClientProtocol) {
        self.client = client
    }

    /// Fetches a random joke from `ChuckNorrisEndpoint.random`.
    ///
    /// The endpoint is genuinely random per call, so no client-side shuffling is
    /// needed to keep refreshes interesting.
    ///
    /// - Returns: A freshly decoded joke.
    /// - Throws: `NetworkError` if the request or decoding fails.
    func randomJoke() async throws -> ChuckNorrisJoke {
        try await client.request(ChuckNorrisEndpoint.random, as: ChuckNorrisJoke.self)
    }
}
