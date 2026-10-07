//
//  VatglassesMatchingService.swift
//  VatSight
//

import Foundation

// MARK: - Controller Matching and Synthetic Sectors
extension VatglassesService {

    /// Synthesises 20 nm APP/DEP circles for unmatched controllers. One circle per ICAO;
    /// split positions share a circle (co-controllers). Suppressed when real sector exists.
    func generateSyntheticSectors(
        unmatchedCIDs controllers: [Controllers],
        airports: [VatglassesAirport],
        icaosWithRealAppSector: Set<String>
    ) -> [VatglassesSector] {
        var airportByICAO: [String: VatglassesAirport] = [:]
        airportByICAO.reserveCapacity(airports.count)
        for airport in airports {
            airportByICAO[airport.icao.uppercased()] = airport
        }

        var groups: [String: [Controllers]] = [:]

        for controller in controllers {
            let upper = controller.callsign.uppercased()
            guard controller.frequency != "199.998" else { continue } // observer frequency

            guard upper.hasSuffix("_APP") || upper.hasSuffix("_DEP") else { continue }

            let components = upper.split(separator: "_", omittingEmptySubsequences: true).map(String.init)
            guard components.count >= 2 else { continue }
            let icao = components[0]
            guard !icaosWithRealAppSector.contains(icao) else { continue }

            // Skip mentor (_X_) and trainee (_T_) infixes (e.g. EPKK_X_APP).
            if components.count >= 3 {
                let infix = components[1]
                guard infix != "X" && infix != "T" else { continue }
            }

            groups[icao, default: []].append(controller)
        }

        var result: [VatglassesSector] = []

        for (icao, groupControllers) in groups {
            guard !groupControllers.isEmpty else { continue }

            let primary = groupControllers[0]
            let coControllers = Array(groupControllers.dropFirst())

            guard let airport = airportByICAO[icao],
                  abs(airport.latitude) <= 90,
                  abs(airport.longitude) <= 180 else { continue }

            let geometry = makeCircleGeometry(latitude: airport.latitude, longitude: airport.longitude, radiusNm: 15.0)

            let properties = SectorProperties(
                min: 20,
                max: 200,
                name: "\(icao) APP (Synthetic)",
                groupName: nil,
                color: nil
            )

            result.append(VatglassesSector(
                id: "SYNTHETIC/\(primary.callsign)",
                ownerRefs: [icao],
                frequency: primary.frequency,
                geometry: geometry,
                properties: properties,
                isActive: true,
                activeOwnerColorHex: nil,
                activeOwnerRef: icao,
                activeController: primary,
                activeCoControllers: coControllers,
                isBasicDataOnly: true,
                isSynthetic: true
            ))
        }

        return result
    }

    /// Matches a nodata.json sector via `NODATA/{ownerRef}` position lookup; falls back to prefix match.
    func findActiveOwnerForBasicSector(
        ownerRefs: [String],
        allPositions: [String: VatglassesPosition],
        prefixGroupedControllers: [String: [Controllers]]
    ) -> (ownerRef: String, controller: Controllers)? {
        let emptyFreqMap: [String: [Controllers]] = [:] // nodata positions rarely have frequencies

        for ownerRef in ownerRefs {
            if let position = allPositions["NODATA/\(ownerRef.uppercased())"] {
                if let match = findMatchingController(
                    position: position,
                    frequencyGroupedControllers: emptyFreqMap,
                    prefixGroupedControllers: prefixGroupedControllers
                ) {
                    return (ownerRef, match)
                }
            }

            let key = ownerRef.uppercased() // fallback: ownerRef as callsign prefix
            if let candidates = prefixGroupedControllers[key],
               let match = candidates.first {
                return (ownerRef, match)
            }
        }
        return nil
    }

    // MARK: - Hierarchical Ownership Matching

    /// Scopes a raw ownerRef to a FIR region prefix, unless already scoped (e.g. "fss/EUCME").
    func scopedOwnerRef(_ ref: String, regionPrefix: String) -> String {
        if ref.contains("/") {
            // Already scoped (e.g. "fss/EUCME") — uppercase only the prefix component.
            let parts = ref.split(separator: "/", maxSplits: 1)
            guard parts.count == 2 else { return ref }
            return "\(parts[0].uppercased())/\(parts[1])"
        }
        return "\(regionPrefix.uppercased())/\(ref)"
    }

    /// Strips trailing zeros but keeps ≥1 decimal digit. e.g. "119.900" → "119.9".
    func normaliseFrequency(_ raw: String) -> String {
        guard let value = Double(raw) else { return raw }
        var formatted = String(format: "%.3f", value)
        while formatted.hasSuffix("0") && !formatted.hasSuffix(".0") {
            formatted.removeLast()
        }
        return formatted
    }

