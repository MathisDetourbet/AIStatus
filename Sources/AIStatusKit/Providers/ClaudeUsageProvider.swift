import Foundation

public enum UsageError: Error, Equatable {
    case noCredentials
    case tokenExpired
    case rateLimited
    case network
}

public protocol UsageProviding: Sendable {
    func fetchUsage() async throws -> UsageSnapshot
}

public struct ClaudeUsageProvider: UsageProviding {
    static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    static let betaHeader = "oauth-2025-04-20"
    /// Required — without a claude-code User-Agent the endpoint 429s persistently.
    static let userAgent = "claude-code/2.0.0"

    private let credentialsReader: any ClaudeCredentialsReading
    private let session: URLSession

    public init(
        credentialsReader: any ClaudeCredentialsReading = KeychainClaudeCredentialsReader(),
        session: URLSession = .shared
    ) {
        self.credentialsReader = credentialsReader
        self.session = session
    }

    public func fetchUsage() async throws -> UsageSnapshot {
        let credentials: ClaudeCredentials
        do {
            credentials = try credentialsReader.readCredentials()
        } catch {
            throw UsageError.noCredentials
        }
        if let expiresAt = credentials.expiresAt, expiresAt <= Date() {
            throw UsageError.tokenExpired
        }

        var request = URLRequest(url: Self.usageURL)
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(Self.betaHeader, forHTTPHeaderField: "anthropic-beta")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw UsageError.network
        }

        if let http = response as? HTTPURLResponse {
            switch http.statusCode {
            case 200..<300: break
            case 401, 403: throw UsageError.tokenExpired
            case 429: throw UsageError.rateLimited
            default: throw UsageError.network
            }
        }

        guard let snapshot = try? UsageSnapshot(data: data) else {
            throw UsageError.network
        }
        return snapshot
    }
}
