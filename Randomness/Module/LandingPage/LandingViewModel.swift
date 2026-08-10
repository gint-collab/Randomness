//
//  LandingViewModel.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/10/26.
//

import Combine

@MainActor
protocol LandingViewModelProtocol: LoadableViewModel {
    func login()
}

@MainActor
final class LandingViewModel: LandingViewModelProtocol {
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let onLoginSuccess: CompletionHandler

    init(onLoginSuccess: @escaping CompletionHandler) {
        self.onLoginSuccess = onLoginSuccess
    }

    func login() {
        onLoginSuccess()
    }
}
