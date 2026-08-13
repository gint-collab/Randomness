//
//  AppCoordinatorXCTests.swift
//  RandomnessTests
//
//  Created by Septuagint Murito on 8/11/26.
//
//  XCTest counterpart of `AppCoordinatorTests` (Swift Testing).
//

import XCTest
import SwiftUI
@testable import Randomness

// MARK: - Test doubles

/// `HTTPClientProtocol` double that always fails, guaranteeing no real network
/// traffic happens while the coordinator builds its destinations.
private struct XCStubHTTPClient: HTTPClientProtocol {
    nonisolated func request<T: Decodable & Sendable>(_ endpoint: EndpointProtocol, as type: T.Type) async throws -> T {
        throw URLError(.unsupportedURL)
    }
}

/// Deterministic `ChuckNorrisServiceProtocol` double returning a fixed joke.
private struct XCStubChuckNorrisService: ChuckNorrisServiceProtocol {
    func randomJoke() async throws -> ChuckNorrisJoke {
        ChuckNorrisJoke(id: "1", value: "Chuck Norris counted to infinity. Twice.", iconURL: nil)
    }
}

/// Composition root used by the tests, wiring only offline test doubles.
private struct XCStubDependencies: AppDependenciesProtocol {
    let httpClient: HTTPClientProtocol = XCStubHTTPClient()
    let catService: CatServiceProtocol = MockCatService()
    let chuckNorrisService: ChuckNorrisServiceProtocol = XCStubChuckNorrisService()

    @MainActor
    func makeApplePayService() -> ApplePayServiceProtocol { MockApplePayService() }
}

// MARK: - Tests

/// XCTest suite for `AppCoordinator`: navigation stack management, authentication
/// flow transitions and route-to-view construction.
@MainActor
final class AppCoordinatorXCTests: XCTestCase {

    /// System under test, recreated before every test case.
    private var sut: AppCoordinator!

    /// Creates a fresh coordinator backed by offline stub dependencies.
    override func setUp() {
        super.setUp()
        sut = AppCoordinator(dependencies: XCStubDependencies())
    }

    /// Releases the system under test to avoid state leaking between cases.
    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    /// Builds a `CatImage` fixture.
    /// - Parameter id: Identifier used for both the id and the generated URL.
    /// - Returns: A fully populated `CatImage`.
    private func makeImage(id: String = "abc") -> CatImage {
        CatImage(id: id, url: "https://cdn2.thecatapi.com/images/\(id).jpg", width: 100, height: 50)
    }

    // MARK: Initial state

    /// A freshly created coordinator is logged out and shows the root screen.
    func test_init_startsUnauthenticatedWithEmptyPath() {
        XCTAssertFalse(sut.isAuthenticated)
        XCTAssertTrue(sut.path.isEmpty)
    }

    // MARK: Navigation

    /// `push(_:)` appends exactly one entry to the navigation path.
    func test_push_appendsRouteToPath() {
        sut.push(.catList)

        XCTAssertEqual(sut.path.count, 1)
    }

    /// Consecutive pushes stack up, including routes with associated values.
    func test_push_multipleRoutesGrowsPath() {
        sut.push(.catList)
        sut.push(.chuckNorris)
        sut.push(.catDetail(image: makeImage(), related: [makeImage(id: "x")]))

        XCTAssertEqual(sut.path.count, 3)
    }

    /// `pop()` removes only the topmost route.
    func test_pop_removesLastRoute() {
        sut.push(.catList)
        sut.push(.chuckNorris)

        sut.pop()

        XCTAssertEqual(sut.path.count, 1)
    }

    /// `pop()` on an empty path is safe and leaves the path untouched.
    func test_pop_onEmptyPathIsNoOp() {
        sut.pop()

        XCTAssertTrue(sut.path.isEmpty)
    }

    /// `popToRoot()` discards the whole stack in one call.
    func test_popToRoot_clearsPath() {
        sut.push(.catList)
        sut.push(.chuckNorris)
        sut.push(.catFeeds(makeImage()))

        sut.popToRoot()

        XCTAssertTrue(sut.path.isEmpty)
    }

    // MARK: Authentication flow

    /// `didLogin()` flips `isAuthenticated` to `true` and resets navigation so the
    /// user lands on the authenticated root screen.
    func test_didLogin_authenticatesAndResetsPath() {
        sut.push(.catList)

        sut.didLogin()

        XCTAssertTrue(sut.isAuthenticated)
        XCTAssertTrue(sut.path.isEmpty)
    }

    /// `didLogout()` clears the session and any screen pushed while signed in.
    func test_didLogout_deauthenticatesAndResetsPath() {
        sut.didLogin()
        sut.push(.chuckNorris)

        sut.didLogout()

        XCTAssertFalse(sut.isAuthenticated)
        XCTAssertTrue(sut.path.isEmpty)
    }

    // MARK: Route factory

    /// Every `AppRoute` case produces a concrete destination view without trapping,
    /// protecting against missing cases in the factory's `switch`.
    func test_viewForRoute_buildsDestinationForEveryRoute() {
        let routes: [AppRoute] = [
            .catList,
            .chuckNorris,
            .catFeeds(makeImage()),
            .catDetail(image: makeImage(), related: [makeImage(id: "y")])
        ]

        for route in routes {
            // Building the view must not trap and must produce a concrete SwiftUI view.
            let view = sut.view(for: route)
            XCTAssertFalse(String(describing: type(of: view)).isEmpty, "Failed for route: \(route)")
        }
    }

    // MARK: Route equality / hashing

    /// `AppRoute` value semantics: routes carrying identical payloads compare equal
    /// and hash alike (required for correct `NavigationPath` behaviour), while
    /// distinct cases differ.
    func test_routes_withSameAssociatedValuesAreEqual() {
        let image = makeImage()
        let related = [makeImage(id: "z")]

        XCTAssertEqual(AppRoute.catDetail(image: image, related: related), .catDetail(image: image, related: related))
        XCTAssertEqual(AppRoute.catFeeds(image), .catFeeds(image))
        XCTAssertNotEqual(AppRoute.catList, .chuckNorris)
        XCTAssertEqual(AppRoute.catFeeds(image).hashValue, AppRoute.catFeeds(image).hashValue)
    }
}
