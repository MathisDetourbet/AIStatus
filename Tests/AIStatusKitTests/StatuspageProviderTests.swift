import Foundation
import Testing
@testable import AIStatusKit

@Test func `provider has correct API endpoint`() {
    let provider = StatuspageProvider(
        name: "TestService",
        baseURL: URL(string: "https://status.example.com")!
    )
    #expect(provider.name == "TestService")
    #expect(provider.statusURL.absoluteString == "https://status.example.com/api/v2/status.json")
}

@Test func `provider parses operational response`() async throws {
    let json = Data("""
    {"status":{"indicator":"none","description":"All Systems Operational"}}
    """.utf8)

    let provider = StatuspageProvider(
        name: "Test",
        baseURL: URL(string: "https://status.example.com")!,
        session: .mock(data: json, statusCode: 200)
    )
    let status = try await provider.fetchStatus()
    #expect(status == .operational)
}

@Test func `provider parses major response`() async throws {
    let json = Data("""
    {"status":{"indicator":"major","description":"Major System Outage"}}
    """.utf8)

    let provider = StatuspageProvider(
        name: "Test",
        baseURL: URL(string: "https://status.example.com")!,
        session: .mock(data: json, statusCode: 200)
    )
    let status = try await provider.fetchStatus()
    #expect(status == .major)
}

@Test func `provider returns nil on network error`() async {
    let provider = StatuspageProvider(
        name: "Test",
        baseURL: URL(string: "https://status.example.com")!,
        session: .mock(error: URLError(.notConnectedToInternet))
    )
    let status = try? await provider.fetchStatus()
    #expect(status == nil)
}
