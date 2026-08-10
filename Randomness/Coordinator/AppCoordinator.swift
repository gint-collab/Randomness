//
//  AppCoordinator.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/9/26.
//

import SwiftUI
import Combine

enum AppRoute: RouteProtocol {
    /// Detail for a cat, carrying the list already loaded by the previous
    /// screen so the detail view needs no extra request.
    case catDetail(image: CatImage, related: [CatImage])
    case catFeeds(CatImage)
    case catList
    case chuckNorris
}

@MainActor
protocol AppCoordinating: NavigationCoordinating, AuthenticationFlowCoordinating, RouteViewFactory
where Route == AppRoute {}

@MainActor
final class AppCoordinator: ObservableObject, AppCoordinating {
    @Published var path = NavigationPath()
    @Published private(set) var isAuthenticated: Bool = false

    private let dependencies: AppDependenciesProtocol

    init(dependencies: AppDependenciesProtocol? = nil) {
        self.dependencies = dependencies ?? AppDependencies()
    }

    // MARK: - Flow
    func didLogin() {
        popToRoot()
        isAuthenticated = true
    }

    func didLogout() {
        popToRoot()
        isAuthenticated = false
    }

    // MARK: - RouteViewFactory
    @ViewBuilder
    func view(for route: AppRoute) -> some View {
        switch route {
        case .catList:
            CatTabbarView(
                service: self.dependencies.catService,
                onSelectImage: { [weak self] image, related in
                    self?.push(.catDetail(image: image, related: related))
                }
            )
        case .catDetail(let image, let related):
            CatDetailsView(
                viewModel: CatDetailsViewModel(
                    image: image,
                    relatedImages: related,
                    service: self.dependencies.catService
                )
            )
        case .chuckNorris:
            ChuckNorrisView(
                viewModel: ChuckNorrisViewModel(service: self.dependencies.chuckNorrisService)
            )
        case .catFeeds(let image):
            CatFeedsView(
                viewModel: CatFeedsViewModel(
                    image: image,
                    service: self.dependencies.catService
                )
            )
        }
    }
}
