//
//  ServiceTests.swift
//  RandomnessTests
//
//  Created by Septuagint Murito on 8/11/26.
//

import Foundation
import Testing
@testable import Randomness

/// Demonstrates why `MockHTTPClient` exists: the services only depend on
/// `HTTPClientProtocol`, so they can be tested without any networking.
@Suite("Services + MockHTTPClient")
@MainActor
struct ServiceTests {

    // MARK: ChuckNorrisService

    @Test("randomJoke returns the decoded joke")
    func chuckNorrisReturnsJoke() async throws {
        let joke = ChuckNorrisJoke(id: "1", value: "Chuck Norris counted to infinity. Twice.", iconURL: nil)
        let sut = ChuckNorrisService(client: MockHTTPClient(value: joke))

        let result = try await sut.randomJoke()

        #expect(result == joke)
    }

    @Test("randomJoke propagates client errors")
    func chuckNorrisPropagatesError() async throws {
        let sut = ChuckNorrisService(client: MockHTTPClient(error: NetworkError.statusCode(500)))

        await #expect(throws: NetworkError.self) {
            _ = try await sut.randomJoke()
        }
    }

    @Test("randomJoke hits the Chuck Norris random endpoint")
    func chuckNorrisUsesRandomEndpoint() async throws {
        let joke = ChuckNorrisJoke(id: "1", value: "joke", iconURL: nil)
        let seen = EndpointRecorder()
        let sut = ChuckNorrisService(client: MockHTTPClient { endpoint in
            seen.record(endpoint)
            return joke
        })

        _ = try await sut.randomJoke()

        #expect(seen.chuckNorrisCases.count == 1)
        guard case .random = seen.chuckNorrisCases.first else {
            Issue.record("Expected .random, got \(seen.chuckNorrisCases)")
            return
        }
    }

    // MARK: CatService

    @Test("randomFact returns the decoded fact")
    func catReturnsFact() async throws {
        let fact = CatFact(fact: "Cats sleep 70% of their lives.", length: 30)
        let sut = CatService(client: MockHTTPClient(value: fact))

        let result = try await sut.randomFact()

        #expect(result == fact)
    }

    @Test("images requests the search endpoint with the requested limit")
    func catRequestsImagesWithLimit() async throws {
        let images = [CatImage(id: "abc", url: "https://cdn2.thecatapi.com/images/abc.jpg", width: 100, height: 50)]
        let seen = EndpointRecorder()
        let sut = CatService(client: MockHTTPClient { endpoint in
            seen.record(endpoint)
            return images
        })

        let result = try await sut.images(limit: 7)

        #expect(result == images)
        #expect(seen.catImageCases.count == 1)
        guard case .search(let limit) = seen.catImageCases.first else {
            Issue.record("Expected .search, got \(seen.catImageCases)")
            return
        }
        #expect(limit == 7)
    }

    @Test("images propagates client errors")
    func catPropagatesError() async throws {
        let sut = CatService(client: MockHTTPClient(error: NetworkError.invalidResponse))

        await #expect(throws: NetworkError.self) {
            _ = try await sut.images(limit: 1)
        }
    }
}

// MARK: - Helpers

/// Records the endpoints a service asks for, so tests can assert on routing.
///
/// Endpoint *properties* are main-actor isolated, so the `@Sendable` stub closure
/// matches on the enum cases instead of reading `path`/`queryItems` directly.
private final class EndpointRecorder: @unchecked Sendable {
    private(set) var catCases: [CatEndpoint] = []
    private(set) var catImageCases: [CatImageEndpoint] = []
    private(set) var chuckNorrisCases: [ChuckNorrisEndpoint] = []

    func record(_ endpoint: EndpointProtocol) {
        switch endpoint {
        case let endpoint as CatEndpoint: catCases.append(endpoint)
        case let endpoint as CatImageEndpoint: catImageCases.append(endpoint)
        case let endpoint as ChuckNorrisEndpoint: chuckNorrisCases.append(endpoint)
        default: break
        }
    }
}
