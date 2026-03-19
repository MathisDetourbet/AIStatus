import Foundation

public struct StatuspageProvider: StatusProvider {
    public let name: String
    public let baseURL: URL
    public let statusURL: URL
    private let session: URLSession

    public init(name: String, baseURL: URL, session: URLSession = .shared) {
        self.name = name
        self.baseURL = baseURL
        self.statusURL = baseURL.appendingPathComponent("api/v2/status.json")
        self.session = session
    }

    public func fetchStatus() async throws -> AIStatus {
        let (data, _) = try await session.data(from: statusURL)
        let response = try JSONDecoder().decode(StatusResponse.self, from: data)
        return StatusResponse.mapIndicator(response.status.indicator)
    }
}
