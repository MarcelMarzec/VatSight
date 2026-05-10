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
    let latitude: Double
    let longitude: Double
    let heading: Double
    
    var id: Int { cid }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
