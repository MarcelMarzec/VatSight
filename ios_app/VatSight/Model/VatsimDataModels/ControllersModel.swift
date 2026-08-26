//
//  ControllersModel.swift
//  VatSight
//
//  Created by Marcel Marzec on 27/05/2026.
//

import Foundation
import CoreLocation

struct Controllers: Codable, Identifiable {
    let cid: Int
    let name: String
    let callsign: String
    let frequency: String
    let facility: Int
    let rating: Int
    let server: String
    let visual_range: Int
    let text_atis: [String]?
    let logon_time: Date
    let last_updated: Date

    var id: Int { cid }

    /// Resolved controller rating from the shared registry. e.g. `.short` → "C1"
    var ratingInfo: ControllerRatings? {
        VatsimRatingsRegistry.shared.controllerRatings[rating]
    }

    /// Resolved facility from the shared registry. e.g. `.short` → "CTR", `.long` → "Centre"
    var facilityInfo: Facilities? {
        VatsimRatingsRegistry.shared.facilities[facility]
    }

    var logon_timeFormatted: String {
        Self.utcTimeFormatter.string(from: logon_time)
    }
    
    var last_updatedFormatted: String {
        Self.utcTimeFormatter.string(from: last_updated)
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
    
    private static let utcTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss'z'"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()
}
