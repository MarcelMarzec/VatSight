//
//  Pilot.swift
//  VatSight
//
//  Created by Marcel Marzec on 09/05/2026.
//

import Foundation
import CoreLocation

struct Pilot: Codable, Identifiable {
    let cid: Int
    let name: String
    let callsign: String
    let server: String
    let pilot_rating: Int
    let military_rating: Int
    let latitude: Double
    let longitude: Double
    let altitude: Int
    let groundspeed: Int
    let transponder: String
    let heading: Int
    let qnh_i_hg: Double
    let qnh_mb: Double
    let logon_time: Date
    let last_updated: Date
    let flight_plan: fp?
    
    
    var id: Int { cid }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var isEmergency: Bool {
        transponder == "7700" ||
        transponder == "7600" ||
        transponder == "7500" ||
        transponder == "7601"
    }
    
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

struct fp: Codable {
    let flight_rules: String
    let aircraft: String
    let aircraft_faa: String
    let aircraft_short: String
    let departure: String
    let arrival: String
    let alternate: String
    let deptime: String
    let enroute_time: String
    let fuel_time: String
    let remarks: String
    let route: String
    let revision_id: Int
    let assigned_transponder: String
    
    var deptimeFormatted: String {
        Self.hhmmZTimeFormatter(deptime)
    }

    var enroute_timeFormatted: String {
        Self.hhmmTimeFormatter(enroute_time)
    }

    var fuel_timeFormatted: String {
        Self.hhmmTimeFormatter(fuel_time)
    }
    
    private static let utcTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm'Z'"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()
    
    private static func hhmmTimeFormatter(_ value: String) -> String {
        guard value.count == 4 else { return value }

        let h = value.prefix(2)
        let m = value.suffix(2)

        return "\(h):\(m)"
    }
    
    private static func hhmmZTimeFormatter(_ value: String) -> String {
        guard value.count == 4 else { return value }

        let h = value.prefix(2)
        let m = value.suffix(2)

        return "\(h):\(m)Z"
    }
}
