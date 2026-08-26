//
//  PrefilesModel.swift
//  VatSight
//
//  Created by Marcel Marzec on 27/05/2026.
//

import Foundation
import CoreLocation

struct Prefiles: Codable, Identifiable {
    let cid: Int
    let name: String
    let callsign: String
    let flight_plan: FlightPlan?
    let last_updated: Date

    var id: Int { cid }
    
    var last_updatedFormatted: String {
        Self.utcTimeFormatter.string(from: last_updated)
    }
    
    private static let utcTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss'z'"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()
}
