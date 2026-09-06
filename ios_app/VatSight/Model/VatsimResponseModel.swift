//
//  VatsimResponseModel.swift
//  VatSight
//
//  Created by Marcel Marzec on 09/05/2026.
//

import Foundation

struct VatsimResponseModel: Encodable {
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

extension VatsimResponseModel: Decodable {
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        general = try container.decode(General.self, forKey: .general)
        pilots = try container.decode([Pilot].self, forKey: .pilots)
        controllers = try container.decode([Controllers].self, forKey: .controllers)
        atis = try container.decode([ATIS].self, forKey: .atis)
        servers = try container.decode([Servers].self, forKey: .servers)
        prefiles = try container.decode([Prefiles].self, forKey: .prefiles)
        facilities = try container.decode([Facilities].self, forKey: .facilities)
        ratings = try container.decode([ControllerRatings].self, forKey: .ratings)
        pilot_ratings = try container.decode([PilotRatings].self, forKey: .pilot_ratings)
        military_ratings = try container.decode([MilitaryRatings].self, forKey: .military_ratings)
    }
}
