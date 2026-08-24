//
//  AtisModel.swift
//  VatSight
//
//  Created by Marcel Marzec on 27/05/2026.
//

import Foundation
import CoreLocation

struct ATIS: Codable, Identifiable {
    let cid: Int
    let name: String
    let callsign: String
    let frequency: String
    let facility: Int
    let rating: Int
    let server: String
    let visual_range: Int
    let atis_code: String?
    let text_atis: [String]?
    let logon_time: Date
    let last_updated: Date

    var id: Int { cid }

    /// Resolved facility from the shared registry. e.g. `.short` → "ATIS", `.long` → "ATIS"
    var facilityInfo: Facilities? {
        VatsimRatingsRegistry.shared.facilities[facility]
    }

    /// Duration online as a formatted string, e.g. "2h 34m"
    var onlineDuration: String {
        let elapsed = Int(Date().timeIntervalSince(logon_time))
        let hours = elapsed / 3600
        let minutes = (elapsed % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var logon_timeFormatted: String {
        Self.utcTimeFormatter.string(from: logon_time)
    }
    
    var last_updatedFormatted: String {
        Self.utcTimeFormatter.string(from: last_updated)
    }
    
    private static let utcTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm'z'"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()
}
