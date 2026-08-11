//
//  CatServiceTests.swift
//  RandomnessTests
//
//  Created by Septuagint Murito on 8/11/26.
//

import Foundation
import Testing
@testable import Randomness

private func makeImage(id: String = "abc") -> CatImage {
    CatImage(id: id, url: "https://cdn2.thecatapi.com/images/\(id).jpg", width: 100, height: 50)
}

private func makeFact(_ text: String = "Cats sleep 70% of their lives.") -> CatFact {
    CatFact(fact: text, length: text.count)
}

/// Unit tests for `CatService`, driven entirely through `MockHTTPClient`.
@Suite("CatService")
@MainActor
struct CatServiceTests {

    // MARK: randomFact

    @Test("randomFact returns the decoded fact")
    func randomFactReturnsDecodedFact() async throws {
        let fact = makeFact()
        let sut = CatService(client: MockHTTPClient(value: fact))

        let result = try await sut.randomFact()

        #expect(result == fact)
    }

    @Test("randomFact hits the random fact endpoint")
    func randomFactUsesRandomFactEndpoint() async throws {
        let seen = EndpointRecorder()
        let sut = CatService(client: MockHTTPClient { endpoint in
            seen.record(endpoint)
            return makeFact()
        })

        _ = try await sut.randomFact()

        #expect(seen.catCases.count == 1)
        guard case .randomFact = seen.catCases.first else {
            Issue.record("Expected .randomFact, got \(seen.catCases)")
            return
        }
    }

