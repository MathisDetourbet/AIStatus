import Testing
@testable import AIStatusKit

@Suite("Cursor Provider")
struct CursorProviderTests {
    @Test func `has correct name`() {
        #expect(AI.cursor.name == "Cursor")
    }

    @Test func `has correct base URL`() {
        #expect(AI.cursor.baseURL.absoluteString == "https://status.cursor.com")
    }
}
