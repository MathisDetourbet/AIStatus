import Foundation
import Testing
@testable import AIStatusKit

struct StubProvider: StatusProvider {
    let name: String
    let baseURL: URL
    let result: ServiceStatus

    init(name: String, result: ServiceStatus) {
        self.name = name
        self.baseURL = URL(string: "https://example.com")!
        self.result = result
    }

    func fetchStatus() async throws -> ServiceStatus {
        result
    }
}

@Test func `monitor refreshes statuses`() async {
    let monitor = await StatusMonitor(providers: [
        StubProvider(name: "ServiceA", result: .operational),
        StubProvider(name: "ServiceB", result: .minor),
    ])
    await monitor.refresh()
    let statuses = await monitor.statuses
    #expect(statuses["ServiceA"] == .operational)
    #expect(statuses["ServiceB"] == .minor)
}

@Test func `overall status is worst`() async {
    let monitor = await StatusMonitor(providers: [
        StubProvider(name: "A", result: .operational),
        StubProvider(name: "B", result: .major),
    ])
    await monitor.refresh()
    let overall = await monitor.overallStatus
    #expect(overall == .major)
}

@Test func `overall status defaults to unknown`() async {
    let monitor = await StatusMonitor(providers: [])
    let overall = await monitor.overallStatus
    #expect(overall == .unknown)
}
