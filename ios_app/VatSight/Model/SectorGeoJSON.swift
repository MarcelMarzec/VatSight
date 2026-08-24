//
//  SectorGeoJSON.swift
//  VatSight
//
//  Created by Marcel Marzec on 28/07/2026.
//

import Foundation
import MapboxMaps
import Turf
import CoreLocation

enum SectorGeoJSON {

    // MARK: - Label placement helpers

    /// Cache of previously computed label coordinates keyed by sector ID.
    /// Avoids recomputing expensive distance calculations on every render.
    private static var labelCoordinateCache: [String: CLLocationCoordinate2D] = [:]

    /// Approximate degrees-per-metre at mid-latitudes (1 deg lat ≈ 111 km).
    private static let degreesPerMetre: Double = 1.0 / 111_000

    /// Minimum distance (metres) a label point must be from any airport coordinate.
    private static let airportAvoidanceRadius: Double = 15_000   // ~15 km

    /// Step size for each candidate offset attempt (metres). Tries multiples of this.
    private static let nudgeStep: Double = 20_000   // 20 km per step

    /// Returns the centroid of the largest ring (outer ring of the largest polygon).
    private static func centroid(of sector: VatglassesSector) -> CLLocationCoordinate2D? {
        // Collect all outer rings; pick the one with the most coordinates as the "main" polygon.
        var rings: [[CLLocationCoordinate2D]] = []
        let coords = sector.geometry.coordinates
        if sector.geometry.type == "Polygon", let first = coords.first, let ring = first.first {
            rings.append(ring.compactMap { c in
                guard c.count >= 2 else { return nil }
                return CLLocationCoordinate2D(latitude: c[1], longitude: c[0])
            })
        } else if sector.geometry.type == "MultiPolygon" {
            for polygon in coords {
                if let ring = polygon.first {
                    rings.append(ring.compactMap { c in
                        guard c.count >= 2 else { return nil }
                        return CLLocationCoordinate2D(latitude: c[1], longitude: c[0])
                    })
                }
            }
        }
        guard let mainRing = rings.max(by: { $0.count < $1.count }), !mainRing.isEmpty else { return nil }

        var latSum = 0.0, lonSum = 0.0
        for coord in mainRing {
            latSum += coord.latitude
            lonSum += coord.longitude
        }
        return CLLocationCoordinate2D(latitude: latSum / Double(mainRing.count),
                                      longitude: lonSum / Double(mainRing.count))
    }

