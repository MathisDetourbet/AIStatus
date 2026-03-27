import Foundation
import NonEmpty
import Testing
@testable import AIStatusKit

struct StubProvider: StatusProvider {
    let name: String
    let baseURL: URL
    let result: AIStatus

    init(name: String, result: AIStatus) {
        self.name = name
        self.baseURL = URL(string: "https://example.com")!
        self.result = result
    }

    func fetchStatus() async throws -> AIStatus {
        result
    }
}

@Test func `monitor refreshes statuses`() async {
    let monitor = await StatusMonitor(providers: NonEmptyArray(rawValue: [
        StubProvider(name: "ServiceA", result: .operational),
        StubProvider(name: "ServiceB", result: .minor),
    ])!)
    await monitor.refresh()
    let statuses = await monitor.statuses
    #expect(statuses["ServiceA"] == .operational)
    #expect(statuses["ServiceB"] == .minor)
}

@Test func `overall status is worst`() async {
    let monitor = await StatusMonitor(providers: NonEmptyArray(rawValue: [
        StubProvider(name: "A", result: .operational),
        StubProvider(name: "B", result: .major),
    ])!)
    await monitor.refresh()
    let overall = await monitor.overallStatus
    #expect(overall == .major)
}

@Test func `overall status defaults to unknown when no refresh`() async {
    let monitor = await StatusMonitor(providers: NonEmptyArray(rawValue: [
        StubProvider(name: "A", result: .operational),
    ])!)
    let overall = await monitor.overallStatus
    #expect(overall == .unknown)
}

@Test func `selected provider defaults to first provider`() async {
    let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    let monitor = await StatusMonitor(
        providers: NonEmptyArray(rawValue: [
            StubProvider(name: "Claude", result: .operational),
        ])!,
        defaults: defaults
    )
    let selected = await monitor.selectedProvider.name
    #expect(selected == "Claude")
}

@Test func `selected provider restores from UserDefaults`() async {
    let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    defaults.set("OpenAI", forKey: "selectedProvider")
    let monitor = await StatusMonitor(
        providers: NonEmptyArray(rawValue: [
            StubProvider(name: "Claude", result: .operational),
            StubProvider(name: "OpenAI", result: .major),
        ])!,
        defaults: defaults
    )
    let selected = await monitor.selectedProvider.name
    #expect(selected == "OpenAI")
}

@Test func `selectedStatus reflects selected provider`() async {
    let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    let openai = StubProvider(name: "OpenAI", result: .major)
    let monitor = await StatusMonitor(
        providers: NonEmptyArray(rawValue: [
            StubProvider(name: "Claude", result: .operational),
            openai,
        ])!,
        defaults: defaults
    )
    await monitor.refresh()
    await MainActor.run { monitor.selectedProvider = openai }
    let status = await monitor.selectedStatus
    #expect(status == .major)
}

@Test func `selectedStatus returns unknown before refresh`() async {
    let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    let monitor = await StatusMonitor(
        providers: NonEmptyArray(rawValue: [
            StubProvider(name: "Claude", result: .operational),
        ])!,
        defaults: defaults
    )
    let status = await monitor.selectedStatus
    #expect(status == .unknown)
}

@Test func `setting selectedProvider persists to UserDefaults`() async {
    let suiteName = "test-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    let openai = StubProvider(name: "OpenAI", result: .operational)
    let monitor = await StatusMonitor(
        providers: NonEmptyArray(rawValue: [
            StubProvider(name: "Claude", result: .operational),
            openai,
        ])!,
        defaults: defaults
    )
    await MainActor.run { monitor.selectedProvider = openai }
    let persisted = UserDefaults(suiteName: suiteName)!.string(forKey: "selectedProvider")
    #expect(persisted == "OpenAI")
}
