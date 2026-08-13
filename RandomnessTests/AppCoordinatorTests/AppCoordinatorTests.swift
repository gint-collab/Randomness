//
//  AppCoordinatorTests.swift
//  RandomnessTests
//
//  Created by Septuagint Murito on 8/11/26.
//

import Testing
import SwiftUI
@testable import Randomness

// MARK: - Test doubles

/// `HTTPClientProtocol` double that always fails, guaranteeing no real network
/// traffic happens while the coordinator builds its destinations.
private struct StubHTTPClient: HTTPClientProtocol {
    nonisolated func request<T: Decodable & Sendable>(_ endpoint: EndpointProtocol, as type: T.Type) async throws -> T {
        throw URLError(.unsupportedURL)
    }
}

/// Deterministic `ChuckNorrisServiceProtocol` double returning a fixed joke.
private struct StubChuckNorrisService: ChuckNorrisServiceProtocol {
    func randomJoke() async throws -> ChuckNorrisJoke {
        ChuckNorrisJoke(id: "1", value: "Chuck Norris counted to infinity. Twice.", iconURL: nil)
    }
}

/// Composition root used by the tests, wiring only offline test doubles.
private struct StubDependencies: AppDependenciesProtocol {
    let httpClient: HTTPClientProtocol = StubHTTPClient()
    let catService: CatServiceProtocol = MockCatService()
    let chuckNorrisService: ChuckNorrisServiceProtocol = StubChuckNorrisService()

    @MainActor
    func makeApplePayService() -> ApplePayServiceProtocol { MockApplePayService() }
}

/// Builds a `CatImage` fixture.
/// - Parameter id: Identifier used for both the id and the generated URL.
/// - Returns: A fully populated `CatImage`.
private func makeImage(id: String = "abc") -> CatImage {
    CatImage(id: id, url: "https://cdn2.thecatapi.com/images/\(id).jpg", width: 100, height: 50)
}

/// Creates the system under test backed by `StubDependencies`.
@MainActor
private func makeSUT() -> AppCoordinator {
    AppCoordinator(dependencies: StubDependencies())
}

// MARK: - Tests

/// Unit tests for `AppCoordinator`: navigation stack management, authentication
/// flow transitions and route-to-view construction.
@MainActor
struct AppCoordinatorTests {

    // MARK: Initial state

    /// A freshly created coordinator is logged out and shows the root screen.
    @Test func startsUnauthenticatedWithEmptyPath() {
        let sut = makeSUT()

        #expect(sut.isAuthenticated == false)
        #expect(sut.path.isEmpty)
    }

    // MARK: Navigation

    /// `push(_:)` appends exactly one entry to the navigation path.
    @Test func pushAppendsRouteToPath() {
        let sut = makeSUT()

        sut.push(.catList)

        #expect(sut.path.count == 1)
    }

    /// Consecutive pushes stack up, including routes with associated values.
    @Test func pushMultipleRoutesGrowsPath() {
        let sut = makeSUT()

        sut.push(.catList)
        sut.push(.chuckNorris)
        sut.push(.catDetail(image: makeImage(), related: [makeImage(id: "x")]))

        #expect(sut.path.count == 3)
    }

    /// `pop()` removes only the topmost route.
    @Test func popRemovesLastRoute() {
        let sut = makeSUT()
        sut.push(.catList)
        sut.push(.chuckNorris)

        sut.pop()

        #expect(sut.path.count == 1)
    }

    /// `pop()` on an empty path is safe and leaves the path untouched.
    @Test func popOnEmptyPathIsNoOp() {
        let sut = makeSUT()

        sut.pop()

        #expect(sut.path.isEmpty)
    }

    /// `popToRoot()` discards the whole stack in one call.
    @Test func popToRootClearsPath() {
        let sut = makeSUT()
        sut.push(.catList)
        sut.push(.chuckNorris)
        sut.push(.catFeeds(makeImage()))

        sut.popToRoot()

        #expect(sut.path.isEmpty)
    }

    // MARK: Authentication flow

    /// `didLogin()` flips `isAuthenticated` to `true` and resets navigation so the
    /// user lands on the authenticated root screen.
    @Test func didLoginAuthenticatesAndResetsPath() {
        let sut = makeSUT()
        sut.push(.catList)

        sut.didLogin()

        #expect(sut.isAuthenticated)
        #expect(sut.path.isEmpty)
    }

    /// `didLogout()` clears the session and any screen pushed while signed in.
    @Test func didLogoutDeauthenticatesAndResetsPath() {
        let sut = makeSUT()
        sut.didLogin()
        sut.push(.chuckNorris)

        sut.didLogout()

        #expect(sut.isAuthenticated == false)
        #expect(sut.path.isEmpty)
    }

    // MARK: Route factory

    /// Every `AppRoute` case produces a concrete destination view without trapping,
    /// protecting against missing cases in the factory's `switch`.
    /// - Parameter route: Route under test, supplied by the parameterised runner.
    @Test(arguments: [
        AppRoute.catList,
        AppRoute.chuckNorris,
        AppRoute.catFeeds(makeImage()),
        AppRoute.catDetail(image: makeImage(), related: [makeImage(id: "y")])
    ])
    func viewForRouteBuildsDestination(route: AppRoute) {
        let sut = makeSUT()

        // Building the view must not trap and must produce a concrete SwiftUI view.
        let view = sut.view(for: route)

        #expect(String(describing: type(of: view)).isEmpty == false)
    }

    // MARK: Route equality / hashing

    /// `AppRoute` value semantics: routes carrying identical payloads compare equal
    /// (required for correct `NavigationPath` behaviour) while distinct cases differ.
    @Test func routesWithSameAssociatedValuesAreEqual() {
        let image = makeImage()
        let related = [makeImage(id: "z")]

        #expect(AppRoute.catDetail(image: image, related: related) == .catDetail(image: image, related: related))
        #expect(AppRoute.catFeeds(image) == .catFeeds(image))
        #expect(AppRoute.catList != .chuckNorris)
    }
}
