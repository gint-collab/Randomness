//
//  MockHTTPClient.swift
//  RandomnessTests
//
//  Created by Septuagint Murito on 8/9/26.
//

import Foundation
@testable import Randomness

/// Protocol-oriented test double for `HTTPClientProtocol`.
///
/// Use this when the unit under test only depends on `HTTPClientProtocol` (e.g. a
/// ViewModel or repository). To exercise the real `HTTPClient` networking stack,
/// use the `URLProtocol` stubs in `NetworkingTests` instead.
struct MockHTTPClient: HTTPClientProtocol {
    enum Response: @unchecked Sendable {
        /// Same value returned for every request.
        case success(Any)
        /// Same error thrown for every request.
        case failure(Error)
        /// Value decided per endpoint, for units that make several different calls.
        case handler(@Sendable (EndpointProtocol) throws -> Any)
    }

    let response: Response

    init(response: Response) {
        self.response = response
    }

    init(value: Any) {
        self.init(response: .success(value))
    }

    init(error: Error) {
        self.init(response: .failure(error))
    }

    init(handler: @escaping @Sendable (EndpointProtocol) throws -> Any) {
        self.init(response: .handler(handler))
    }

    nonisolated func request<T: Decodable & Sendable>(_ endpoint: EndpointProtocol, as type: T.Type) async throws -> T {
        switch response {
        case .failure(let error):
            throw error
        case .success(let value):
            return try cast(value)
        case .handler(let handler):
            return try cast(handler(endpoint))
        }
    }

    private func cast<T>(_ value: Any) throws -> T {
        guard let typed = value as? T else { throw NetworkError.invalidResponse }
        return typed
    }
}
