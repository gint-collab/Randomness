//
//  MockHTTPClientXCTests.swift
//  RandomnessTests
//
//  Created by Septuagint Murito on 8/11/26.
//

import XCTest
@testable import Randomness

// MARK: - Fixtures

private struct XCTMockEndpoint: EndpointProtocol {
    var baseURL = URL(string: "https://example.com")!
    var path = "/items"
}

private struct XCTOtherMockEndpoint: EndpointProtocol {
    var baseURL = URL(string: "https://example.com")!
    var path = "/others"
}

private struct XCTMockPayload: Codable, Equatable, Sendable {
    let id: Int
}

// MARK: - Tests

final class MockHTTPClientXCTests: XCTestCase {

    func test_request_returnsStubbedValueWhenTypeMatches() async throws {
        let expected = XCTMockPayload(id: 42)
        let sut = MockHTTPClient(value: expected)

        let result = try await sut.request(XCTMockEndpoint(), as: XCTMockPayload.self)

        XCTAssertEqual(result, expected)
    }

    func test_request_throwsStubbedError() async throws {
        let sut = MockHTTPClient(error: NetworkError.statusCode(404))

        do {
            _ = try await sut.request(XCTMockEndpoint(), as: XCTMockPayload.self)
            XCTFail("Expected an error")
        } catch let error as NetworkError {
            guard case .statusCode(let code) = error else {
                return XCTFail("Expected .statusCode, got \(error)")
            }
            XCTAssertEqual(code, 404)
        }
    }

    func test_request_handlerCanVaryTheValuePerEndpoint() async throws {
        let sut = MockHTTPClient { endpoint in
            XCTMockPayload(id: endpoint is XCTMockEndpoint ? 1 : 2)
        }

        let first = try await sut.request(XCTMockEndpoint(), as: XCTMockPayload.self)
        let second = try await sut.request(XCTOtherMockEndpoint(), as: XCTMockPayload.self)

        XCTAssertEqual(first.id, 1)
        XCTAssertEqual(second.id, 2)
    }

    func test_request_handlerErrorsArePropagated() async throws {
        let sut = MockHTTPClient { _ in throw NetworkError.invalidURL }

        do {
            _ = try await sut.request(XCTMockEndpoint(), as: XCTMockPayload.self)
            XCTFail("Expected an error")
        } catch let error as NetworkError {
            guard case .invalidURL = error else {
                return XCTFail("Expected .invalidURL, got \(error)")
            }
        }
    }

    func test_request_throwsInvalidResponseWhenStubbedValueHasWrongType() async throws {
        let sut = MockHTTPClient(value: "not a payload")

        do {
            _ = try await sut.request(XCTMockEndpoint(), as: XCTMockPayload.self)
            XCTFail("Expected an error")
        } catch let error as NetworkError {
            guard case .invalidResponse = error else {
                return XCTFail("Expected .invalidResponse, got \(error)")
            }
        }
    }

    func test_init_responseCaseIsStoredAsProvided() async throws {
        let sut = MockHTTPClient(response: .success(XCTMockPayload(id: 7)))

        let result = try await sut.request(XCTMockEndpoint(), as: XCTMockPayload.self)

        XCTAssertEqual(result.id, 7)
    }
}
