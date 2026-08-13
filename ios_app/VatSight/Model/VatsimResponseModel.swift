//
//  VatsimResponse.swift
//  VatSight
//
//  Created by Marcel Marzec on 09/05/2026.
//

import Foundation

struct VatsimResponseModel: Codable {
    let general: General
    let pilots: [Pilot]
    let controllers: [Controllers]
    let atis: [ATIS]
    let servers: [Servers]
    let prefiles: [Prefiles]
    let facilities: [Facilities]
    let ratings: [ControllerRatings]
    let pilot_ratings: [PilotRatings]
    let military_ratings: [MilitaryRatings]
}
