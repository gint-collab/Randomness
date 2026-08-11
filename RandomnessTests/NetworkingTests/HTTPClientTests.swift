//
//  HTTPClientTests.swift
//  RandomnessTests
//
//  Created by Septuagint Murito on 8/11/26.
//

import Foundation
import Testing
@testable import Randomness

// MARK: - Test doubles

/// `URLProtocol` stub that lets each test decide what the "server" returns.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    /// Handler is set per-test; access is serialised by running tests in the same process.
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse?, Data))?

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = StubURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            if let response {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            } else {
                // Simulate a non-HTTP response.
                let urlResponse = URLResponse(
                    url: request.url!,
                    mimeType: nil,
                    expectedContentLength: data.count,
                    textEncodingName: nil
                )
                client?.urlProtocol(self, didReceive: urlResponse, cacheStoragePolicy: .notAllowed)
            }
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private struct TestEndpoint: EndpointProtocol {
    var baseURL = URL(string: "https://example.com")!
    var path = "/items"
    var method: HTTPMethod = .get
    var queryItems: [URLQueryItem] = []
    var headers: [String: String] = ["Accept": "application/json"]
    var body: Data?
}

private struct Payload: Codable, Equatable, Sendable {
    let id: Int
    let name: String
}

private func httpResponse(_ statusCode: Int, url: URL = URL(string: "https://example.com/items")!) -> HTTPURLResponse {
    HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: nil)!
}

// MARK: - Endpoint tests

@Suite("EndpointProtocol")
struct EndpointProtocolTests {

    @Test("Builds a URLRequest from base URL and path")
    func buildsRequest() throws {
        let request = try TestEndpoint().urlRequest()

        #expect(request.url?.absoluteString == "https://example.com/items")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request.httpBody == nil)
    }

    @Test("Appends query items when present")
    func appendsQueryItems() throws {
        var endpoint = TestEndpoint()
        endpoint.queryItems = [URLQueryItem(name: "limit", value: "5")]

        let request = try endpoint.urlRequest()

        #expect(request.url?.query == "limit=5")
    }

    @Test("Applies method, body and custom headers")
    func appliesMethodBodyAndHeaders() throws {
        var endpoint = TestEndpoint()
        endpoint.method = .post
        endpoint.body = Data("{}".utf8)
        endpoint.headers = ["Content-Type": "application/json"]

        let request = try endpoint.urlRequest()

        #expect(request.httpMethod == "POST")
        #expect(request.httpBody == Data("{}".utf8))
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }
}

// MARK: - HTTPClient tests

@Suite(.serialized)
struct HTTPClientTests {

