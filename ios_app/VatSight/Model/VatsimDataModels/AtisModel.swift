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
    
    var logon_timeFormatted: String {
        Self.utcTimeFormatter.string(from: logon_time)
    }
    
    var last_updatedFormatted: String {
        Self.utcTimeFormatter.string(from: last_updated)
    }
    
    private static let utcTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm'Z'"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()
}
