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
import GEOSwift

// GEOSwift also vends Feature/FeatureCollection for its own GeoJSON support.
// Pin these names to the Turf/MapboxMaps versions used throughout this module.
typealias Feature = Turf.Feature
typealias FeatureCollection = Turf.FeatureCollection

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

    /// Distance in metres between two coordinates (flat-earth approximation).
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
        ( 1,  0), (-1,  0), ( 0,  1), ( 0, -1),
        ( 0.7,  0.7), (-0.7,  0.7), ( 0.7, -0.7), (-0.7, -0.7)
    ]

    /// Finds the best label coordinate for a sector, nudging the centroid away from airports.
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

        if isClearOfAirports(center, airports: airports) {
            labelCoordinateCache[sector.id] = center
            return center
        }

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

        labelCoordinateCache[sector.id] = center
        return center
    }

    /// Clears the label coordinate cache. Call this when airport data changes.
    static func clearLabelCoordinateCache() {
        labelCoordinateCache.removeAll()
    }

    // MARK: - Callsign Helpers

    /// Derives a short callsign from a full controller callsign.
    /// E.g. "LRBB_S_CTR" → "LRBB_S", "EGTT_CTR" → "EGTT".
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
    static func featureCollection(
        from sectors: [VatglassesSector],
        controllers: [Controllers] = [],
        activeOnly: Bool = false,
        selectedControllerCID: Int? = nil
    ) -> FeatureCollection {

        let filteredSectors = activeOnly ? sectors.filter { $0.isActive } : sectors
        var controllersWithLabels = Set<Int>()

        let features = filteredSectors.compactMap { sector -> Feature? in
            let controller = sector.activeController

            let shouldShowLabel: Bool
            if let controller = controller {
                let suppressedSuffixes = ["_TWR", "_GND", "_DEL", "_ATIS"]
                let isSuppressed = suppressedSuffixes.contains(where: { controller.callsign.uppercased().hasSuffix($0) })
                shouldShowLabel = !isSuppressed && !controllersWithLabels.contains(controller.cid)
                if shouldShowLabel {
                    controllersWithLabels.insert(controller.cid)
                }
            } else {
                shouldShowLabel = false
            }

            let isSelected = selectedControllerCID != nil && sector.activeController?.cid == selectedControllerCID
            return feature(from: sector, shouldShowLabel: shouldShowLabel, isSelected: isSelected)
        }

        return FeatureCollection(features: features)
    }

    /// Creates a Feature from a single sector with active controller information.
    static func feature(from sector: VatglassesSector, shouldShowLabel: Bool = true, isSelected: Bool = false) -> Feature? {
        guard let geometry = sector.geometry.turfGeometry else {
            return nil
        }

        var feature = Feature(geometry: geometry)

        feature.properties = [
            "id": .string(sector.id),
            "frequency": .string(sector.frequency),
            "isActive": .boolean(sector.isActive),
            "isSelected": .boolean(isSelected),
            "isBasicDataOnly": .boolean(sector.isBasicDataOnly)
        ]

        if let colorHex = sector.activeOwnerColorHex {
            feature.properties?["colorHex"] = .string(colorHex)
        }

        if let activeOwnerRef = sector.activeOwnerRef {
            feature.properties?["activeOwner"] = .string(activeOwnerRef)
        }

        if sector.isActive && shouldShowLabel, let controller = sector.activeController {
            feature.properties?["controllerCallsign"] = .string(controller.callsign)
            feature.properties?["controllerFrequency"] = .string(controller.frequency)
            feature.properties?["controllerName"] = .string(controller.name)
            feature.properties?["controllerCID"] = .number(Double(controller.cid))
        }

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
                "isFriend": .boolean(friendCIDs.contains(controller.cid)),
                "isBasicDataOnly": .boolean(sector.isBasicDataOnly)
            ]
            return feature
        }

        return FeatureCollection(features: features)
    }

    /// Creates separate FeatureCollections for active and inactive sectors.
    static func separateActiveInactive(from sectors: [VatglassesSector], controllers: [Controllers] = []) -> (active: FeatureCollection, inactive: FeatureCollection) {
        let activeSectors = sectors.filter { $0.isActive }
        let inactiveSectors = sectors.filter { !$0.isActive }

        return (
            active: featureCollection(from: activeSectors, controllers: controllers),
            inactive: featureCollection(from: inactiveSectors, controllers: controllers)
        )
    }

    // MARK: - Sector Merging (GEOSwift boolean union)

    /// Groups active sectors by controller CID and performs a true boolean polygon union
    /// using GEOSwift (backed by GEOS) to produce one dissolved polygon per controller.
    ///
    /// Adjacent or overlapping sector polygons are merged into a single outer ring with
    /// all shared interior edges removed. Disjoint sectors for the same controller produce
    /// a MultiPolygon — each piece is still one feature, so the fill and outline both apply.
    ///
    /// The result is cached in RadarViewModel and only recomputed when the active ownership
    /// assignment changes, not on every VATSIM refresh tick.
    static func mergedByController(from sectors: [VatglassesSector]) -> [VatglassesSector] {
        let activeSectors = sectors.filter { $0.isActive }

        // Group active sectors by controller CID.
        var groups: [Int: [VatglassesSector]] = [:]
        for sector in activeSectors {
            guard let cid = sector.activeController?.cid else { continue }
            groups[cid, default: []].append(sector)
        }

        var merged: [VatglassesSector] = []

        for (_, group) in groups {
            guard let first = group.first else { continue }

            // Single sector — no union needed, pass through unchanged.
            if group.count == 1 {
                merged.append(first)
                continue
            }

            // Convert each sector's geometry to GEOSwift Polygon objects, then repair each
            // one with buffer(by: 0) before union. buffer(0) is the standard GEOS technique
            // for fixing self-intersecting rings (TopologyException) without changing shape.
            var geoPolygons: [GEOSwift.Polygon] = []
            for sector in group {
                let raw = sector.geometry.toGEOSwiftPolygons()
                for poly in raw {
                    // Attempt topology repair; fall back to the original if buffer fails.
                    let repaired: GEOSwift.Polygon
                    if let buffered = try? poly.buffer(by: 0),
                       case .polygon(let p) = buffered {
                        repaired = p
                    } else {
                        repaired = poly
                    }
                    geoPolygons.append(repaired)
                }
            }

            guard !geoPolygons.isEmpty else {
                merged.append(syntheticSector(id: first, geometry: .collected(from: group)))
                continue
            }

            let unionedGeometry: SectorGeometry
            do {
                let multiPoly = GEOSwift.MultiPolygon(polygons: geoPolygons)
                let result = try multiPoly.unaryUnion()
                guard let sectorGeom = SectorGeometry(from: result) else {
                    unionedGeometry = SectorGeometry.collected(from: group)
                    merged.append(syntheticSector(id: first, geometry: unionedGeometry))
                    continue
                }
                unionedGeometry = sectorGeom
            } catch {
                // Union still failed after repair — fall back to coordinate collect.
                unionedGeometry = SectorGeometry.collected(from: group)
            }

            merged.append(syntheticSector(id: first, geometry: unionedGeometry))
        }

        return merged
    }

    /// Builds a synthetic merged VatglassesSector from a representative first sector and
    /// the pre-computed merged geometry.
    private static func syntheticSector(id first: VatglassesSector, geometry: SectorGeometry) -> VatglassesSector {
        VatglassesSector(
            id: "merged-\(first.activeController?.cid ?? 0)",
            ownerRefs: first.ownerRefs,
            frequency: first.frequency,
            geometry: geometry,
            properties: first.properties,
            isActive: true,
            activeOwnerColorHex: first.activeOwnerColorHex,
            activeOwnerRef: first.activeOwnerRef,
            activeController: first.activeController
        )
    }
}

