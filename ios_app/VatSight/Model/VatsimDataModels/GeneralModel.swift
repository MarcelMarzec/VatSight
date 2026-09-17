//
//  GeneralModel.swift
//  VatSight
//
//  Created by Marcel Marzec on 27/05/2026.
//

import Foundation
import CoreLocation

struct General: Codable {
    let version: Int
    let update_timestamp: Date
    let connected_clients: Int
    let unique_users: Int
    
    var update_timestampFormatted: String {
        VatsimDateFormatting.utcTimeFormatter.string(from: update_timestamp)
    }
}
