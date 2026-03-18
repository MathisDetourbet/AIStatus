import Foundation

public protocol StatusProvider: Sendable {
    var name: String { get }
    var baseURL: URL { get }
    func fetchStatus() async throws -> ServiceStatus
}
