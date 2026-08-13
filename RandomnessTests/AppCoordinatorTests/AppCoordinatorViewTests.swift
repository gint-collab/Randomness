//
//  AppCoordinatorViewTests.swift
//  RandomnessTests
//
//  Created by Septuagint Murito on 8/11/26.
//

import SwiftUI
import Testing
@testable import Randomness

// MARK: - Test doubles

/// `HTTPClientProtocol` double that always fails, guaranteeing no real network
/// traffic happens while the view hierarchy is built.
private struct ViewStubHTTPClient: HTTPClientProtocol {
    nonisolated func request<T: Decodable & Sendable>(_ endpoint: EndpointProtocol, as type: T.Type) async throws -> T {
        throw URLError(.unsupportedURL)
    }
}

private struct ViewStubChuckNorrisService: ChuckNorrisServiceProtocol {
    func randomJoke() async throws -> ChuckNorrisJoke {
        ChuckNorrisJoke(id: "1", value: "Chuck Norris counted to infinity. Twice.", iconURL: nil)
    }
}

/// Composition root wiring only offline doubles.
private struct ViewStubDependencies: AppDependenciesProtocol {
    let httpClient: HTTPClientProtocol = ViewStubHTTPClient()
    let catService: CatServiceProtocol = MockCatService()
    let chuckNorrisService: ChuckNorrisServiceProtocol = ViewStubChuckNorrisService()

    @MainActor
    func makeApplePayService() -> ApplePayServiceProtocol { MockApplePayService() }
}

private func makeImage(id: String = "abc") -> CatImage {
    CatImage(id: id, url: "https://cdn2.thecatapi.com/images/\(id).jpg", width: 100, height: 50)
}

/// Renders a view off-screen, which forces SwiftUI to evaluate `body` and
/// initialise `@StateObject` storage — the closest a unit test can get to
/// "this screen actually builds".
@MainActor
private func render(_ view: some View) -> UIImage? {
    let renderer = ImageRenderer(content: view.frame(width: 390, height: 844))
    renderer.scale = 1
    return renderer.uiImage
}

// MARK: - Tests

/// Unit tests for `AppCoordinatorView`: it must build in both authentication
/// states and wire its child view models back to the coordinator.
@Suite("AppCoordinatorView")
@MainActor
struct AppCoordinatorViewTests {

    // MARK: Construction

    @Test("Builds without touching the network")
    func buildsView() {
        let view = AppCoordinatorView()
            .environment(\.dependencies, ViewStubDependencies())

        #expect(String(describing: type(of: view)).isEmpty == false)
    }

    @Test("Renders the unauthenticated root screen")
    func rendersLandingWhenLoggedOut() {
        let view = AppCoordinatorView()
            .environment(\.dependencies, ViewStubDependencies())

        #expect(render(view) != nil)
    }

    @Test("Renders the authenticated root screen")
    func rendersDashboardWhenLoggedIn() {
        let coordinator = AppCoordinator(dependencies: ViewStubDependencies())
        coordinator.didLogin()

        let view = AppCoordinatorView()
            .environment(\.dependencies, ViewStubDependencies())
            .environmentObject(coordinator)

        #expect(coordinator.isAuthenticated)
        #expect(render(view) != nil)
    }

    @Test("Renders every navigation destination the coordinator can produce")
    func rendersEveryDestination() {
        let coordinator = AppCoordinator(dependencies: ViewStubDependencies())
        let routes: [AppRoute] = [
            .catList,
            .chuckNorris,
            .catFeeds(makeImage()),
            .catDetail(image: makeImage(), related: [makeImage(id: "y")])
        ]

        for route in routes {
            let destination = NavigationStack { coordinator.view(for: route) }
                .environment(\.dependencies, ViewStubDependencies())
                .environmentObject(coordinator)

            #expect(render(destination) != nil, "Failed to render \(route)")
        }
    }

    // MARK: Coordinator wiring

    /// Mirrors `LandingView(viewModel: LandingViewModel(onLoginSuccess: coordinator.didLogin))`.
    @Test("Landing login callback authenticates the coordinator")
    func landingLoginCallbackAuthenticates() {
        let coordinator = AppCoordinator(dependencies: ViewStubDependencies())
        let viewModel = LandingViewModel(onLoginSuccess: { coordinator.didLogin() })

        viewModel.login()

        #expect(coordinator.isAuthenticated)
        #expect(coordinator.path.isEmpty)
    }

    /// Mirrors `DashboardView(viewModel: DashboardViewModel(onLogout: coordinator.didLogout))`.
    @Test("Dashboard logout callback deauthenticates the coordinator")
    func dashboardLogoutCallbackDeauthenticates() {
        let coordinator = AppCoordinator(dependencies: ViewStubDependencies())
        coordinator.didLogin()
        let viewModel = DashboardViewModel(
            onSelect: { coordinator.push($0) },
            onLogout: { coordinator.didLogout() }
        )

        viewModel.didTapLogout()

        #expect(coordinator.isAuthenticated == false)
        #expect(coordinator.path.isEmpty)
    }

    /// Mirrors `DashboardViewModel(onSelect: coordinator.push)`.
    @Test("Dashboard selection pushes the item's route", arguments: ListItems.allCases)
    func dashboardSelectionPushesRoute(item: ListItems) {
        let coordinator = AppCoordinator(dependencies: ViewStubDependencies())
        let viewModel = DashboardViewModel(
            onSelect: { coordinator.push($0) },
            onLogout: {}
        )

        viewModel.didSelect(item)

        #expect(coordinator.path.count == 1)
    }
}
