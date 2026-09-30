//
//  RadarViewModel+AirportTraffic.swift
//  VatSight
//

import Foundation

// MARK: - Airport Traffic and Friend CID Helpers
extension RadarViewModel {

    /// Traffic data for the currently selected airport, derived from live pilots and prefiles.
    var selectedAirportTraffic: AirportTraffic? {
        guard let icao = selectedAirportICAO else { return nil }
        let upperICAO = icao.uppercased()
        let groundSpeedThreshold = 40

        var airborneDep: [Pilot] = []
        var airborneArr: [Pilot] = []
        var groundDep: [Pilot] = []
        var groundArr: [Pilot] = []

        for pilot in pilots {
            guard let fp = pilot.flight_plan else { continue }
            let isDeparture = fp.departure.uppercased() == upperICAO
            let isArrival   = fp.arrival.uppercased()   == upperICAO
            guard isDeparture || isArrival else { continue }

            let isOnGround = pilot.groundspeed < groundSpeedThreshold

            if isDeparture {
                if isOnGround { groundDep.append(pilot) }
                else { airborneDep.append(pilot) }
            }
            if isArrival {
                if isOnGround { groundArr.append(pilot) }
                else { airborneArr.append(pilot) }
            }
        }

        let prefileDep = prefiles.filter { $0.flight_plan?.departure.uppercased() == upperICAO }
        let prefileArr = prefiles.filter { $0.flight_plan?.arrival.uppercased()   == upperICAO }

        return AirportTraffic(
            airborneDepartures: airborneDep,
            airborneArrivals:   airborneArr,
            groundDepartures:   groundDep,
            groundArrivals:     groundArr,
            prefileDepartures:  prefileDep,
            prefileArrivals:    prefileArr
        )
    }

    /// Returns the set of airport ICAOs where any online friend CID is controlling.
    /// Checks all controllers whose callsign prefix matches the airport ICAO, not just
    /// the single `activeController` stored on the airport (which is only the highest-priority one).
    func friendControlledAirportICAOs(friendCIDs: Set<Int>) -> Set<String> {
        guard !friendCIDs.isEmpty else { return [] }

        // Build a lookup: callsign prefix → set of CIDs with that prefix.
        // Covers both full ICAO (e.g. "EGKK") and 3-char variant (e.g. "GKK") prefixes.
        var prefixToCIDs: [String: Set<Int>] = [:]
        for ctrl in controllers {
            let upper = ctrl.callsign.uppercased()
            if let underscore = upper.firstIndex(of: "_") {
                let prefix = String(upper[upper.startIndex..<underscore])
                prefixToCIDs[prefix, default: []].insert(ctrl.cid)
            }
        }

        var result = Set<String>()
        for airport in airports {
            guard airport.isActive else { continue }
            let icao = airport.icao.uppercased()
            // Check both the full ICAO prefix and the 3-char shortened variant.
            let prefixes: [String] = icao.count == 4 ? [icao, String(icao.dropFirst())] : [icao]
            for prefix in prefixes {
                if let cids = prefixToCIDs[prefix], !cids.isDisjoint(with: friendCIDs) {
                    result.insert(airport.icao)
                    break
                }
            }
        }
        return result
    }
}

// MARK: - AirportTraffic

struct AirportTraffic {
    /// Airborne pilots with this airport as departure (groundspeed >= 40 kt)
    let airborneDepartures: [Pilot]
    /// Airborne pilots with this airport as arrival (groundspeed >= 40 kt)
    let airborneArrivals: [Pilot]
    /// On-ground pilots with this airport as departure (groundspeed < 40 kt)
    let groundDepartures: [Pilot]
    /// On-ground pilots with this airport as arrival (groundspeed < 40 kt)
    let groundArrivals: [Pilot]
    /// Prefiled plans departing from this airport (no live position)
    let prefileDepartures: [Prefiles]
    /// Prefiled plans arriving at this airport (no live position)
    let prefileArrivals: [Prefiles]

    var totalDepartures: Int {
        airborneDepartures.count + groundDepartures.count + prefileDepartures.count
    }
    var totalArrivals: Int {
        airborneArrivals.count + groundArrivals.count + prefileArrivals.count
    }
    var totalOnGround: Int {
        groundDepartures.count + groundArrivals.count
    }
    /// All airborne pilots (departures + arrivals) — used to draw airport-to-pilot lines.
    var allAirbornePilots: [Pilot] {
        airborneDepartures + airborneArrivals
    }
}
