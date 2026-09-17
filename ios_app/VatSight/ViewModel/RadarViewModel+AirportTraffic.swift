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

    /// Returns the set of airport ICAOs where a tracked CID is the active controller.
    func friendControlledAirportICAOs(friendCIDs: Set<Int>) -> Set<String> {
        guard !friendCIDs.isEmpty else { return [] }
        var result = Set<String>()
        for airport in airports {
            if let controller = airport.activeController, friendCIDs.contains(controller.cid) {
                result.insert(airport.icao)
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
