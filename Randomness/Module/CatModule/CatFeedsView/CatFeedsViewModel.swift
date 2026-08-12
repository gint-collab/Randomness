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
    func cancelPendingWork()
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
    private var loadMoreTask: Task<Void, Never>?
    private var initialLoadTask: Task<Void, Never>?

    init(image: CatImage? = nil, service: CatServiceProtocol, pageSize: Int = 10) {
        self.seedImage = image
        self.service = service
        self.pageSize = pageSize
        self.posts = image.map { [CatPost(image: $0)] } ?? []
    }

    func onAppear() {
        guard !didLoadInitialPage else { return }
        didLoadInitialPage = true
        initialLoadTask?.cancel()
        // `[weak self]` so the detached task never keeps the view model alive
        // after the screen is dismissed.
        initialLoadTask = Task { [weak self] in
            await self?.loadFactForFirstPost()
            await self?.loadMore()
            self?.initialLoadTask = nil
        }
    }

    /// Cancels any in-flight work. Call from the view's `onDisappear`.
    func cancelPendingWork() {
        initialLoadTask?.cancel()
        initialLoadTask = nil
        loadMoreTask?.cancel()
        loadMoreTask = nil
    }

    func refresh() async {
        // Cancel any in-flight pagination, otherwise `loadMore`'s `isLoadingMore`
        // guard makes the refresh return immediately and nothing happens.
        loadMoreTask?.cancel()
        loadMoreTask = nil
        isLoadingMore = false
        didLoadInitialPage = true

        let seed = seedImage
        let limit = pageSize

        await perform { [weak self] in
            guard let self else { return }
            let newPosts = try await self.service.fetchPosts(offset: 0, limit: limit, seed: seed)

            // Build the new feed off-screen and swap it in at the end, so the
            // list is never emptied mid-refresh (which kills the pull gesture).
            var refreshed = seed.map { [CatPost(image: $0)] } ?? []
            refreshed.append(contentsOf: newPosts)

            if !refreshed.isEmpty, refreshed[0].fact == nil {
                refreshed[0].fact = try? await self.service.randomFact()
            }

            self.posts = refreshed
        }
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
            guard !Task.isCancelled else { return }
            self.posts.append(contentsOf: newPosts)
        }
    }

    /// Triggers the next page once the user reaches the last few cards.
    func loadMoreIfNeeded(currentItem: CatPost) async {
        guard !isLoadingMore else { return }
        let thresholdIndex = posts.index(posts.endIndex, offsetBy: -3, limitedBy: posts.startIndex) ?? posts.startIndex
        guard let index = posts.firstIndex(where: { $0.id == currentItem.id }),
              index >= thresholdIndex else { return }
        // Two statements so the closure infers `Void` rather than `Void?`,
        // which wouldn't match `Task<Void, Never>`.
        let task = Task { [weak self] in
            guard let self else { return }
            await self.loadMore()
        }
        loadMoreTask = task
        await task.value
        if loadMoreTask == task { loadMoreTask = nil }
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
