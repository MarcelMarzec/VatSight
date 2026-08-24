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
    let short: String
    let long: String
}

struct PilotRatings: Codable, Identifiable {
    let id: Int
    let short_name: String
    let long_name: String
}

struct MilitaryRatings: Codable, Identifiable {
    let id: Int
    let short_name: String
    let long_name: String
}

// MARK: - Rating Registry

/// Shared lookup tables populated once per VATSIM fetch on the main thread.
/// Allows Controllers and Pilot to expose resolved rating objects as computed properties.
final class VatsimRatingsRegistry {
    static let shared = VatsimRatingsRegistry()
    private init() {}

    var controllerRatings: [Int: ControllerRatings] = [:]
    var pilotRatings: [Int: PilotRatings] = [:]
    var militaryRatings: [Int: MilitaryRatings] = [:]
    var facilities: [Int: Facilities] = [:]

    func populate(from response: VatsimResponseModel) {
        controllerRatings = Dictionary(response.ratings.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        pilotRatings = Dictionary(response.pilot_ratings.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        militaryRatings = Dictionary(response.military_ratings.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        facilities = Dictionary(response.facilities.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
}
