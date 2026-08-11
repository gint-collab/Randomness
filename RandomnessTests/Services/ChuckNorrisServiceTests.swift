//
//  ChuckNorrisServiceTests.swift
//  RandomnessTests
//
//  Created by Septuagint Murito on 8/11/26.
//

import Foundation
import Testing
@testable import Randomness

private func makeJoke(
    id: String = "1",
    value: String = "Chuck Norris counted to infinity. Twice.",
    iconURL: String? = nil
) -> ChuckNorrisJoke {
    ChuckNorrisJoke(id: id, value: value, iconURL: iconURL)
}

/// Unit tests for `ChuckNorrisService`, driven entirely through `MockHTTPClient`.
@Suite("ChuckNorrisService")
@MainActor
struct ChuckNorrisServiceTests {

    // MARK: randomJoke

    @Test("randomJoke returns the decoded joke")
    func randomJokeReturnsDecodedJoke() async throws {
        let joke = makeJoke()
        let sut = ChuckNorrisService(client: MockHTTPClient(value: joke))

        let result = try await sut.randomJoke()

        #expect(result == joke)
    }

    @Test("randomJoke preserves the optional icon URL")
    func randomJokePreservesIconURL() async throws {
        let joke = makeJoke(iconURL: "https://api.chucknorris.io/img/avatar/chuck-norris.png")
        let sut = ChuckNorrisService(client: MockHTTPClient(value: joke))

        let result = try await sut.randomJoke()

        #expect(result.iconURL == joke.iconURL)
    }

    @Test("randomJoke hits the random endpoint")
    func randomJokeUsesRandomEndpoint() async throws {
        let seen = EndpointRecorder()
        let sut = ChuckNorrisService(client: MockHTTPClient { endpoint in
            seen.record(endpoint)
            return makeJoke()
        })

        _ = try await sut.randomJoke()

        #expect(seen.chuckNorrisCases.count == 1)
        guard case .random = seen.chuckNorrisCases.first else {
            Issue.record("Expected .random, got \(seen.chuckNorrisCases)")
            return
        }
    }

    @Test("randomJoke issues exactly one request per call")
    func randomJokeIssuesOneRequestPerCall() async throws {
        let seen = EndpointRecorder()
        let sut = ChuckNorrisService(client: MockHTTPClient { endpoint in
            seen.record(endpoint)
            return makeJoke()
        })

        _ = try await sut.randomJoke()
        _ = try await sut.randomJoke()
        _ = try await sut.randomJoke()

        #expect(seen.chuckNorrisCases.count == 3)
    }

    // MARK: Error handling

    @Test("randomJoke propagates client errors")
    func randomJokePropagatesError() async throws {
        let sut = ChuckNorrisService(client: MockHTTPClient(error: NetworkError.statusCode(500)))

        do {
            _ = try await sut.randomJoke()
            Issue.record("Expected an error")
        } catch let error as NetworkError {
            guard case .statusCode(500) = error else {
                Issue.record("Expected .statusCode(500), got \(error)")
                return
            }
        }
    }

    @Test("randomJoke surfaces a decoding mismatch as .invalidResponse")
    func randomJokeSurfacesTypeMismatch() async throws {
        let sut = ChuckNorrisService(client: MockHTTPClient(value: "not a joke"))

        await #expect(throws: NetworkError.self) {
            _ = try await sut.randomJoke()
        }
    }

    // MARK: Model

    @Test("ChuckNorrisJoke decodes the snake-cased icon_url key")
    func decodesIconURLKey() throws {
        let json = Data(#"{"id":"abc","value":"joke","icon_url":"https://example.com/icon.png"}"#.utf8)

        let joke = try JSONDecoder().decode(ChuckNorrisJoke.self, from: json)

        #expect(joke.id == "abc")
        #expect(joke.value == "joke")
        #expect(joke.iconURL == "https://example.com/icon.png")
    }

    @Test("ChuckNorrisJoke decodes when icon_url is absent")
    func decodesWithoutIconURL() throws {
        let json = Data(#"{"id":"abc","value":"joke"}"#.utf8)

        let joke = try JSONDecoder().decode(ChuckNorrisJoke.self, from: json)

        #expect(joke.iconURL == nil)
    }
}
