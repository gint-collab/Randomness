//
//  CatFeedsViewModel.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/10/26.
//

import SwiftUI
import Combine

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

    func loadMore() async {
        guard !isLoadingMore else { return }
        isLoadingMore = true

        defer { isLoadingMore = false }

        let currentCount = posts.count
        let seed = seedImage

        await perform { [weak self] in
            guard let self else { return }
            let newPosts = try await self.service.fetchPosts(
                offset: currentCount,
                limit: self.pageSize,
                seed: seed
            )
            self.posts.append(contentsOf: newPosts)
        }
    }

    /// Triggers the next page once the user reaches the last few cards.
    func loadMoreIfNeeded(currentItem: CatPost) async {
        guard !isLoadingMore else { return }
        let thresholdIndex = posts.index(posts.endIndex, offsetBy: -3, limitedBy: posts.startIndex) ?? posts.startIndex
        guard let index = posts.firstIndex(where: { $0.id == currentItem.id }),
              index >= thresholdIndex else { return }
        await loadMore()
    }

    func toggleLike(_ post: CatPost) {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        posts[index].isLiked.toggle()
    }

    private func loadFactForFirstPost() async {
        guard !posts.isEmpty else { return }
        await perform { [weak self] in
            guard let self else { return }
            let fact = try await self.service.randomFact()
            if !self.posts.isEmpty { self.posts[0].fact = fact }
        }
    }
}
