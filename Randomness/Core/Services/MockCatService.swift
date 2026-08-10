//
//  MockCatService.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/9/26.
//

import Foundation

/// Preview / test double backed by a static JSON payload.
struct MockCatService: CatServiceProtocol {
    var error: Error?

    func randomFact() async throws -> CatFact {
        if let error { throw error }
        return CatFact(fact: "Cats sleep 70% of their lives.", length: 34)
    }

    func facts(limit: Int) async throws -> [CatFact] {
        if let error { throw error }
        return Array(repeating: CatFact(fact: "Cats have five toes on their front paws.", length: 40), count: limit)
    }

    func images(limit: Int) async throws -> [CatImage] {
        if let error { throw error }
        let images = try JSONDecoder().decode([CatImage].self, from: Data(Self.sampleJSON.utf8))
        return Array(images.prefix(limit))
    }

    static let sampleJSON = """
    [
      { "id": "4gj", "url": "https://cdn2.thecatapi.com/images/4gj.gif", "width": 500, "height": 287 },
      { "id": "4hr", "url": "https://cdn2.thecatapi.com/images/4hr.gif", "width": 239, "height": 170 },
      { "id": "7ak", "url": "https://cdn2.thecatapi.com/images/7ak.jpg", "width": 500, "height": 336 },
      { "id": "8fu", "url": "https://cdn2.thecatapi.com/images/8fu.jpg", "width": 550, "height": 365 },
      { "id": "a05", "url": "https://cdn2.thecatapi.com/images/a05.jpg", "width": 640, "height": 640 },
      { "id": "cj1", "url": "https://cdn2.thecatapi.com/images/cj1.jpg", "width": 640, "height": 512 },
      { "id": "MTU1ODMyMQ", "url": "https://cdn2.thecatapi.com/images/MTU1ODMyMQ.jpg", "width": 640, "height": 478 },
      { "id": "MTY2MjYzNQ", "url": "https://cdn2.thecatapi.com/images/MTY2MjYzNQ.jpg", "width": 640, "height": 360 },
      { "id": "MTg0MTA4OA", "url": "https://cdn2.thecatapi.com/images/MTg0MTA4OA.jpg", "width": 540, "height": 720 },
      { "id": "wu1YzlB9q", "url": "https://cdn2.thecatapi.com/images/wu1YzlB9q.jpg", "width": 2048, "height": 1371 }
    ]
    """
}
