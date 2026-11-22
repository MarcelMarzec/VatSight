//
//  EventTimeFormatting.swift
//  VatSight
//
//  Formats event and booking times according to the user's UTC / Local / Both setting.
//  UTC uses aviation style ("18:00z"); local follows the device's 12/24-hour preference.
//

import Foundation

nonisolated enum EventTimeFormatting {

    // MARK: - Formatters (created once)

    nonisolated(unsafe) private static let utcTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "HH:mm"
        return f
    }()

    nonisolated(unsafe) private static let localTime: DateFormatter = {
        let f = DateFormatter()
        f.timeZone = .autoupdatingCurrent
        f.locale = .autoupdatingCurrent
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    nonisolated(unsafe) private static let utcDay: DateFormatter = makeDayFormatter(template: "EEEdMMM", utc: true)
    nonisolated(unsafe) private static let localDay: DateFormatter = makeDayFormatter(template: "EEEdMMM", utc: false)
    nonisolated(unsafe) private static let utcLongDay: DateFormatter = makeDayFormatter(template: "EEEEdMMMMy", utc: true)
    nonisolated(unsafe) private static let localLongDay: DateFormatter = makeDayFormatter(template: "EEEEdMMMMy", utc: false)
    nonisolated(unsafe) private static let utcWeekday: DateFormatter = makeDayFormatter(template: "EEE", utc: true)
    nonisolated(unsafe) private static let localWeekday: DateFormatter = makeDayFormatter(template: "EEE", utc: false)

    private static func makeDayFormatter(template: String, utc: Bool) -> DateFormatter {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.timeZone = utc ? TimeZone(identifier: "UTC") : .autoupdatingCurrent
        f.setLocalizedDateFormatFromTemplate(template)
        return f
    }

    // MARK: - Time Zones

    /// The zone that day boundaries are drawn in (calendar columns, list sections).
    static func timeZone(for display: EventTimeDisplay) -> TimeZone {
        display == .local ? .autoupdatingCurrent : TimeZone(identifier: "UTC")!
    }

    /// Cached: views ask for these many times per render.
    static func calendar(for display: EventTimeDisplay) -> Calendar {
        display == .local ? localCalendar : utcCalendar
    }

    private static let utcCalendar = makeCalendar(TimeZone(identifier: "UTC")!)
    private static let localCalendar = makeCalendar(.autoupdatingCurrent)

    private static func makeCalendar(_ zone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .autoupdatingCurrent
        calendar.timeZone = zone
        calendar.firstWeekday = Calendar.autoupdatingCurrent.firstWeekday
        return calendar
    }

    // MARK: - Single Times

    /// "18:00z"
    static func utcString(_ date: Date) -> String { utcTime.string(from: date) + "z" }

    /// "19:00" or "7:00 PM"
    static func localString(_ date: Date) -> String { localTime.string(from: date) }

    /// A single time per the setting. Both → "18:00z (19:00)".
    static func time(_ date: Date, display: EventTimeDisplay) -> String {
        switch display {
        case .utc: return utcString(date)
        case .local: return localString(date)
        case .both: return "\(utcString(date)) (\(localString(date)))"
        }
    }

    /// A time split for compact displays: UTC → ("18:00z", nil), Local → ("19:00", nil),
    /// Both → ("18:00z", "19:00"). `withWeekday` prefixes the day, e.g. "Tue 18:00z".
    static func timeParts(_ date: Date, display: EventTimeDisplay, withWeekday: Bool = false) -> (primary: String, secondary: String?) {
        let utcDayPrefix = withWeekday ? utcWeekday.string(from: date) + " " : ""
        let localDayPrefix = withWeekday ? localWeekday.string(from: date) + " " : ""
        switch display {
        case .utc: return (utcDayPrefix + utcString(date), nil)
        case .local: return (localDayPrefix + localString(date), nil)
        case .both: return (utcDayPrefix + utcString(date), localDayPrefix + localString(date))
        }
    }

    // MARK: - Ranges

    /// Primary and optional secondary line for a time range.
    /// UTC → "05:00 – 22:00z"; Local → "06:00 – 23:00"; Both → UTC line + "06:00 – 23:00 local".
    /// Ranges that cross a day boundary include weekdays: "Sat 23:00z – Sun 02:00z".
    static func range(start: Date, end: Date, display: EventTimeDisplay) -> (primary: String, secondary: String?) {
        switch display {
        case .utc:
            return (utcRange(start, end), nil)
        case .local:
            return (localRange(start, end), nil)
        case .both:
            return (utcRange(start, end), localRange(start, end) + " local")
        }
    }

    private static func utcRange(_ start: Date, _ end: Date) -> String {
        let calendar = Self.calendar(for: .utc)
        if calendar.isDate(start, inSameDayAs: end) || isMidnightEnd(start, end, calendar) {
            return "\(utcTime.string(from: start)) – \(utcTime.string(from: end))z"
        }
        return "\(utcWeekday.string(from: start)) \(utcString(start)) – \(utcWeekday.string(from: end)) \(utcString(end))"
    }

    private static func localRange(_ start: Date, _ end: Date) -> String {
        let calendar = Self.calendar(for: .local)
        if calendar.isDate(start, inSameDayAs: end) || isMidnightEnd(start, end, calendar) {
            return "\(localString(start)) – \(localString(end))"
        }
        return "\(localWeekday.string(from: start)) \(localString(start)) – \(localWeekday.string(from: end)) \(localString(end))"
    }

    /// True when the range ends exactly at the midnight that closes the start day.
    private static func isMidnightEnd(_ start: Date, _ end: Date, _ calendar: Calendar) -> Bool {
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: start)) else { return false }
        return end == nextDay
    }

    // MARK: - Dates

    /// "Sun 22 Nov", or "Sun 22 Nov – Tue 24 Nov" for multi-day events. Day boundaries follow the setting.
    static func dateLine(start: Date, end: Date, display: EventTimeDisplay) -> String {
        let formatter = display == .local ? localDay : utcDay
        let calendar = Self.calendar(for: display)
        let lastInstant = end > start ? end.addingTimeInterval(-1) : end
        if calendar.isDate(start, inSameDayAs: lastInstant) {
            return formatter.string(from: start)
        }
        return "\(formatter.string(from: start)) – \(formatter.string(from: lastInstant))"
    }

    /// "Sunday 22 November 2026"
    static func longDate(_ date: Date, display: EventTimeDisplay) -> String {
        (display == .local ? localLongDay : utcLongDay).string(from: date)
    }

    /// "Sun 22 Nov" in the given display's zone.
    static func shortDate(_ date: Date, display: EventTimeDisplay) -> String {
        (display == .local ? localDay : utcDay).string(from: date)
    }

    // MARK: - Durations & Relative

    /// "17h", "2h 30m", "45m", "2d 12h"
    static func duration(_ interval: TimeInterval) -> String {
        let totalMinutes = max(0, Int((interval / 60).rounded()))
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let minutes = totalMinutes % 60
        if days > 0 { return hours > 0 ? "\(days)d \(hours)h" : "\(days)d" }
        if hours > 0 { return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h" }
        return "\(minutes)m"
    }

    /// "Starts in 3h 20m", "Live · ends in 45m", "Ended"
    static func relativeStatus(start: Date, end: Date, now: Date = Date()) -> String {
        if now < start {
            let interval = start.timeIntervalSince(now)
            if interval < 60 { return "Starting now" }
            return "Starts in \(duration(interval))"
        }
        if now < end {
            return "Live · ends in \(duration(end.timeIntervalSince(now)))"
        }
        return "Ended"
    }

    /// Compact countdown for pills: "in 3h", "in 2d", "now".
    static func compactCountdown(to date: Date, now: Date = Date()) -> String {
        let interval = date.timeIntervalSince(now)
        if interval <= 60 { return "now" }
        let minutes = Int(interval / 60)
        if minutes < 60 { return "in \(minutes)m" }
        let hours = minutes / 60
        if hours < 48 { return "in \(hours)h" }
        return "in \(hours / 24)d"
    }
}
