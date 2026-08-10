//
//  CatListViewModel.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/10/26.
//

import SwiftUI
import Combine

@MainActor
protocol CatListViewModelProtocol: LoadableViewModel {
    var images: [CatImage] { get }
    func loadImages() async
    func didSelect(_ image: CatImage)
}

@MainActor
final class CatListViewModel: CatListViewModelProtocol {
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published private(set) var images: [CatImage] = []

    private let service: CatServiceProtocol
    private let limit: Int
    /// Receives the tapped image plus the already loaded list, so the detail
    /// screen doesn't need to re-fetch anything.
    private let onSelect: (CatImage, [CatImage]) -> Void

    init(
        service: CatServiceProtocol,
        limit: Int = 10,
        onSelect: @escaping (CatImage, [CatImage]) -> Void = { _, _ in }
    ) {
        self.service = service
        self.limit = limit
        self.onSelect = onSelect
    }

    func onAppear() {
        guard images.isEmpty else { return }
        Task { await loadImages() }
    }

    func loadImages() async {
        await perform { [weak self] in
            guard let self else { return }
            let images = try await self.service.images(limit: self.limit)
            self.images = images
        }
    }

    func didSelect(_ image: CatImage) {
        onSelect(image, images)
    }
}
