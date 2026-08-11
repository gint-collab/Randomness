//
//  HTTPClientXCTests.swift
//  RandomnessTests
//
//  Created by Septuagint Murito on 8/11/26.
//

import XCTest
@testable import Randomness

// MARK: - Test doubles

/// `URLProtocol` stub used by the XCTest suite.
final class XCTStubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse?, Data))?

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [XCTStubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = XCTStubURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            if let response {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            } else {
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

private struct XCTTestEndpoint: EndpointProtocol {
    var baseURL = URL(string: "https://example.com")!
    var path = "/items"
    var method: HTTPMethod = .get
    var queryItems: [URLQueryItem] = []
    var headers: [String: String] = ["Accept": "application/json"]
    var body: Data?
}

private struct XCTPayload: Codable, Equatable, Sendable {
    let id: Int
    let name: String
}

private final class RequestBox: @unchecked Sendable {
    var value: URLRequest?
}

// MARK: - Tests

final class HTTPClientXCTests: XCTestCase {

    override func tearDown() {
        XCTStubURLProtocol.handler = nil
        super.tearDown()
    }

    private func makeClient(
        decoder: JSONDecoder = JSONDecoder(),
        handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse?, Data)
    ) -> HTTPClient {
        XCTStubURLProtocol.handler = handler
        return HTTPClient(session: XCTStubURLProtocol.makeSession(), decoder: decoder)
    }

    private func httpResponse(
        _ statusCode: Int,
        url: URL = URL(string: "https://example.com/items")!
    ) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: nil)!
    }

    // MARK: Endpoint

    func test_endpoint_buildsRequestFromBaseURLAndPath() throws {
        let request = try XCTTestEndpoint().urlRequest()

        XCTAssertEqual(request.url?.absoluteString, "https://example.com/items")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertNil(request.httpBody)
    }

    func test_endpoint_appendsQueryItems() throws {
        var endpoint = XCTTestEndpoint()
        endpoint.queryItems = [URLQueryItem(name: "limit", value: "5")]

        let request = try endpoint.urlRequest()

        XCTAssertEqual(request.url?.query, "limit=5")
    }

    func test_endpoint_appliesMethodBodyAndHeaders() throws {
        var endpoint = XCTTestEndpoint()
        endpoint.method = .post
        endpoint.body = Data("{}".utf8)
        endpoint.headers = ["Content-Type": "application/json"]

        let request = try endpoint.urlRequest()

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.httpBody, Data("{}".utf8))
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    // MARK: Success paths

    func test_request_decodesSuccessfulResponse() async throws {
        let expected = XCTPayload(id: 1, name: "Randomness")
        let client = makeClient { _ in (self.httpResponse(200), try JSONEncoder().encode(expected)) }

        let result = try await client.request(XCTTestEndpoint(), as: XCTPayload.self)

        XCTAssertEqual(result, expected)
    }

    func test_request_sendsRequestBuiltByEndpoint() async throws {
        let box = RequestBox()
        var endpoint = XCTTestEndpoint()
        endpoint.queryItems = [URLQueryItem(name: "limit", value: "3")]

        let client = makeClient { request in
            box.value = request
            return (self.httpResponse(200), Data(#"{"id":1,"name":"a"}"#.utf8))
        }

        _ = try await client.request(endpoint, as: XCTPayload.self)

        XCTAssertEqual(box.value?.url?.absoluteString, "https://example.com/items?limit=3")
        XCTAssertEqual(box.value?.httpMethod, "GET")
        XCTAssertEqual(box.value?.cachePolicy, .reloadIgnoringLocalAndRemoteCacheData)
    }

    func test_request_genericOverloadInfersType() async throws {
        let expected = XCTPayload(id: 7, name: "inferred")
        let client = makeClient { _ in (self.httpResponse(200), try JSONEncoder().encode(expected)) }

        let result: XCTPayload = try await client.request(XCTTestEndpoint())

        XCTAssertEqual(result, expected)
    }

    func test_request_acceptsEverySuccessStatusCode() async throws {
        for code in [200, 201, 204, 299] {
            let client = makeClient { _ in (self.httpResponse(code), Data(#"{"id":1,"name":"ok"}"#.utf8)) }

            let result = try await client.request(XCTTestEndpoint(), as: XCTPayload.self)

            XCTAssertEqual(result.id, 1, "Failed for status code \(code)")
        }
    }

    func test_request_usesInjectedDecoder() async throws {
        struct SnakePayload: Decodable, Sendable { let userName: String }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let client = makeClient(decoder: decoder) { _ in
            (self.httpResponse(200), Data(#"{"user_name":"septuagint"}"#.utf8))
        }

        let result = try await client.request(XCTTestEndpoint(), as: SnakePayload.self)

        XCTAssertEqual(result.userName, "septuagint")
    }

    // MARK: Failure paths

    func test_request_throwsStatusCodeErrorForFailureResponses() async throws {
        for code in [300, 400, 404, 500] {
            let client = makeClient { _ in (self.httpResponse(code), Data("{}".utf8)) }

            do {
                _ = try await client.request(XCTTestEndpoint(), as: XCTPayload.self)
                XCTFail("Expected an error for status code \(code)")
            } catch let error as NetworkError {
                guard case .statusCode(let received) = error else {
                    return XCTFail("Expected .statusCode, got \(error)")
                }
                XCTAssertEqual(received, code)
            }
        }
    }

    func test_request_throwsInvalidResponseForNonHTTPResponse() async throws {
        let client = makeClient { _ in (nil, Data("{}".utf8)) }

        do {
            _ = try await client.request(XCTTestEndpoint(), as: XCTPayload.self)
            XCTFail("Expected an error")
        } catch let error as NetworkError {
            guard case .invalidResponse = error else {
                return XCTFail("Expected .invalidResponse, got \(error)")
            }
        }
    }

    func test_request_throwsDecodingErrorForMismatchedPayload() async throws {
        let client = makeClient { _ in (self.httpResponse(200), Data(#"{"unexpected":true}"#.utf8)) }

        do {
            _ = try await client.request(XCTTestEndpoint(), as: XCTPayload.self)
            XCTFail("Expected an error")
        } catch let error as NetworkError {
            guard case .decoding = error else {
                return XCTFail("Expected .decoding, got \(error)")
            }
        }
    }

    func test_request_wrapsTransportFailureInUnderlying() async throws {
        let client = makeClient { _ in throw URLError(.notConnectedToInternet) }

        do {
            _ = try await client.request(XCTTestEndpoint(), as: XCTPayload.self)
            XCTFail("Expected an error")
        } catch let error as NetworkError {
            guard case .underlying(let underlying) = error else {
                return XCTFail("Expected .underlying, got \(error)")
            }
            XCTAssertEqual((underlying as? URLError)?.code, .notConnectedToInternet)
        }
    }

    // MARK: NetworkError

    func test_networkError_providesUserFacingDescriptions() {
        XCTAssertEqual(NetworkError.invalidURL.errorDescription, "The request URL is invalid.")
        XCTAssertEqual(NetworkError.invalidResponse.errorDescription, "The server returned an invalid response.")
        XCTAssertEqual(NetworkError.statusCode(503).errorDescription, "Request failed with status code 503.")
        XCTAssertEqual(NetworkError.decoding(URLError(.badURL)).errorDescription, "Unable to read the server response.")

        let underlying = URLError(.timedOut)
        XCTAssertEqual(NetworkError.underlying(underlying).errorDescription, underlying.localizedDescription)
    }
}
