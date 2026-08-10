//
//  CatFeedsViewModel.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/10/26.
//

import SwiftUI
import Combine

/// A single item in the cat feed, modelled like a social post.
nonisolated struct CatPost: Identifiable, Hashable, Sendable {
    let id: String
    let image: CatImage
    var fact: CatFact?
    var likeCount: Int
    var commentCount: Int
    var isLiked: Bool
    let postedAt: Date

    init(
        image: CatImage,
        fact: CatFact? = nil,
        likeCount: Int = Int.random(in: 12...2400),
        commentCount: Int = Int.random(in: 0...180),
        isLiked: Bool = false,
        postedAt: Date = Date().addingTimeInterval(-Double.random(in: 300...86_400 * 5))
    ) {
        self.id = image.id
        self.image = image
        self.fact = fact
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.isLiked = isLiked
        self.postedAt = postedAt
    }

    var authorName: String { "Cat #\(image.id.prefix(4))" }
}

@MainActor
protocol CatFeedsViewModelProtocol: LoadableViewModel {
    /// The image the feed was seeded with, when opened from a specific cat.
    var seedImage: CatImage? { get }
    var posts: [CatPost] { get }
    var isLoadingMore: Bool { get }
    func refresh() async
    func loadMoreIfNeeded(currentItem: CatPost) async
    func toggleLike(_ post: CatPost)
}

@MainActor
final class CatFeedsViewModel: CatFeedsViewModelProtocol {
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published private(set) var seedImage: CatImage?
    @Published private(set) var posts: [CatPost] = []
    @Published private(set) var isLoadingMore: Bool = false

    private let service: CatServiceProtocol
    private let pageSize: Int
    private var didLoadInitialPage = false

    init(image: CatImage? = nil, service: CatServiceProtocol, pageSize: Int = 10) {
        self.seedImage = image
        self.service = service
        self.pageSize = pageSize
        self.posts = image.map { [CatPost(image: $0)] } ?? []
    }

    func onAppear() {
        guard !didLoadInitialPage else { return }
        didLoadInitialPage = true
        Task {
            await loadFactForFirstPost()
            await loadMore()
        }
    }

    func refresh() async {
        posts = seedImage.map { [CatPost(image: $0)] } ?? []
        await loadFactForFirstPost()
        await loadMore()
    }

    func loadMoreIfNeeded(currentItem: CatPost) async {
        guard let index = posts.firstIndex(of: currentItem) else { return }
        guard index >= posts.count - 3 else { return }
        await loadMore()
    }

    func toggleLike(_ post: CatPost) {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        posts[index].isLiked.toggle()
        posts[index].likeCount += posts[index].isLiked ? 1 : -1
    }

    // MARK: - Private

    private func loadFactForFirstPost() async {
        guard !posts.isEmpty else { return }
        await perform { [weak self] in
            guard let self else { return }
            let fact = try await self.service.randomFact()
            if !self.posts.isEmpty { self.posts[0].fact = fact }
        }
    }

    private func loadMore() async {
        guard !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            async let imagesTask = service.images(limit: pageSize)
            async let factsTask = service.facts(limit: pageSize)
            let (images, facts) = try await (imagesTask, factsTask)

            var existing = Set(posts.map(\.id))
            var newPosts: [CatPost] = []
            for (offset, item) in images.enumerated() where !existing.contains(item.id) {
                existing.insert(item.id)
                newPosts.append(
                    CatPost(image: item, fact: offset < facts.count ? facts[offset] : nil)
                )
            }
            posts.append(contentsOf: newPosts)
        } catch {
            if posts.count <= 1 {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}
