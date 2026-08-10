//
//  ChuckNorrisService.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/9/26.
//

import Foundation

nonisolated struct ChuckNorrisJoke: Decodable, Hashable, Identifiable, Sendable {
    let id: String
    let value: String
    let iconURL: String?

    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case value
        case iconURL = "icon_url"
    }
}

protocol ChuckNorrisServiceProtocol {
    func randomJoke() async throws -> ChuckNorrisJoke
}

enum ChuckNorrisEndpoint: EndpointProtocol {
    case random

    var baseURL: URL { URL(string: "https://api.chucknorris.io")! }

    var path: String {
        switch self {
        case .random: return "jokes/random"
        }
    }
}

struct ChuckNorrisService: ChuckNorrisServiceProtocol {
    private let client: HTTPClientProtocol

    init(client: HTTPClientProtocol) {
        self.client = client
    }

    func randomJoke() async throws -> ChuckNorrisJoke {
        try await client.request(ChuckNorrisEndpoint.random, as: ChuckNorrisJoke.self)
    }
}
