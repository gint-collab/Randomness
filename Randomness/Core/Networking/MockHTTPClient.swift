//
//  MockHTTPClient.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/9/26.
//

import Foundation

/// Protocol-oriented test double for `HTTPClientProtocol`.
struct MockHTTPClient: HTTPClientProtocol {
    enum Response: @unchecked Sendable {
        case success(Any)
        case failure(Error)
    }

    let response: Response

    init(response: Response) {
        self.response = response
    }

    init(value: Any) {
        self.init(response: .success(value))
    }

    nonisolated func request<T: Decodable & Sendable>(_ endpoint: EndpointProtocol, as type: T.Type) async throws -> T {
        switch response {
        case .failure(let error):
            throw error
        case .success(let value):
            guard let typed = value as? T else { throw NetworkError.invalidResponse }
            return typed
        }
    }
}
