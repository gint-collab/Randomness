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
    func loadFact() async
}

@MainActor
final class CatDetailsViewModel: CatDetailsViewModelProtocol {
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published private(set) var fact: CatFact?

    let image: CatImage

    private let service: CatServiceProtocol

    init(image: CatImage, service: CatServiceProtocol) {
        self.image = image
        self.service = service
    }

    func onAppear() {
        guard fact == nil else { return }
        Task { await loadFact() }
    }

    func loadFact() async {
        await perform { [weak self] in
            guard let self else { return }
            self.fact = try await self.service.randomFact()
        }
    }
}
