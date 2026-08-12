//
//  CatDetailsViewModel.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/10/26.
//

import SwiftUI
import Combine

@MainActor
protocol CatDetailsViewModelProtocol: LoadableViewModel {
    var image: CatImage { get }
    var fact: CatFact? { get }
    var relatedImages: [CatImage] { get }
    var isLoadingRelated: Bool { get }
    func loadFact() async
    func loadRelatedImages() async
    func select(_ image: CatImage)
    func cancelPendingWork()
}

@MainActor
final class CatDetailsViewModel: CatDetailsViewModelProtocol {
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published private(set) var fact: CatFact?
    @Published private(set) var image: CatImage
    @Published private(set) var relatedImages: [CatImage] = []
    @Published private(set) var isLoadingRelated: Bool = false

    private let service: CatServiceProtocol
    private let relatedLimit: Int
    private var tasks: [Task<Void, Never>] = []

    /// - Parameter relatedImages: Images already loaded by the list screen.
    ///   When non-empty no network call is made for related cats.
    init(
        image: CatImage,
        relatedImages: [CatImage] = [],
        service: CatServiceProtocol,
        relatedLimit: Int = 10
    ) {
        self.image = image
        self.service = service
        self.relatedLimit = relatedLimit
        self.relatedImages = Self.ordered(relatedImages, selecting: image)
    }

    func onAppear() {
        // `[weak self]` + tracked tasks: unstructured tasks otherwise keep the
        // view model alive for the whole request after the screen is popped.
        // Each closure needs two statements so it infers `Void` rather than
        // `Void?`, which wouldn't match `Task<Void, Never>`.
        if fact == nil {
            tasks.append(Task { [weak self] in
                guard let self else { return }
                await self.loadFact()
            })
        }
        if relatedImages.isEmpty {
            tasks.append(Task { [weak self] in
                guard let self else { return }
                await self.loadRelatedImages()
            })
        }
    }

    /// Cancels any in-flight work. Call from the view's `onDisappear`.
    func cancelPendingWork() {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
    }

    func loadFact() async {
        await perform { [weak self] in
            guard let self else { return }
            self.fact = try await self.service.randomFact()
        }
    }

    func loadRelatedImages() async {
        guard relatedImages.isEmpty else { return }
        isLoadingRelated = true
        defer { isLoadingRelated = false }
        do {
            let images = try await service.images(limit: relatedLimit)
            relatedImages = Self.ordered(images, selecting: image)
        } catch {
            relatedImages = [image]
        }
    }

    func select(_ image: CatImage) {
        guard image.id != self.image.id else { return }
        self.image = image
    }

    /// Keeps the current image first and drops duplicates.
    private static func ordered(_ images: [CatImage], selecting image: CatImage) -> [CatImage] {
        guard !images.isEmpty else { return [] }
        var unique = [image]
        for item in images where item.id != image.id {
            unique.append(item)
        }
        return unique
    }
}
