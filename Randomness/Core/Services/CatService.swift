//
//  CatService.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/9/26.
//

import Foundation

nonisolated struct CatFact: Decodable, Hashable, Identifiable, Sendable {
    var id: String { fact }
    let fact: String
    let length: Int
}

nonisolated struct CatImage: Decodable, Hashable, Identifiable, Sendable {
    let id: String
    let url: String
    let width: Int
    let height: Int

    /// width / height, guarded against invalid values coming from the API.
    var aspectRatio: CGFloat {
        guard width > 0, height > 0 else { return 1 }
        return CGFloat(width) / CGFloat(height)
    }
}

protocol CatServiceProtocol {
    func randomFact() async throws -> CatFact
    func facts(limit: Int) async throws -> [CatFact]
    func images(limit: Int) async throws -> [CatImage]
    /// Builds a page of feed posts by pairing random images with random facts.
    /// - Parameters:
    ///   - offset: Number of posts already shown, used to keep ids unique.
    ///   - limit: Page size.
    ///   - seed: Optional image whose id must be excluded from the page.
    func fetchPosts(offset: Int, limit: Int, seed: CatImage?) async throws -> [CatPost]
}

extension CatServiceProtocol {
    func fetchPosts(offset: Int, limit: Int, seed: CatImage?) async throws -> [CatPost] {
        async let imagesTask = images(limit: limit)
        async let factsTask = facts(limit: limit)
        let (pageImages, pageFacts) = try await (imagesTask, factsTask)

        return pageImages
            .filter { $0.id != seed?.id }
            .enumerated()
            .map { index, image in
                CatPost(
                    image: image,
                    id: "\(image.id)-\(offset + index)",
                    fact: index < pageFacts.count ? pageFacts[index] : nil,
                    postedAt: Date.now.addingTimeInterval(-Double((offset + index) * 3_600))
                )
            }
    }
}

enum CatEndpoint: EndpointProtocol {
    case randomFact
    case facts(limit: Int)

    var baseURL: URL { URL(string: "https://catfact.ninja")! }

    var path: String {
        switch self {
        case .randomFact: return "fact"
        case .facts: return "facts"
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .randomFact: return []
        case .facts(let limit): return [URLQueryItem(name: "limit", value: "\(limit)")]
        }
    }
}

enum CatImageEndpoint: EndpointProtocol {
    case search(limit: Int)

    var baseURL: URL { URL(string: "https://api.thecatapi.com")! }

    var path: String {
        switch self {
        case .search: return "v1/images/search"
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .search(let limit): return [URLQueryItem(name: "limit", value: "\(limit)")]
        }
    }
}

private nonisolated struct CatFactsPage: Decodable, Sendable {
    let data: [CatFact]
}

struct CatService: CatServiceProtocol {
    private let client: HTTPClientProtocol

    init(client: HTTPClientProtocol) {
        self.client = client
    }

    func randomFact() async throws -> CatFact {
        try await client.request(CatEndpoint.randomFact, as: CatFact.self)
    }

    func facts(limit: Int) async throws -> [CatFact] {
        try await client.request(CatEndpoint.facts(limit: limit), as: CatFactsPage.self).data
    }

    func images(limit: Int) async throws -> [CatImage] {
        try await client.request(CatImageEndpoint.search(limit: limit), as: [CatImage].self)
    }
}
