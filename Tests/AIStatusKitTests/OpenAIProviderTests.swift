import Testing
@testable import AIStatusKit

@Suite("OpenAI Provider")
struct OpenAIProviderTests {
    @Test func `has correct name`() {
        #expect(AI.openai.name == "OpenAI")
    }

    @Test func `has correct base URL`() {
        #expect(AI.openai.baseURL.absoluteString == "https://status.openai.com")
    }
}
