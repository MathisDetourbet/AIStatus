import Foundation
import Security

/// Reads the OAuth credentials Claude Code stores in the login Keychain.
/// First access triggers macOS's one-time permission dialog.
public struct KeychainClaudeCredentialsReader: ClaudeCredentialsReading {
    static let service = "Claude Code-credentials"

    public init() {}

    public func readCredentials() throws -> ClaudeCredentials {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else {
            throw CredentialsError.notFound
        }
        guard status == errSecSuccess, let data = item as? Data else {
            throw CredentialsError.unreadable
        }
        return try ClaudeCredentials(json: data)
    }
}