    /// Distance in metres between two coordinates (flat-earth approximation — fine for small distances).
    private static func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let dLat = (a.latitude - b.latitude) * 111_000
        let dLon = (a.longitude - b.longitude) * 111_000 * cos(a.latitude * .pi / 180)
        return sqrt(dLat * dLat + dLon * dLon)
    }

    /// Returns true if `point` is at least `airportAvoidanceRadius` metres from every airport.
    private static func isClearOfAirports(_ point: CLLocationCoordinate2D,
                                          airports: [VatglassesAirport]) -> Bool {
        for airport in airports {
            let airportCoord = CLLocationCoordinate2D(latitude: airport.latitude,
                                                      longitude: airport.longitude)
            if distance(point, airportCoord) < airportAvoidanceRadius {
                return false
            }
        }
        return true
    }

    /// Candidate offset directions (unit vectors) tried in order: cardinal then diagonal.
    private static let candidateDirections: [(Double, Double)] = [
        ( 1,  0), (-1,  0), ( 0,  1), ( 0, -1),  // N, S, E, W
        ( 0.7,  0.7), (-0.7,  0.7), ( 0.7, -0.7), (-0.7, -0.7)  // NE, NW, SE, SW
    ]

    /// Finds the best label coordinate for a sector by nudging the centroid away from airports.
    /// Falls back to the raw centroid if no clear position is found.
    /// Results are cached by sector ID to avoid recomputing on every render.
    static func labelCoordinate(
        for sector: VatglassesSector,
        airports: [VatglassesAirport]
    ) -> CLLocationCoordinate2D? {
        if let cached = labelCoordinateCache[sector.id] { return cached }

        guard let center = centroid(of: sector) else { return nil }
        guard !airports.isEmpty else {
            labelCoordinateCache[sector.id] = center
            return center
        }

        // If the centroid is already clear, use it.
        if isClearOfAirports(center, airports: airports) {
            labelCoordinateCache[sector.id] = center
            return center
        }

        // Try progressively larger offsets in each direction.
        for multiplier in 1...4 {
            let offsetMetres = nudgeStep * Double(multiplier)
            let dDeg = offsetMetres * degreesPerMetre
            for (dy, dx) in candidateDirections {
                let candidate = CLLocationCoordinate2D(
                    latitude:  center.latitude  + dy * dDeg,
                    longitude: center.longitude + dx * dDeg / max(cos(center.latitude * .pi / 180), 0.001)
                )
                if isClearOfAirports(candidate, airports: airports) {
                    labelCoordinateCache[sector.id] = candidate
                    return candidate
                }
            }
        }

        // No clear position found — fall back to centroid (better than nothing).
        labelCoordinateCache[sector.id] = center
        return center
    }

    /// Clears the label coordinate cache. Call this when airport data changes.
    static func clearLabelCoordinateCache() {
        labelCoordinateCache.removeAll()
    }

    // MARK: - Callsign Helpers

    /// Derives a short callsign from a full controller callsign.
    /// E.g. "LRBB_S_CTR" → "LRBB_S", "EGTT_CTR" → "EGTT", "LRBB_CTR" → "LRBB"
    /// Strips the trailing ATC suffix (_CTR, _APP, _DEP, _TWR, _GND, _DEL, _ATIS, _FSS, _OBS).
    static func shortCallsign(from callsign: String) -> String {
        let atcSuffixes = ["_CTR", "_APP", "_DEP", "_TWR", "_GND", "_DEL", "_ATIS", "_FSS", "_OBS"]
        let upper = callsign.uppercased()
        for suffix in atcSuffixes {
            if upper.hasSuffix(suffix) {
                return String(callsign.dropLast(suffix.count))
            }
        }
        return callsign
    }

    // MARK: - FeatureCollections

    /// Creates a FeatureCollection for all sectors with controller information.
    /// For active sectors with the same controller, only the first sector will have label data.
    /// All sectors owned by the selected controller CID are highlighted.
    static func featureCollection(
        from sectors: [VatglassesSector],
        controllers: [Controllers] = [],
        activeOnly: Bool = false,
        selectedControllerCID: Int? = nil
    ) -> FeatureCollection {
        
        let filteredSectors = activeOnly ? sectors.filter { $0.isActive } : sectors
        
        // Track which controllers already have a label assigned
        var controllersWithLabels = Set<Int>()  // Use CID instead of callsign
        
        let features = filteredSectors.compactMap { sector -> Feature? in
            // Use the pre-matched controller from VatGlasses matching
            let controller = sector.activeController
            
            // Determine if this sector should show the label
            let shouldShowLabel: Bool
            if let controller = controller {
                // Never show labels for tower, ground, or ATIS positions
                let suppressedSuffixes = ["_TWR", "_GND", "_DEL", "_ATIS"]
                let isSuppressed = suppressedSuffixes.contains(where: { controller.callsign.uppercased().hasSuffix($0) })
                // Only show label if this controller hasn't been labeled yet and is not suppressed
                shouldShowLabel = !isSuppressed && !controllersWithLabels.contains(controller.cid)
                if shouldShowLabel {
                    controllersWithLabels.insert(controller.cid)
                }
            } else {
                shouldShowLabel = false
            }
            
            // Highlight all sectors owned by the selected controller
            let isSelected = selectedControllerCID != nil && sector.activeController?.cid == selectedControllerCID
            return feature(from: sector, shouldShowLabel: shouldShowLabel, isSelected: isSelected)
        }
        
        return FeatureCollection(features: features)
    }
    
    /// Creates a Feature from a single sector with active controller information
    static func feature(from sector: VatglassesSector, shouldShowLabel: Bool = true, isSelected: Bool = false) -> Feature? {
        guard let geometry = sector.geometry.turfGeometry else {
            return nil
        }
        
        var feature = Feature(geometry: geometry)
        
        feature.properties = [
            "id": .string(sector.id),
            "frequency": .string(sector.frequency),
            "isActive": .boolean(sector.isActive),
            "isSelected": .boolean(isSelected)
        ]
        
        // Add color hex if available (for active sectors with position colors)
        if let colorHex = sector.activeOwnerColorHex {
            feature.properties?["colorHex"] = .string(colorHex)
        }
        
        // Add the active owner reference (the position that's actually controlling)
        if let activeOwnerRef = sector.activeOwnerRef {
            feature.properties?["activeOwner"] = .string(activeOwnerRef)
        }
        
        // If sector is active and should show label, use the pre-matched controller
        if sector.isActive && shouldShowLabel, let controller = sector.activeController {
            feature.properties?["controllerCallsign"] = .string(controller.callsign)
            feature.properties?["controllerFrequency"] = .string(controller.frequency)
            feature.properties?["controllerName"] = .string(controller.name)
            feature.properties?["controllerCID"] = .number(Double(controller.cid))
        }
        
        // Add altitude properties if available
        if let min = sector.properties?.min {
            feature.properties?["minAltitude"] = .number(Double(min))
        }
        
        if let max = sector.properties?.max {
            feature.properties?["maxAltitude"] = .number(Double(max))
        }
        
        if let name = sector.properties?.name {
            feature.properties?["name"] = .string(name)
        }
        
        if let color = sector.properties?.color {
            feature.properties?["color"] = .string(color)
        }
        
        return feature
    }
    
    /// Creates a FeatureCollection of Point features used exclusively for sector label placement.
    /// Each active sector with a controller gets one point, positioned to avoid nearby airports.
    static func labelPointFeatureCollection(
        from sectors: [VatglassesSector],
        airports: [VatglassesAirport],
        selectedControllerCID: Int? = nil,
        friendCIDs: Set<Int> = []
    ) -> FeatureCollection {
        var controllersWithLabels = Set<Int>()

        let features: [Feature] = sectors.compactMap { sector in
            guard sector.isActive, let controller = sector.activeController else { return nil }
            let suppressedSuffixes = ["_TWR", "_GND", "_DEL", "_ATIS"]
            guard !suppressedSuffixes.contains(where: { controller.callsign.uppercased().hasSuffix($0) }) else { return nil }
            guard !controllersWithLabels.contains(controller.cid) else { return nil }
            controllersWithLabels.insert(controller.cid)

            guard let coord = labelCoordinate(for: sector, airports: airports) else { return nil }

            var feature = Feature(geometry: .point(Point(coord)))
            feature.properties = [
                "id": .string(sector.id),
                "controllerCallsign": .string(controller.callsign),
                "controllerFrequency": .string(controller.frequency),
                "controllerShortCallsign": .string(Self.shortCallsign(from: controller.callsign)),
                "isSelected": .boolean(selectedControllerCID != nil && sector.activeController?.cid == selectedControllerCID),
                "isFriend": .boolean(friendCIDs.contains(controller.cid))
            ]
            return feature
        }

        return FeatureCollection(features: features)
    }

    /// Creates separate FeatureCollections for active and inactive sectors
    static func separateActiveInactive(from sectors: [VatglassesSector], controllers: [Controllers] = []) -> (active: FeatureCollection, inactive: FeatureCollection) {
        let activeSectors = sectors.filter { $0.isActive }
        let inactiveSectors = sectors.filter { !$0.isActive }
        
        return (
            active: featureCollection(from: activeSectors, controllers: controllers),
            inactive: featureCollection(from: inactiveSectors, controllers: controllers)
        )
    }
}
