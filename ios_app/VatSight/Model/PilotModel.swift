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
    let heading: Double
    let qnh_i_hg: Double
    let qnh_mb: Double
    let logon_time: String
    let last_updated: String
    let flight_plan: fp?
    
    
    var id: Int { cid }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
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
}
