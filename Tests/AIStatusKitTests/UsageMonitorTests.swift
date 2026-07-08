import Foundation
import Synchronization
import Testing
@testable import AIStatusKit

/// Returns queued results in order; throws `.network` when exhausted.
final class MockUsageProvider: UsageProviding, Sendable {
    private let results: Mutex<[Result<UsageSnapshot, UsageError>]>

    init(results: [Result<UsageSnapshot, UsageError>]) {
        self.results = Mutex(results)
    }

    func fetchUsage() async throws -> UsageSnapshot {
        let next = results.withLock { $0.isEmpty ? nil : $0.removeFirst() }
        guard let next else { throw UsageError.network }
        return try next.get()
    }
}

/// Counts fetches and holds each one open until `release()` is called, so a
/// second refresh can be attempted while the first is still in flight.
final class GatedUsageProvider: UsageProviding, Sendable {
    private let snapshot: UsageSnapshot
    let callCount = Mutex(0)
    private let gate = Mutex<CheckedContinuation<Void, Never>?>(nil)

    init(snapshot: UsageSnapshot) {
        self.snapshot = snapshot
    }

    func fetchUsage() async throws -> UsageSnapshot {
        callCount.withLock { $0 += 1 }
        await withCheckedContinuation { continuation in
            gate.withLock { $0 = continuation }
        }
        return snapshot
    }

    func release() {
        let continuation = gate.withLock { stored -> CheckedContinuation<Void, Never>? in
            defer { stored = nil }
            return stored
        }
        continuation?.resume()
    }
}

@Suite("Usage Monitor")
@MainActor
struct UsageMonitorTests {
    let snapshot = UsageSnapshot(sessionUtilization: 42, sessionResetsAt: nil, weeklyUtilization: 61, weeklyResetsAt: nil)

    @Test func `overlapping refresh triggers only one fetch`() async {
        let provider = GatedUsageProvider(snapshot: snapshot)
        let monitor = UsageMonitor(provider: provider, autoStart: false)

        let first = Task { await monitor.refresh() }
        while provider.callCount.withLock({ $0 }) == 0 { await Task.yield() }

        // First fetch is now suspended inside the provider; a second refresh
        // should be dropped by the in-flight guard rather than call fetch again.
        await monitor.refresh()
        #expect(provider.callCount.withLock { $0 } == 1)

        provider.release()
        await first.value
        #expect(monitor.state == .available(snapshot))
    }

    @Test func `successful fetch yields available`() async {
        let monitor = UsageMonitor(provider: MockUsageProvider(results: [.success(snapshot)]), autoStart: false)
        await monitor.refresh()
        #expect(monitor.state == .available(snapshot))
    }

    @Test func `initial state is unavailable`() {
        let monitor = UsageMonitor(provider: MockUsageProvider(results: []), autoStart: false)
        #expect(monitor.state == .unavailable)
    }

    @Test func `failure after success yields stale with last snapshot`() async {
        let monitor = UsageMonitor(
            provider: MockUsageProvider(results: [.success(snapshot), .failure(.network)]),
            autoStart: false
        )
        await monitor.refresh()
        await monitor.refresh()
        #expect(monitor.state == .stale(snapshot))
    }

    @Test func `failure without prior data yields unavailable`() async {
        let monitor = UsageMonitor(provider: MockUsageProvider(results: [.failure(.network)]), autoStart: false)
        await monitor.refresh()
        #expect(monitor.state == .unavailable)
    }

    @Test func `missing credentials yields noCredentials`() async {
        let monitor = UsageMonitor(provider: MockUsageProvider(results: [.failure(.noCredentials)]), autoStart: false)
        await monitor.refresh()
        #expect(monitor.state == .noCredentials)
    }

    @Test func `expired token yields tokenExpired`() async {
        let monitor = UsageMonitor(provider: MockUsageProvider(results: [.failure(.tokenExpired)]), autoStart: false)
        await monitor.refresh()
        #expect(monitor.state == .tokenExpired)
    }

    @Test func `rate limit keeps previous state and enables backoff`() async {
        let monitor = UsageMonitor(
            provider: MockUsageProvider(results: [.success(snapshot), .failure(.rateLimited)]),
            autoStart: false
        )
        await monitor.refresh()
        await monitor.refresh()
        #expect(monitor.state == .available(snapshot))
        #expect(monitor.isRateLimited == true)
    }

    @Test func `success clears rate limit backoff`() async {
        let monitor = UsageMonitor(
            provider: MockUsageProvider(results: [.failure(.rateLimited), .success(snapshot)]),
            autoStart: false
        )
        await monitor.refresh()
        await monitor.refresh()
        #expect(monitor.state == .available(snapshot))
        #expect(monitor.isRateLimited == false)
    }

    @Test func `displayedSnapshot exposes available and stale values only`() {
        #expect(UsageMonitor.State.available(snapshot).displayedSnapshot == snapshot)
        #expect(UsageMonitor.State.stale(snapshot).displayedSnapshot == snapshot)
        #expect(UsageMonitor.State.unavailable.displayedSnapshot == nil)
        #expect(UsageMonitor.State.noCredentials.displayedSnapshot == nil)
        #expect(UsageMonitor.State.tokenExpired.displayedSnapshot == nil)
    }
}
