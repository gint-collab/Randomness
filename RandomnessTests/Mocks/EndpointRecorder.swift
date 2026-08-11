//
//  EndpointRecorder.swift
//  RandomnessTests
//
//  Created by Septuagint Murito on 8/11/26.
//

import Foundation
@testable import Randomness

/// Records the endpoints a service asks for, so tests can assert on routing.
///
/// The project uses default main-actor isolation, which makes `EndpointProtocol`
/// members (`path`, `queryItems`, …) main-actor isolated and therefore unreadable
/// from `MockHTTPClient`'s `@Sendable` handler closure. Matching on the endpoint
/// *enum cases* sidesteps that entirely.
final class EndpointRecorder: @unchecked Sendable {
    private(set) var catCases: [CatEndpoint] = []
    private(set) var catImageCases: [CatImageEndpoint] = []
    private(set) var chuckNorrisCases: [ChuckNorrisEndpoint] = []

    func record(_ endpoint: EndpointProtocol) {
        switch endpoint {
        case let endpoint as CatEndpoint: catCases.append(endpoint)
        case let endpoint as CatImageEndpoint: catImageCases.append(endpoint)
        case let endpoint as ChuckNorrisEndpoint: chuckNorrisCases.append(endpoint)
        default: break
        }
    }
}
