import Foundation
import Testing
@testable import AIStatusKit

@Test func `decodes operational status`() throws {
    let json = """
    {"status":{"indicator":"none","description":"All Systems Operational"}}
    """
    let response = try JSONDecoder().decode(StatusResponse.self, from: Data(json.utf8))
    #expect(response.status.indicator == "none")
    #expect(response.status.description == "All Systems Operational")
}

@Test func `map indicator none to operational`() {
    #expect(StatusResponse.mapIndicator("none") == .operational)
}

@Test func `map indicator minor to minor`() {
    #expect(StatusResponse.mapIndicator("minor") == .minor)
}

@Test func `map indicator major to major`() {
    #expect(StatusResponse.mapIndicator("major") == .major)
}

@Test func `map indicator critical to major`() {
    #expect(StatusResponse.mapIndicator("critical") == .major)
}

@Test func `map unknown indicator to unknown`() {
    #expect(StatusResponse.mapIndicator("something_else") == .unknown)
}
