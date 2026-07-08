import Foundation

public struct ClaudeCredentials: Sendable, Equatable {
    public let accessToken: String
    public let expiresAt: Date?

    public init(accessToken: String, expiresAt: Date?) {
        self.accessToken = accessToken
        self.expiresAt = expiresAt
    }
}

public enum CredentialsError: Error, Equatable {
    case notFound
    case unreadable
}

public protocol ClaudeCredentialsReading: Sendable {
    func readCredentials() throws -> ClaudeCredentials
}

extension ClaudeCredentials {
    /// Parses the JSON Claude Code stores in the Keychain item "Claude Code-credentials":
    /// `{"claudeAiOauth": {"accessToken": "...", "expiresAt": <epoch milliseconds>, ...}}`
    init(json data: Data) throws {
        struct Wrapper: Decodable {
            struct OAuth: Decodable {
                let accessToken: String
                let expiresAt: Double?
            }
            let claudeAiOauth: OAuth
        }
        guard let wrapper = try? JSONDecoder().decode(Wrapper.self, from: data) else {
            throw CredentialsError.unreadable
        }
        self.init(
            accessToken: wrapper.claudeAiOauth.accessToken,
            expiresAt: wrapper.claudeAiOauth.expiresAt.map { Date(timeIntervalSince1970: $0 / 1000) }
        )
    }
}
