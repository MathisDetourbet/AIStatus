import Foundation
import Synchronization

struct MockHandler: Sendable {
    let data: Data?
    let statusCode: Int
    let error: (any Error)?
}

final class MockRegistry: Sendable {
    static let shared = MockRegistry()

    private let storage = Mutex<[String: MockHandler]>([:])

    func register(id: String, handler: MockHandler) {
        storage.withLock { $0[id] = handler }
    }

    func handler(for id: String) -> MockHandler? {
        storage.withLock { $0[id] }
    }
}

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    static let idHeader = "X-Mock-ID"

    override class func canInit(with request: URLRequest) -> Bool {
        request.value(forHTTPHeaderField: idHeader) != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let mockID = request.value(forHTTPHeaderField: Self.idHeader),
              let handler = MockRegistry.shared.handler(for: mockID) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        if let error = handler.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: handler.statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if let data = handler.data {
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

extension URLSession {
    static func mock(data: Data? = nil, statusCode: Int = 200, error: (any Error)? = nil) -> URLSession {
        let id = UUID().uuidString
        MockRegistry.shared.register(id: id, handler: MockHandler(data: data, statusCode: statusCode, error: error))
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        config.httpAdditionalHeaders = [MockURLProtocol.idHeader: id]
        return URLSession(configuration: config)
    }
}
