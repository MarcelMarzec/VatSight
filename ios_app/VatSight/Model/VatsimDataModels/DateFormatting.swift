//
//  DateFormatting.swift
//  VatSight
//
//  Created by Marcel Marzec on 27/05/2026.
//

import Foundation

/// Shared date formatters for VATSIM data models.
enum VatsimDateFormatting {
    /// Formats a `Date` as `HH:mm:ss'z'` in UTC, e.g. "14:32:07z".
    static let utcTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss'z'"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()
}
