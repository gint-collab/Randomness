//
//  CoordinatorProtocol.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/9/26.
//

import SwiftUI

/// Routes that a coordinator can navigate to.
protocol RouteProtocol: Hashable {}

/// Navigation abstraction so view models depend on behaviour, not on `AppCoordinator`.
@MainActor
protocol NavigationCoordinating: AnyObject {
    associatedtype Route: RouteProtocol

    var path: NavigationPath { get set }

    func push(_ route: Route)
    func pop()
    func popToRoot()
}

extension NavigationCoordinating {
    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path = NavigationPath()
    }

    func push(_ route: Route) {
        path.append(route)
    }
}

/// Authentication flow abstraction.
@MainActor
protocol AuthenticationFlowCoordinating: AnyObject {
    var isAuthenticated: Bool { get }

    func didLogin()
    func didLogout()
}

/// Builds a destination view for a given route.
@MainActor
protocol RouteViewFactory {
    associatedtype Route: RouteProtocol
    associatedtype Destination: View

    @ViewBuilder
    func view(for route: Route) -> Destination
}
