import Foundation
import Testing
@testable import AIStatusKit

struct StubCredentialsReader: ClaudeCredentialsReading {
    let result: Result<ClaudeCredentials, CredentialsError>

    func readCredentials() throws -> ClaudeCredentials {
        try result.get()
    }
}

@Suite("Claude Usage Provider")
struct ClaudeUsageProviderTests {
    let validCredentials = ClaudeCredentials(accessToken: "token", expiresAt: Date(timeIntervalSinceNow: 3600))

    @Test func `fetches usage snapshot on success`() async throws {
        let json = """
        { "five_hour": { "utilization": 42, "resets_at": "2026-07-08T15:00:00Z" }, "seven_day": { "utilization": 61 } }
        """.data(using: .utf8)!
        let provider = ClaudeUsageProvider(
            credentialsReader: StubCredentialsReader(result: .success(validCredentials)),
            session: .mock(data: json)
        )
        let snapshot = try await provider.fetchUsage()
        #expect(snapshot.sessionUtilization == 42)
        #expect(snapshot.weeklyUtilization == 61)
    }

    @Test func `missing credentials throws noCredentials`() async {
        let provider = ClaudeUsageProvider(
            credentialsReader: StubCredentialsReader(result: .failure(.notFound)),
            session: .mock()
        )
        await #expect(throws: UsageError.noCredentials) {
            try await provider.fetchUsage()
        }
    }

    @Test func `unreadable credentials throws noCredentials`() async {
        let provider = ClaudeUsageProvider(
            credentialsReader: StubCredentialsReader(result: .failure(.unreadable)),
            session: .mock()
        )
        await #expect(throws: UsageError.noCredentials) {
            try await provider.fetchUsage()
        }
    }

    @Test func `locally expired token throws tokenExpired without network call`() async {
        let expired = ClaudeCredentials(accessToken: "token", expiresAt: Date(timeIntervalSinceNow: -60))
        let provider = ClaudeUsageProvider(
            credentialsReader: StubCredentialsReader(result: .success(expired)),
            session: .mock(error: URLError(.notConnectedToInternet))
        )
        await #expect(throws: UsageError.tokenExpired) {
            try await provider.fetchUsage()
        }
    }

    @Test func `401 throws tokenExpired`() async {
        let provider = ClaudeUsageProvider(
            credentialsReader: StubCredentialsReader(result: .success(validCredentials)),
            session: .mock(data: Data(), statusCode: 401)
        )
        await #expect(throws: UsageError.tokenExpired) {
            try await provider.fetchUsage()
        }
    }

    @Test func `429 throws rateLimited`() async {
        let provider = ClaudeUsageProvider(
            credentialsReader: StubCredentialsReader(result: .success(validCredentials)),
            session: .mock(data: Data(), statusCode: 429)
        )
        await #expect(throws: UsageError.rateLimited) {
            try await provider.fetchUsage()
        }
    }

    @Test func `server error throws network`() async {
        let provider = ClaudeUsageProvider(
            credentialsReader: StubCredentialsReader(result: .success(validCredentials)),
            session: .mock(data: Data(), statusCode: 500)
        )
        await #expect(throws: UsageError.network) {
            try await provider.fetchUsage()
        }
    }

    @Test func `connection failure throws network`() async {
        let provider = ClaudeUsageProvider(
            credentialsReader: StubCredentialsReader(result: .success(validCredentials)),
            session: .mock(error: URLError(.notConnectedToInternet))
        )
        await #expect(throws: UsageError.network) {
            try await provider.fetchUsage()
        }
    }
}
