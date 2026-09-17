//
//  VatglassesMatchingService.swift
//  VatSight
//

import Foundation

// MARK: - Controller Matching and Synthetic Sectors
extension VatglassesService {

    /// Generates synthetic 20 nm circle sectors for APP/DEP controllers that are online
    /// but have no matching real VATGlasses sector.
    ///
    /// Key behaviours:
    /// - Only APP and DEP positions. TWR is not synthesised.
    /// - One circle per ICAO. Split APP positions (e.g. EGLL_N_APP + EGLL_S_APP) share a
    ///   single circle; extra controllers are stored in `activeCoControllers`.
    /// - Suppressed entirely when another controller at the same ICAO already has a real
    ///   matched APP sector (`icaosWithRealAppSector`).
    /// - Mentor (_X_) and trainee (_T_) infixes are skipped.
    /// - Frequency 199.998 (VATSIM observer placeholder) is always skipped.
    func generateSyntheticSectors(
        unmatchedCIDs controllers: [Controllers],
        airports: [VatglassesAirport],
        icaosWithRealAppSector: Set<String>
    ) -> [VatglassesSector] {
        // Build a fast ICAO → airport coordinate lookup.
        var airportByICAO: [String: VatglassesAirport] = [:]
        airportByICAO.reserveCapacity(airports.count)
        for airport in airports {
            airportByICAO[airport.icao.uppercased()] = airport
        }

        // Group eligible APP/DEP controllers by ICAO — one circle per airport.
        var groups: [String: [Controllers]] = [:]

        for controller in controllers {
            let upper = controller.callsign.uppercased()

            // Skip observer/inactive frequency.
            guard controller.frequency != "199.998" else { continue }

            // Only synthesise for APP and DEP positions.
            guard upper.hasSuffix("_APP") || upper.hasSuffix("_DEP") else { continue }

            // Split on underscore to extract ICAO and detect mentor/trainee infixes.
            let components = upper.split(separator: "_", omittingEmptySubsequences: true).map(String.init)
            guard components.count >= 2 else { continue }
            let icao = components[0]

            // Skip if a real matched APP sector already exists for this ICAO.
            guard !icaosWithRealAppSector.contains(icao) else { continue }

            // Skip VATSIM mentor (_X_) and trainee (_T_) sessions — second component exactly
            // "X" or "T" in a 3+ component callsign (e.g. EPKK_X_APP, EPKK_T_APP).
            if components.count >= 3 {
                let infix = components[1]
                guard infix != "X" && infix != "T" else { continue }
            }

            groups[icao, default: []].append(controller)
        }

        // Build one VatglassesSector per ICAO group.
        var result: [VatglassesSector] = []

        for (icao, groupControllers) in groups {
            guard !groupControllers.isEmpty else { continue }

            let primary = groupControllers[0]
            let coControllers = Array(groupControllers.dropFirst())

            // Require a known airport with valid coordinates.
            guard let airport = airportByICAO[icao],
                  abs(airport.latitude) <= 90,
                  abs(airport.longitude) <= 180 else { continue }

            let geometry = makeCircleGeometry(latitude: airport.latitude, longitude: airport.longitude, radiusNm: 20.0)

            let properties = SectorProperties(
                min: 20,
                max: 200,
                name: "\(icao) APP (Synthetic)",
                groupName: nil,
                color: nil
            )

            result.append(VatglassesSector(
                id: "synthetic/\(primary.callsign.uppercased())",
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

    /// Finds the first online controller for a nodata.json sector.
    ///
    /// For each ownerRef (a position ID like "KZMP"), looks up the parsed nodata position
    /// under "nodata/{ownerRef}" and delegates to `findMatchingController` which uses the
    /// callsign-primary, frequency-secondary strategy.
    ///
    /// Falls back to a direct prefix match against the ownerRef itself for legacy entries
    /// (e.g. regions where the ownerRef IS the callsign prefix and no position was parsed).
    func findActiveOwnerForBasicSector(
        ownerRefs: [String],
        allPositions: [String: VatglassesPosition],
        prefixGroupedControllers: [String: [Controllers]]
    ) -> (ownerRef: String, controller: Controllers)? {
        // frequencyGroupedControllers not needed here — nodata positions rarely have frequencies.
        // Pass an empty map so findMatchingController falls through to callsign-only matching.
        let emptyFreqMap: [String: [Controllers]] = [:]

        for ownerRef in ownerRefs {
            // Primary path: delegate to the shared matching logic.
            if let position = allPositions["nodata/\(ownerRef)"] {
                if let match = findMatchingController(
                    position: position,
                    frequencyGroupedControllers: emptyFreqMap,
                    prefixGroupedControllers: prefixGroupedControllers
                ) {
                    return (ownerRef, match)
                }
            }

            // Fallback: ownerRef itself is used as a callsign prefix (legacy / non-US regions
            // where the sector owner string doubles as the prefix, e.g. "KZBW" → "KZBW_FSS").
            let key = ownerRef.uppercased()
            if let candidates = prefixGroupedControllers[key],
               let match = candidates.first {
                return (ownerRef, match)
            }
        }
        return nil
    }

    // MARK: - Hierarchical Ownership Matching

    /// Scopes a raw ownerRef to a specific FIR region, unless it already contains a cross-file
    /// prefix (e.g. "fss/EUCME" is returned as-is; "CT" becomes "regionPrefix/CT").
    func scopedOwnerRef(_ ref: String, regionPrefix: String) -> String {
        return ref.contains("/") ? ref : "\(regionPrefix)/\(ref)"
    }

    /// Normalises a frequency string to a canonical form for comparison.
    /// Strips trailing zeros after the decimal point, but keeps at least one decimal digit.
    /// e.g. "119.900" -> "119.9", "120.500" -> "120.5", "121.000" -> "121.0"
    func normaliseFrequency(_ raw: String) -> String {
        guard let value = Double(raw) else { return raw }
        // Format with up to 3 decimal places then strip trailing zeros
        var formatted = String(format: "%.3f", value)
        // Find the last non-zero character after the decimal, stopping before ".0"
        while formatted.hasSuffix("0") && !formatted.hasSuffix(".0") {
            formatted.removeLast()
        }
        return formatted
    }

    /// Groups controllers by normalised frequency for efficient lookup during sector matching.
    func buildFrequencyGroupedControllers(from controllers: [Controllers]) -> [String: [Controllers]] {
        var grouped: [String: [Controllers]] = [:]
        for controller in controllers {
            let key = normaliseFrequency(controller.frequency)
            grouped[key, default: []].append(controller)
        }
        return grouped
    }

    /// Groups controllers by the callsign prefix (the component before the first `_`).
    /// Used as a fast lookup for positions that have no frequency in the data.
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

    /// Walks the hierarchical ownership chain for a sector and returns the first active owner.
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

            // All ownerRefs are scoped at parse time (e.g. "soca/CA", "fss/EUCME"),
            // so the lookup is always a direct key match.
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

    /// Returns the first controller whose callsign matches the given position, or nil if none match.
    ///
    /// Matching strategy (mirrors the vatglasses reference implementation):
    /// 1. Always use callsign pattern as the primary filter — narrows candidates via the
    ///    prefix-keyed lookup (O(1) per `pre` entry) so no full scan is needed.
    /// 2. When the position has a frequency, additionally require the controller to be on
    ///    that frequency. This eliminates false positives when two positions share the same
    ///    callsign prefix but operate on different frequencies (e.g. different APP sectors).
    /// 3. When the position has no frequency (e.g. NAT, oceanic FSS positions), the callsign
    ///    match alone is sufficient — there is no secondary filter to apply.
    func findMatchingController(
        position: VatglassesPosition,
        frequencyGroupedControllers: [String: [Controllers]],
        prefixGroupedControllers: [String: [Controllers]]
    ) -> Controllers? {
        // Collect candidates by callsign prefix — O(pre.count) lookups, not O(controllers).
        var trainingMatch: Controllers? = nil

        for pre in position.facilityPrefixes {
            let key = pre.uppercased()
            guard let candidates = prefixGroupedControllers[key] else { continue }

            for controller in candidates {
                guard matchesCallsignPattern(controller: controller, position: position) else { continue }

                // Callsign matches. If the position has a frequency, also verify the controller
                // is on that frequency to avoid cross-sector false positives.
                let frequencyMatches: Bool
                if let freq = position.frequency {
                    let normFreq = normaliseFrequency(freq)
                    let controllerFreq = normaliseFrequency(controller.frequency)
                    frequencyMatches = controllerFreq == normFreq
                } else {
                    // No frequency defined — callsign match is sufficient.
                    frequencyMatches = true
                }

                guard frequencyMatches else { continue }

                // Deprioritise mentor/trainee callsigns (_X_, _T_) — keep them as a fallback
                // but always prefer the real controller if one also matches this position.
                let upper = controller.callsign.uppercased()
                if upper.contains("_X_") || upper.contains("_T_") {
                    if trainingMatch == nil { trainingMatch = controller }
                } else {
                    return controller
                }
            }
        }

        // No plain controller matched — fall back to the training/mentor match if present.
        return trainingMatch
    }

    /// Returns true if the controller's callsign matches the position's facility prefix and type.
    /// Supports two patterns: `FACILITY_TYPE` and `FACILITY_MIDDLE_TYPE` (e.g. SOCA_N_APP).
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

            // FACILITY_TYPE (e.g. SOCA_APP)
            if callsignLength == facilityLength + 1 + typeLength {
                let index = controllerCallsign.index(controllerCallsign.startIndex, offsetBy: facilityLength)
                if controllerCallsign[index] == "_" { return true }
            }

            // FACILITY_MIDDLE_TYPE (e.g. SOCA_N_APP, SOCA_JR_APP)
            if callsignLength > facilityLength + 1 + typeLength {
                let afterFacility = controllerCallsign.index(controllerCallsign.startIndex, offsetBy: facilityLength)
                let beforeType = controllerCallsign.index(controllerCallsign.endIndex, offsetBy: -typeLength - 1)
                if controllerCallsign[afterFacility] == "_" && controllerCallsign[beforeType] == "_" { return true }
            }
        }

        return false
    }
}