    private func makeClient(
        decoder: JSONDecoder = JSONDecoder(),
        handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse?, Data)
    ) -> HTTPClient {
        StubURLProtocol.handler = handler
        return HTTPClient(session: StubURLProtocol.makeSession(), decoder: decoder)
    }

    @Test("Decodes a successful response")
    func decodesSuccess() async throws {
        let expected = Payload(id: 1, name: "Randomness")
        let client = makeClient { _ in (httpResponse(200), try JSONEncoder().encode(expected)) }

        let result = try await client.request(TestEndpoint(), as: Payload.self)

        #expect(result == expected)
    }

    @Test("Sends the request built by the endpoint")
    func sendsBuiltRequest() async throws {
        let captured = Capture()
        var endpoint = TestEndpoint()
        endpoint.queryItems = [URLQueryItem(name: "limit", value: "3")]

        let client = makeClient { request in
            captured.value = request
            return (httpResponse(200), Data("{\"id\":1,\"name\":\"a\"}".utf8))
        }

        _ = try await client.request(endpoint, as: Payload.self)

        #expect(captured.value?.url?.absoluteString == "https://example.com/items?limit=3")
        #expect(captured.value?.httpMethod == "GET")
        #expect(captured.value?.cachePolicy == .reloadIgnoringLocalAndRemoteCacheData)
    }

    @Test("Generic overload infers the decoded type")
    func genericOverload() async throws {
        let expected = Payload(id: 7, name: "inferred")
        let client = makeClient { _ in (httpResponse(200), try JSONEncoder().encode(expected)) }

        let result: Payload = try await client.request(TestEndpoint())

        #expect(result == expected)
    }

    @Test("Throws .statusCode for non-2xx responses", arguments: [300, 400, 404, 500])
    func throwsOnFailureStatus(code: Int) async throws {
        let client = makeClient { _ in (httpResponse(code), Data("{}".utf8)) }

        await #expect(throws: NetworkError.self) {
            _ = try await client.request(TestEndpoint(), as: Payload.self)
        }

        do {
            _ = try await client.request(TestEndpoint(), as: Payload.self)
            Issue.record("Expected an error")
        } catch let error as NetworkError {
            guard case .statusCode(let received) = error else {
                Issue.record("Expected .statusCode, got \(error)")
                return
            }
            #expect(received == code)
        }
    }

    @Test("Accepts every 2xx status code", arguments: [200, 201, 204, 299])
    func acceptsSuccessStatus(code: Int) async throws {
        let client = makeClient { _ in (httpResponse(code), Data("{\"id\":1,\"name\":\"ok\"}".utf8)) }

        let result = try await client.request(TestEndpoint(), as: Payload.self)

        #expect(result.id == 1)
    }

    @Test("Throws .invalidResponse for a non-HTTP response")
    func throwsOnNonHTTPResponse() async throws {
        let client = makeClient { _ in (nil, Data("{}".utf8)) }

        do {
            _ = try await client.request(TestEndpoint(), as: Payload.self)
            Issue.record("Expected an error")
        } catch let error as NetworkError {
            guard case .invalidResponse = error else {
                Issue.record("Expected .invalidResponse, got \(error)")
                return
            }
        }
    }

    @Test("Throws .decoding when the payload does not match")
    func throwsOnDecodingFailure() async throws {
        let client = makeClient { _ in (httpResponse(200), Data("{\"unexpected\":true}".utf8)) }

        do {
            _ = try await client.request(TestEndpoint(), as: Payload.self)
            Issue.record("Expected an error")
        } catch let error as NetworkError {
            guard case .decoding = error else {
                Issue.record("Expected .decoding, got \(error)")
                return
            }
        }
    }

    @Test("Wraps transport failures in .underlying")
    func wrapsTransportError() async throws {
        let client = makeClient { _ in throw URLError(.notConnectedToInternet) }

        do {
            _ = try await client.request(TestEndpoint(), as: Payload.self)
            Issue.record("Expected an error")
        } catch let error as NetworkError {
            guard case .underlying(let underlying) = error else {
                Issue.record("Expected .underlying, got \(error)")
                return
            }
            #expect((underlying as? URLError)?.code == .notConnectedToInternet)
        }
    }

    @Test("Uses the injected decoder")
    func usesInjectedDecoder() async throws {
        struct SnakePayload: Decodable, Sendable { let userName: String }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let client = makeClient(decoder: decoder) { _ in
            (httpResponse(200), Data("{\"user_name\":\"septuagint\"}".utf8))
        }

        let result = try await client.request(TestEndpoint(), as: SnakePayload.self)

        #expect(result.userName == "septuagint")
    }
}

// MARK: - NetworkError tests

@Suite("NetworkError")
struct NetworkErrorTests {

    @Test("Provides user-facing descriptions")
    func descriptions() {
        #expect(NetworkError.invalidURL.errorDescription == "The request URL is invalid.")
        #expect(NetworkError.invalidResponse.errorDescription == "The server returned an invalid response.")
        #expect(NetworkError.statusCode(503).errorDescription == "Request failed with status code 503.")
        #expect(NetworkError.decoding(URLError(.badURL)).errorDescription == "Unable to read the server response.")

        let underlying = URLError(.timedOut)
        #expect(NetworkError.underlying(underlying).errorDescription == underlying.localizedDescription)
    }
}

// MARK: - Helpers

/// Small reference box so escaping stub closures can hand values back to the test.
private final class Capture: @unchecked Sendable {
    var value: URLRequest?
}
