//
//  RatingsModel.swift
//  VatSight
//
//  Created by Marcel Marzec on 27/05/2026.
//

import Foundation
import CoreLocation

struct Facilities: Codable, Identifiable {
    let id: Int
    let short: String
    let long: String
}

struct ControllerRatings: Codable, Identifiable {
    let id: Int
    let short_name: String?
    let long_name: String?
}

struct PilotRatings: Codable, Identifiable {
    let id: Int
    let short_name: String?
    let long_name: String?
}

struct MilitaryRatings: Codable, Identifiable {
    let id: Int
    let short_name: String?
    let long_name: String?
}
