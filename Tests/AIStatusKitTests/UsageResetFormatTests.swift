import Foundation
import Testing
@testable import AIStatusKit

@Suite("Usage Reset Format")
struct UsageResetFormatTests {
    var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    let locale = Locale(identifier: "en_US")

    @Test func `same-day reset formats as time`() {
        let now = ISO8601DateFormatter().date(from: "2026-07-08T10:00:00Z")!
        let reset = ISO8601DateFormatter().date(from: "2026-07-08T15:00:00Z")!
        let result = UsageResetFormat.string(for: reset, relativeTo: now, calendar: utcCalendar, locale: locale)
        #expect(result.contains("3:00"))
    }

    @Test func `other-day reset formats as weekday`() {
        let now = ISO8601DateFormatter().date(from: "2026-07-08T10:00:00Z")!
        let reset = ISO8601DateFormatter().date(from: "2026-07-14T00:00:00Z")!
        let result = UsageResetFormat.string(for: reset, relativeTo: now, calendar: utcCalendar, locale: locale)
        #expect(result == "Tue")
    }
}
