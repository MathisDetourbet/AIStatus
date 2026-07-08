import Foundation
import Testing
@testable import AIStatusKit

@Suite("Usage Snapshot")
struct UsageSnapshotTests {
    @Test func `decodes full response`() throws {
        let json = """
        {
            "five_hour": { "utilization": 42, "resets_at": "2026-07-08T15:00:00Z" },
            "seven_day": { "utilization": 61.4, "resets_at": "2026-07-14T00:00:00.000Z" }
        }
        """.data(using: .utf8)!
        let snapshot = try UsageSnapshot(data: json)
        #expect(snapshot.sessionUtilization == 42)
        #expect(snapshot.weeklyUtilization == 61)
        #expect(snapshot.sessionResetsAt == ISO8601DateFormatter().date(from: "2026-07-08T15:00:00Z"))
        #expect(snapshot.weeklyResetsAt == ISO8601DateFormatter().date(from: "2026-07-14T00:00:00Z"))
    }

    @Test func `decodes partial response with missing window`() throws {
        let json = """
        { "five_hour": { "utilization": 12 } }
        """.data(using: .utf8)!
        let snapshot = try UsageSnapshot(data: json)
        #expect(snapshot.sessionUtilization == 12)
        #expect(snapshot.sessionResetsAt == nil)
        #expect(snapshot.weeklyUtilization == nil)
        #expect(snapshot.weeklyResetsAt == nil)
    }

    @Test func `decodes empty object to all nil`() throws {
        let snapshot = try UsageSnapshot(data: "{}".data(using: .utf8)!)
        #expect(snapshot.sessionUtilization == nil)
        #expect(snapshot.weeklyUtilization == nil)
    }

    @Test func `tolerates unknown fields and unexpected types`() throws {
        let json = """
        {
            "five_hour": { "utilization": "oops", "resets_at": 12345, "extra": true },
            "seven_day": { "utilization": 88, "resets_at": "not-a-date" },
            "seven_day_opus": { "utilization": 5 }
        }
        """.data(using: .utf8)!
        let snapshot = try UsageSnapshot(data: json)
        #expect(snapshot.sessionUtilization == nil)
        #expect(snapshot.sessionResetsAt == nil)
        #expect(snapshot.weeklyUtilization == 88)
        #expect(snapshot.weeklyResetsAt == nil)
    }

    @Test func `out-of-range utilization degrades to nil`() throws {
        let json = """
        { "five_hour": { "utilization": 1e19 }, "seven_day": { "utilization": 61 } }
        """.data(using: .utf8)!
        let snapshot = try UsageSnapshot(data: json)
        #expect(snapshot.sessionUtilization == nil)
        #expect(snapshot.weeklyUtilization == 61)
    }

    @Test func `limiting utilization is max of both windows`() {
        let snapshot = UsageSnapshot(sessionUtilization: 42, sessionResetsAt: nil, weeklyUtilization: 61, weeklyResetsAt: nil)
        #expect(snapshot.limitingUtilization == 61)
    }

    @Test func `limiting utilization falls back to the only present window`() {
        let sessionOnly = UsageSnapshot(sessionUtilization: 42, sessionResetsAt: nil, weeklyUtilization: nil, weeklyResetsAt: nil)
        #expect(sessionOnly.limitingUtilization == 42)
        let weeklyOnly = UsageSnapshot(sessionUtilization: nil, sessionResetsAt: nil, weeklyUtilization: 61, weeklyResetsAt: nil)
        #expect(weeklyOnly.limitingUtilization == 61)
    }

    @Test func `limiting utilization is nil when both windows missing`() {
        let snapshot = UsageSnapshot(sessionUtilization: nil, sessionResetsAt: nil, weeklyUtilization: nil, weeklyResetsAt: nil)
        #expect(snapshot.limitingUtilization == nil)
    }
}
