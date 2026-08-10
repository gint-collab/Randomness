//
//  CatPost.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/10/26.
//

import Foundation

/// A single card in the cat feed: an image, an optional fact and social counters.
nonisolated struct CatPost: Identifiable, Hashable, Sendable {
    let id: String
    let image: CatImage
    var fact: CatFact?
    let authorName: String
    let postedAt: Date
    var likeCount: Int
    var commentCount: Int
    var isLiked: Bool = false {
        didSet {
            guard isLiked != oldValue else { return }
            likeCount += isLiked ? 1 : -1
        }
    }

    init(
        image: CatImage,
        id: String? = nil,
        fact: CatFact? = nil,
        authorName: String? = nil,
        postedAt: Date = .now,
        likeCount: Int? = nil,
        commentCount: Int? = nil,
        isLiked: Bool = false
    ) {
        // The same image id can come back on several pages, so callers can pass
        // a disambiguated id to keep `ForEach` identities unique.
        self.id = id ?? image.id
        self.image = image
        self.fact = fact
        self.authorName = authorName ?? Self.authorNames.randomElement() ?? "Cat Lover"
        self.postedAt = postedAt
        self.likeCount = likeCount ?? Int.random(in: 12...4_800)
        self.commentCount = commentCount ?? Int.random(in: 0...320)
        self.isLiked = isLiked
    }

    private static let authorNames = [
        "Whiskers Daily",
        "Mittens Fanclub",
        "Purr Review",
        "The Meow Times",
        "Cat Naps Weekly",
        "Paws & Effect"
    ]
}
