//
//  ServerModel.swift
//  VatSight
//
//  Created by Marcel Marzec on 27/05/2026.
//

import Foundation
import CoreLocation

struct Servers: Codable {
    let ident: String
    let hostname_or_ip: String
    let location: String
    let name: String
    let client_connections_allowed: Bool
    let is_sweatbox: Bool
}
