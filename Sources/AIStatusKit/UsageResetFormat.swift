import Foundation

/// Formats a usage-window reset date: same-day → time ("3:00 PM"), otherwise weekday ("Tue").
public enum UsageResetFormat {
    public static func string(
        for date: Date,
        relativeTo now: Date = Date(),
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            date.formatted(
                Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            )
        } else {
            date.formatted(
                Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).weekday(.abbreviated)
            )
        }
    }
}
