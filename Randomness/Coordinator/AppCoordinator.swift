//
//  AppCoordinator.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/9/26.
//

import SwiftUI
import Combine

enum AppRoute: RouteProtocol {
    case catDetail(CatImage)
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
            CatListView(
                viewModel: CatListViewModel(
                    service: self.dependencies.catService,
                    onSelect: { [weak self] image in
                        self?.push(.catDetail(image))
                    }
                )
            )
        case .catDetail(let image):
            CatDetailsView(
                viewModel: CatDetailsViewModel(
                    image: image,
                    service: self.dependencies.catService
                )
            )
        case .chuckNorris:
            ChuckNorrisView(
                viewModel: ChuckNorrisViewModel(service: self.dependencies.chuckNorrisService)
            )
        }
    }
}