    func buildFrequencyGroupedControllers(from controllers: [Controllers]) -> [String: [Controllers]] {
        var grouped: [String: [Controllers]] = [:]
        for controller in controllers {
            let key = normaliseFrequency(controller.frequency)
            grouped[key, default: []].append(controller)
        }
        return grouped
    }

    func buildCallsignPrefixGroupedControllers(from controllers: [Controllers]) -> [String: [Controllers]] {
        var grouped: [String: [Controllers]] = [:]
        for controller in controllers {
            let upper = controller.callsign.uppercased()
            if let underscore = upper.firstIndex(of: "_") {
                let prefix = String(upper[upper.startIndex..<underscore])
                grouped[prefix, default: []].append(controller)
            }
        }
        return grouped
    }

    func findActiveOwnerWithController(
        for sector: VatglassesSector,
        allPositions: [String: VatglassesPosition],
        frequencyGroupedControllers: [String: [Controllers]],
        prefixGroupedControllers: [String: [Controllers]],
        positionActiveCache: inout [String: (isActive: Bool, controller: Controllers?)]
    ) -> (ownerRef: String, controller: Controllers)? {
        for ownerRef in sector.ownerRefs {
            if let cached = positionActiveCache[ownerRef] {
                if cached.isActive, let controller = cached.controller {
                    return (ownerRef, controller)
                }
                continue
            }

            let position = allPositions[ownerRef]

            guard let pos = position else {
                positionActiveCache[ownerRef] = (isActive: false, controller: nil)
                continue
            }

            if let matchingController = findMatchingController(
                position: pos,
                frequencyGroupedControllers: frequencyGroupedControllers,
                prefixGroupedControllers: prefixGroupedControllers
            ) {
                positionActiveCache[ownerRef] = (isActive: true, controller: matchingController)
                return (ownerRef, matchingController)
            } else {
                positionActiveCache[ownerRef] = (isActive: false, controller: nil)
            }
        }

        return nil
    }

    /// Matches callsign prefix first, then verifies frequency when available (prevents APP false positives).
    func findMatchingController(
        position: VatglassesPosition,
        frequencyGroupedControllers: [String: [Controllers]],
        prefixGroupedControllers: [String: [Controllers]]
    ) -> Controllers? {
        var trainingMatch: Controllers? = nil

        for pre in position.facilityPrefixes {
            let key = pre.uppercased()
            guard let candidates = prefixGroupedControllers[key] else { continue }

            for controller in candidates {
                guard matchesCallsignPattern(controller: controller, position: position) else { continue }

                let frequencyMatches: Bool
                if let freq = position.frequency {
                    frequencyMatches = normaliseFrequency(controller.frequency) == normaliseFrequency(freq)
                } else {
                    frequencyMatches = true
                }
                guard frequencyMatches else { continue }

                // Deprioritise mentor/trainee callsigns (_X_, _T_); prefer real controller.
                let upper = controller.callsign.uppercased()
                if upper.contains("_X_") || upper.contains("_T_") {
                    if trainingMatch == nil { trainingMatch = controller }
                } else {
                    return controller
                }
            }
        }

        return trainingMatch
    }

    /// True when callsign matches `FACILITY_TYPE` or `FACILITY_MIDDLE_TYPE` (e.g. SOCA_N_APP).
    func matchesCallsignPattern(
        controller: Controllers,
        position: VatglassesPosition
    ) -> Bool {
        let controllerCallsign = controller.callsign
        let posType = position.type

        guard controllerCallsign.hasSuffix(posType) else { return false }

        for facilityPrefix in position.facilityPrefixes {
            guard controllerCallsign.hasPrefix(facilityPrefix) else { continue }

            let facilityLength = facilityPrefix.count
            let typeLength = posType.count
            let callsignLength = controllerCallsign.count

            if callsignLength == facilityLength + 1 + typeLength { // FACILITY_TYPE
                let index = controllerCallsign.index(controllerCallsign.startIndex, offsetBy: facilityLength)
                if controllerCallsign[index] == "_" { return true }
            }

            if callsignLength > facilityLength + 1 + typeLength { // FACILITY_MIDDLE_TYPE
                let afterFacility = controllerCallsign.index(controllerCallsign.startIndex, offsetBy: facilityLength)
                let beforeType = controllerCallsign.index(controllerCallsign.endIndex, offsetBy: -typeLength - 1)
                if controllerCallsign[afterFacility] == "_" && controllerCallsign[beforeType] == "_" { return true }
            }
        }

        return false
    }
}