// MARK: - GEOSwift ↔ SectorGeometry Conversion

extension SectorGeometry {

    // MARK: SectorGeometry → GEOSwift

    /// Converts this sector's geometry into an array of GEOSwift Polygons.
    /// A Polygon sector yields one polygon; a MultiPolygon sector yields one per sub-polygon.
    /// Invalid rings (fewer than 4 points, or unclosed) are skipped.
    func toGEOSwiftPolygons() -> [GEOSwift.Polygon] {
        switch type {
        case "Polygon":
            guard let rings = coordinates.first else { return [] }
            if let poly = makeGEOSwiftPolygon(from: rings) { return [poly] }
            return []
        case "MultiPolygon":
            return coordinates.compactMap { makeGEOSwiftPolygon(from: $0) }
        default:
            return []
        }
    }

    /// Builds one GEOSwift Polygon from a ring array: [[lon, lat], ...].
    /// The first ring is the exterior; subsequent rings are interior holes.
    private func makeGEOSwiftPolygon(from rings: [[[Double]]]) -> GEOSwift.Polygon? {
        guard let exteriorRaw = rings.first else { return nil }
        guard let exterior = makeLinearRing(from: exteriorRaw) else { return nil }

        let holes: [GEOSwift.Polygon.LinearRing] = rings.dropFirst().compactMap {
            makeLinearRing(from: $0)
        }

        return try? GEOSwift.Polygon(exterior: exterior, holes: holes)
    }

