//
//  ChuckNorrisViewModel.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/10/26.
//

import SwiftUI
import Combine

@MainActor
protocol ChuckNorrisViewModelProtocol: LoadableViewModel {
    var joke: ChuckNorrisJoke? { get }
    func loadJoke() async
}

@MainActor
final class ChuckNorrisViewModel: ChuckNorrisViewModelProtocol {
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published private(set) var joke: ChuckNorrisJoke?

    private let service: ChuckNorrisServiceProtocol

    init(service: ChuckNorrisServiceProtocol) {
        self.service = service
    }

    func onAppear() {
        guard joke == nil else { return }
        Task { await loadJoke() }
    }

    func loadJoke() async {
        await perform { [weak self] in
            guard let self else { return }
            self.joke = try await self.service.randomJoke()
        }
    }
}

/// Preview/test double returning a canned joke.
struct MockChuckNorrisService: ChuckNorrisServiceProtocol {
    var joke: ChuckNorrisJoke = ChuckNorrisJoke(
        id: "MhLoeMtSS9O-AWnwDXKJXg",
        value: "While bass fishing near a hiway bridge in his boat, Chuck Norris observed a funeral procession drive by. Out of respect, he stood-up, removed his hat placing it over his heart and thought to himself, \"this is the least I can do...after all I was married to her for over 40 years\".",
        iconURL: "https://api.chucknorris.io/img/avatar/chuck-norris.png"
    )

    func randomJoke() async throws -> ChuckNorrisJoke { joke }
}
