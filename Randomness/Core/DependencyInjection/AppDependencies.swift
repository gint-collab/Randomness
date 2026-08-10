//
//  AppDependencies.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/9/26.
//

import SwiftUI

/// Single composition root exposing every service abstraction.
protocol AppDependenciesProtocol {
    var httpClient: HTTPClientProtocol { get }
    var catService: CatServiceProtocol { get }
    var chuckNorrisService: ChuckNorrisServiceProtocol { get }
}

struct AppDependencies: AppDependenciesProtocol {
    let httpClient: HTTPClientProtocol
    let catService: CatServiceProtocol
    let chuckNorrisService: ChuckNorrisServiceProtocol

    init(httpClient: HTTPClientProtocol = HTTPClient()) {
        self.httpClient = httpClient
        self.catService = CatService(client: httpClient)
        self.chuckNorrisService = ChuckNorrisService(client: httpClient)
    }
}

private struct AppDependenciesKey: EnvironmentKey {
    static let defaultValue: AppDependenciesProtocol = AppDependencies()
}

extension EnvironmentValues {
    var dependencies: AppDependenciesProtocol {
        get { self[AppDependenciesKey.self] }
        set { self[AppDependenciesKey.self] = newValue }
    }
}
