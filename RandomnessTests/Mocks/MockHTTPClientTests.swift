//
//  MockHTTPClientTests.swift
//  RandomnessTests
//
//  Created by Septuagint Murito on 8/11/26.
//

import Foundation
import Testing
@testable import Randomness

private struct MockEndpoint: EndpointProtocol {
    var baseURL = URL(string: "https://example.com")!
    var path = "/items"
}

private struct OtherMockEndpoint: EndpointProtocol {
    var baseURL = URL(string: "https://example.com")!
    var path = "/others"
}

private struct MockPayload: Codable, Equatable, Sendable {
    let id: Int
}

@Suite("MockHTTPClient")
struct MockHTTPClientTests {

    @Test("Returns the stubbed value when the type matches")
    func returnsStubbedValue() async throws {
        let expected = MockPayload(id: 42)
        let sut = MockHTTPClient(value: expected)

        let result = try await sut.request(MockEndpoint(), as: MockPayload.self)

        #expect(result == expected)
    }

    @Test("Throws the stubbed error")
    func throwsStubbedError() async throws {
        let sut = MockHTTPClient(error: NetworkError.statusCode(404))

        do {
            _ = try await sut.request(MockEndpoint(), as: MockPayload.self)
            Issue.record("Expected an error")
        } catch let error as NetworkError {
            guard case .statusCode(404) = error else {
                Issue.record("Expected .statusCode(404), got \(error)")
                return
            }
        }
    }

    @Test("Handler can vary the value per endpoint")
    func handlerVariesPerEndpoint() async throws {
        let sut = MockHTTPClient { endpoint in
            MockPayload(id: endpoint is MockEndpoint ? 1 : 2)
        }

        let first = try await sut.request(MockEndpoint(), as: MockPayload.self)
        let second = try await sut.request(OtherMockEndpoint(), as: MockPayload.self)

        #expect(first.id == 1)
        #expect(second.id == 2)
    }

    @Test("Throws .invalidResponse when the stubbed value has the wrong type")
    func throwsOnTypeMismatch() async throws {
        let sut = MockHTTPClient(value: "not a payload")

        do {
            _ = try await sut.request(MockEndpoint(), as: MockPayload.self)
            Issue.record("Expected an error")
        } catch let error as NetworkError {
            guard case .invalidResponse = error else {
                Issue.record("Expected .invalidResponse, got \(error)")
                return
            }
        }
    }
}