    /// Converts a raw coordinate array [[lon, lat], ...] into a GEOSwift LinearRing.
    /// Closes the ring automatically if the first and last point differ.
    /// Returns nil if the ring has fewer than 4 points (invalid for GEOS).
    private func makeLinearRing(from raw: [[Double]]) -> GEOSwift.Polygon.LinearRing? {
        var points = raw.compactMap { coord -> GEOSwift.Point? in
            guard coord.count >= 2 else { return nil }
            return GEOSwift.Point(x: coord[0], y: coord[1])
        }
        guard !points.isEmpty else { return nil }

        // Ensure the ring is closed.
        if points.first != points.last {
            points.append(points[0])
        }

        // GEOS requires at least 4 points for a valid ring (3 unique + closing point).
        guard points.count >= 4 else { return nil }

        return try? GEOSwift.Polygon.LinearRing(points: points)
    }

    // MARK: GEOSwift → SectorGeometry

    /// Converts a GEOSwift Geometry result back into a SectorGeometry.
    /// Returns nil only if the geometry type is not a polygon or multipolygon.
    init?(from geometry: GEOSwift.Geometry) {
        switch geometry {
        case .polygon(let poly):
            self.init(type: "Polygon", coordinates: [Self.rawRings(from: poly)])
        case .multiPolygon(let multi):
            let polys = multi.polygons.map { Self.rawRings(from: $0) }
            self.init(type: "MultiPolygon", coordinates: polys)
        default:
            return nil
        }
    }

    /// Converts a GEOSwift Polygon into the [[[[Double]]]] ring format used by SectorGeometry.
    private static func rawRings(from polygon: GEOSwift.Polygon) -> [[[Double]]] {
        var rings: [[[Double]]] = []
        rings.append(rawPoints(from: polygon.exterior))
        for hole in polygon.holes {
            rings.append(rawPoints(from: hole))
        }
        return rings
    }

    /// Converts a LinearRing into [[lon, lat], ...] Double arrays.
    private static func rawPoints(from ring: GEOSwift.Polygon.LinearRing) -> [[Double]] {
        ring.points.map { [$0.x, $0.y] }
    }

    // MARK: Fallback

    /// Coordinate-collection fallback: packs all polygons from all sectors into a single
    /// MultiPolygon without dissolving. Used when the GEOS union fails.
    static func collected(from group: [VatglassesSector]) -> SectorGeometry {
        var allPolygons: [[[[Double]]]] = []
        for sector in group {
            let raw = sector.geometry.coordinates
            switch sector.geometry.type {
            case "Polygon":
                if let rings = raw.first { allPolygons.append(rings) }
            case "MultiPolygon":
                allPolygons.append(contentsOf: raw)
            default:
                break
            }
        }
        return SectorGeometry(type: "MultiPolygon", coordinates: allPolygons)
    }
}
