import Testing
@testable import AIStatusKit

@Suite("Claude Provider")
struct ClaudeProviderTests {
    @Test func `has correct name`() {
        #expect(AI.claude.name == "Claude")
    }

    @Test func `has correct base URL`() {
        #expect(AI.claude.baseURL.absoluteString == "https://status.claude.com")
    }
}
