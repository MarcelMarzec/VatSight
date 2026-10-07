//
//  RadarViewModel+AirportTraffic.swift
//  VatSight
//

import Foundation

// MARK: - Airport Traffic and Friend CID Helpers
extension RadarViewModel {

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

    /// ICAOs where a friend CID is controlling. Checks all prefixes (full ICAO + 3-char variant).
    func friendControlledAirportICAOs(friendCIDs: Set<Int>) -> Set<String> {
        guard !friendCIDs.isEmpty else { return [] }

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
    let airborneDepartures: [Pilot]  // groundspeed >= 40 kt
    let airborneArrivals: [Pilot]
    let groundDepartures: [Pilot]    // groundspeed < 40 kt
    let groundArrivals: [Pilot]
    let prefileDepartures: [Prefiles]
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
    var allAirbornePilots: [Pilot] {
        airborneDepartures + airborneArrivals
    }
}
