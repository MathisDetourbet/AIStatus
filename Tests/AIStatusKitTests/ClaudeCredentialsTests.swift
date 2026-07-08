import Foundation
import Testing
@testable import AIStatusKit

@Suite("Claude Credentials")
struct ClaudeCredentialsTests {
    @Test func `parses access token and millisecond expiry`() throws {
        let json = """
        { "claudeAiOauth": { "accessToken": "sk-ant-oat01-abc", "refreshToken": "sk-ant-ort01-xyz", "expiresAt": 1783609200000 } }
        """.data(using: .utf8)!
        let credentials = try ClaudeCredentials(json: json)
        #expect(credentials.accessToken == "sk-ant-oat01-abc")
        #expect(credentials.expiresAt == Date(timeIntervalSince1970: 1_783_609_200))
    }

    @Test func `parses credentials without expiry`() throws {
        let json = """
        { "claudeAiOauth": { "accessToken": "sk-ant-oat01-abc" } }
        """.data(using: .utf8)!
        let credentials = try ClaudeCredentials(json: json)
        #expect(credentials.accessToken == "sk-ant-oat01-abc")
        #expect(credentials.expiresAt == nil)
    }

    @Test func `malformed JSON throws unreadable`() {
        #expect(throws: CredentialsError.unreadable) {
            try ClaudeCredentials(json: "not json".data(using: .utf8)!)
        }
    }

    @Test func `missing claudeAiOauth key throws unreadable`() {
        let json = """
        { "other": {} }
        """.data(using: .utf8)!
        #expect(throws: CredentialsError.unreadable) {
            try ClaudeCredentials(json: json)
        }
    }
}