    @Test("randomFact propagates client errors")
    func randomFactPropagatesError() async throws {
        let sut = CatService(client: MockHTTPClient(error: NetworkError.statusCode(500)))

        await #expect(throws: NetworkError.self) {
            _ = try await sut.randomFact()
        }
    }

    // MARK: facts

    @Test("facts unwraps the paginated envelope")
    func factsUnwrapsEnvelope() async throws {
        let expected = [makeFact("one"), makeFact("two")]
        let sut = CatService(client: MockHTTPClient(value: CatFactsPage(data: expected)))

        let result = try await sut.facts(limit: 2)

        #expect(result == expected)
    }

    @Test("facts forwards the requested limit", arguments: [1, 5, 25])
    func factsForwardsLimit(limit: Int) async throws {
        let seen = EndpointRecorder()
        let sut = CatService(client: MockHTTPClient { endpoint in
            seen.record(endpoint)
            return CatFactsPage(data: [])
        })

        _ = try await sut.facts(limit: limit)

        guard case .facts(let requestedLimit, _) = seen.catCases.first else {
            Issue.record("Expected .facts, got \(seen.catCases)")
            return
        }
        #expect(requestedLimit == limit)
    }

    /// `/facts` is paginated rather than random, so the service randomises the page
    /// to keep refreshes fresh. The page must stay within the valid range.
    @Test("facts requests a page within the valid range")
    func factsRandomisesPageWithinRange() async throws {
        let limit = 10
        let seen = EndpointRecorder()
        let sut = CatService(client: MockHTTPClient { endpoint in
            seen.record(endpoint)
            return CatFactsPage(data: [])
        })

        for _ in 0..<50 {
            _ = try await sut.facts(limit: limit)
        }

        let pages: [Int] = seen.catCases.compactMap { endpoint in
            guard case .facts(_, let page) = endpoint else { return nil }
            return page
        }
        #expect(pages.count == 50)
        #expect(pages.allSatisfy { $0 >= 1 && $0 <= 300 / limit })
    }

    @Test("facts survives a zero limit without trapping")
    func factsHandlesZeroLimit() async throws {
        let sut = CatService(client: MockHTTPClient(value: CatFactsPage(data: [])))

        let result = try await sut.facts(limit: 0)

        #expect(result.isEmpty)
    }

    @Test("facts propagates client errors")
    func factsPropagatesError() async throws {
        let sut = CatService(client: MockHTTPClient(error: NetworkError.invalidResponse))

        await #expect(throws: NetworkError.self) {
            _ = try await sut.facts(limit: 3)
        }
    }

    // MARK: images

    @Test("images returns the decoded images")
    func imagesReturnsDecodedImages() async throws {
        let images = [makeImage(), makeImage(id: "def")]
        let sut = CatService(client: MockHTTPClient(value: images))

        let result = try await sut.images(limit: 2)

        #expect(result == images)
    }

    @Test("images requests the search endpoint with the requested limit")
    func imagesRequestsSearchEndpointWithLimit() async throws {
        let seen = EndpointRecorder()
        let sut = CatService(client: MockHTTPClient { endpoint in
            seen.record(endpoint)
            return [makeImage()]
        })

        _ = try await sut.images(limit: 7)

        #expect(seen.catImageCases.count == 1)
        guard case .search(let limit) = seen.catImageCases.first else {
            Issue.record("Expected .search, got \(seen.catImageCases)")
            return
        }
        #expect(limit == 7)
    }

    @Test("images propagates client errors")
    func imagesPropagatesError() async throws {
        let sut = CatService(client: MockHTTPClient(error: NetworkError.invalidResponse))

        await #expect(throws: NetworkError.self) {
            _ = try await sut.images(limit: 1)
        }
    }

    // MARK: fetchPosts (protocol extension)

    @Test("fetchPosts pairs each image with a fact")
    func fetchPostsPairsImagesWithFacts() async throws {
        let images = [makeImage(id: "a"), makeImage(id: "b")]
        let facts = [makeFact("one"), makeFact("two")]
        let sut = CatService(client: MockHTTPClient { endpoint -> Any in
            if endpoint is CatImageEndpoint { return images }
            return CatFactsPage(data: facts)
        })

        let posts = try await sut.fetchPosts(offset: 0, limit: 2, seed: nil)

        #expect(posts.count == 2)
        #expect(posts.map(\.image) == images)
        #expect(posts.compactMap(\.fact) == facts)
    }

    @Test("fetchPosts excludes the seed image")
    func fetchPostsExcludesSeed() async throws {
        let seed = makeImage(id: "seed")
        let images = [seed, makeImage(id: "other")]
        let sut = CatService(client: MockHTTPClient { endpoint -> Any in
            if endpoint is CatImageEndpoint { return images }
            return CatFactsPage(data: [makeFact()])
        })

        let posts = try await sut.fetchPosts(offset: 0, limit: 2, seed: seed)

        #expect(posts.count == 1)
        #expect(posts.first?.image.id == "other")
    }

    @Test("fetchPosts offsets ids so paging keeps them unique")
    func fetchPostsOffsetsIDs() async throws {
        let images = [makeImage(id: "a"), makeImage(id: "b")]
        let sut = CatService(client: MockHTTPClient { endpoint -> Any in
            if endpoint is CatImageEndpoint { return images }
            return CatFactsPage(data: [])
        })

        let firstPage = try await sut.fetchPosts(offset: 0, limit: 2, seed: nil)
        let secondPage = try await sut.fetchPosts(offset: 2, limit: 2, seed: nil)

        #expect(firstPage.map(\.id) == ["a-0", "b-1"])
        #expect(secondPage.map(\.id) == ["a-2", "b-3"])
        #expect(Set(firstPage.map(\.id)).isDisjoint(with: Set(secondPage.map(\.id))))
    }

    @Test("fetchPosts leaves the fact nil when fewer facts than images come back")
    func fetchPostsToleratesMissingFacts() async throws {
        let images = [makeImage(id: "a"), makeImage(id: "b")]
        let sut = CatService(client: MockHTTPClient { endpoint -> Any in
            if endpoint is CatImageEndpoint { return images }
            return CatFactsPage(data: [makeFact("only one")])
        })

        let posts = try await sut.fetchPosts(offset: 0, limit: 2, seed: nil)

        #expect(posts[0].fact != nil)
        #expect(posts[1].fact == nil)
    }

    @Test("fetchPosts propagates client errors")
    func fetchPostsPropagatesError() async throws {
        let sut = CatService(client: MockHTTPClient(error: NetworkError.statusCode(503)))

        await #expect(throws: NetworkError.self) {
            _ = try await sut.fetchPosts(offset: 0, limit: 2, seed: nil)
        }
    }

    // MARK: Model

    @Test("CatImage.aspectRatio guards against invalid dimensions")
    func aspectRatioGuardsInvalidDimensions() {
        #expect(CatImage(id: "a", url: "u", width: 100, height: 50).aspectRatio == 2)
        #expect(CatImage(id: "a", url: "u", width: 0, height: 50).aspectRatio == 1)
        #expect(CatImage(id: "a", url: "u", width: 100, height: 0).aspectRatio == 1)
        #expect(CatImage(id: "a", url: "u", width: -10, height: -5).aspectRatio == 1)
    }

    @Test("CatFact is identified by its text")
    func catFactIDIsItsText() {
        let fact = makeFact("Cats have 32 muscles in each ear.")

        #expect(fact.id == fact.fact)
    }
}
