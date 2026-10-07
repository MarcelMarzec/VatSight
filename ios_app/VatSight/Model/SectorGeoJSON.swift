//
//  SectorGeoJSON.swift
//  VatSight
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

    private static var labelCoordinateCache: [String: CLLocationCoordinate2D] = [:]
    private static let degreesPerMetre: Double = 1.0 / 111_000
    private static let airportAvoidanceRadius: Double = 15_000   // ~15 km
    private static let nudgeStep: Double = 20_000   // 20 km per step

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

    private static func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let dLat = (a.latitude - b.latitude) * 111_000
        let dLon = (a.longitude - b.longitude) * 111_000 * cos(a.latitude * .pi / 180)
        return sqrt(dLat * dLat + dLon * dLon)
    }

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

    private static let candidateDirections: [(Double, Double)] = [ // cardinal then diagonal
        ( 1,  0), (-1,  0), ( 0,  1), ( 0, -1),
        ( 0.7,  0.7), (-0.7,  0.7), ( 0.7, -0.7), (-0.7, -0.7)
    ]

    /// Nudges centroid away from airports; synthetic APP/DEP circles get a fixed NW offset.
    static func labelCoordinate(
        for sector: VatglassesSector,
        airports: [VatglassesAirport]
    ) -> CLLocationCoordinate2D? {
        if let cached = labelCoordinateCache[sector.id] { return cached }

        guard let center = centroid(of: sector) else { return nil }

        // APP/DEP synthetic circles: NW offset at 65% × 20 nm so label sits inside the ring.
        if sector.isSynthetic,
           let callsign = sector.activeController?.callsign.uppercased(),
           callsign.hasSuffix("_APP") || callsign.hasSuffix("_DEP") {
            let offsetM: Double = 20.0 * 1852.0 * 0.65
            let earthR: Double = 6_371_000
            let bearing: Double = -45 * .pi / 180 // 315° = NW
            let lat1 = center.latitude  * .pi / 180
            let lon1 = center.longitude * .pi / 180
            let d    = offsetM / earthR
            let lat2 = asin(sin(lat1) * cos(d) + cos(lat1) * sin(d) * cos(bearing))
            let lon2 = lon1 + atan2(sin(bearing) * sin(d) * cos(lat1),
                                    cos(d) - sin(lat1) * sin(lat2))
            let coord = CLLocationCoordinate2D(latitude:  lat2 * 180 / .pi,
                                               longitude: lon2 * 180 / .pi)
            labelCoordinateCache[sector.id] = coord
            return coord
        }
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

    static func clearLabelCoordinateCache() {
        labelCoordinateCache.removeAll()
    }

    // MARK: - Callsign Helpers

    /// Strips ATC type suffix. E.g. "LRBB_S_CTR" → "LRBB_S", "EGTT_CTR" → "EGTT".
    static func shortCallsign(from callsign: String) -> String {
        let atcSuffixes = ["_CTR", "_APP", "_DEP", "_TWR", "_GND", "_DEL", "_ATIS", "_FSS", "_OBS"]
        let upper = callsign.uppercased()
        for suffix in atcSuffixes {
            if upper.hasSuffix(suffix) {
                let trimmed = String(callsign.dropLast(suffix.count))
                return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
            }
        }
        return callsign
    }

    // MARK: - FeatureCollections

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
                let syntheticOverride = sector.isSynthetic && !isSuppressed // TWR circles too small
                shouldShowLabel = (syntheticOverride || !isSuppressed) && !controllersWithLabels.contains(controller.cid)
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

    static func labelPointFeatureCollection(
        from sectors: [VatglassesSector],
        airports: [VatglassesAirport],
        selectedControllerCID: Int? = nil,
        friendCIDs: Set<Int> = [],
        myCID: Int = 0
    ) -> FeatureCollection {
        var controllersWithLabels = Set<Int>()

        let features: [Feature] = sectors.compactMap { sector in
            guard sector.isActive, let controller = sector.activeController else { return nil }
            let suppressedSuffixes = ["_TWR", "_GND", "_DEL", "_ATIS"]
            let isSuppressed = suppressedSuffixes.contains(where: { controller.callsign.uppercased().hasSuffix($0) })
            guard !isSuppressed || (sector.isSynthetic && !controller.callsign.uppercased().hasSuffix("_TWR")) else { return nil }
            guard !controllersWithLabels.contains(controller.cid) else { return nil }
            controllersWithLabels.insert(controller.cid)

            guard let coord = labelCoordinate(for: sector, airports: airports) else { return nil }

            let isSelf = myCID > 0 && controller.cid == myCID

            var feature = Feature(geometry: .point(Point(coord)))
            feature.properties = [
                "id": .string(sector.id),
                "controllerCallsign": .string(controller.callsign),
                "controllerFrequency": .string(controller.frequency),
                "controllerShortCallsign": .string(Self.shortCallsign(from: controller.callsign)),
                "isSelected": .boolean(selectedControllerCID != nil && sector.activeController?.cid == selectedControllerCID),
                "isFriend": .boolean(friendCIDs.contains(controller.cid)),
                "isSelf": .boolean(isSelf),
                "isBasicDataOnly": .boolean(sector.isBasicDataOnly)
            ]
            return feature
        }

        return FeatureCollection(features: features)
    }

    static func separateActiveInactive(from sectors: [VatglassesSector], controllers: [Controllers] = []) -> (active: FeatureCollection, inactive: FeatureCollection) {
        let activeSectors = sectors.filter { $0.isActive }
        let inactiveSectors = sectors.filter { !$0.isActive }

        return (
            active: featureCollection(from: activeSectors, controllers: controllers),
            inactive: featureCollection(from: inactiveSectors, controllers: controllers)
        )
    }

    // MARK: - Sector Merging (GEOSwift boolean union)

    /// Boolean polygon union (GEOSwift/GEOS) — one dissolved polygon per controller.
    /// Disjoint sectors for the same controller produce a MultiPolygon.
    static func mergedByController(from sectors: [VatglassesSector]) -> [VatglassesSector] {
        let activeSectors = sectors.filter { $0.isActive }

        var groups: [Int: [VatglassesSector]] = [:]
        for sector in activeSectors {
            guard let cid = sector.activeController?.cid else { continue }
            groups[cid, default: []].append(sector)
        }

        var merged: [VatglassesSector] = []

        for (_, group) in groups {
            guard let first = group.first else { continue }

            if group.count == 1 {
                merged.append(first)
                continue
            }

            // buffer(0) is the GEOS technique for fixing self-intersecting rings before union.
            var geoPolygons: [GEOSwift.Polygon] = []
            for sector in group {
                let raw = sector.geometry.toGEOSwiftPolygons()
                for poly in raw {
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
                merged.append(syntheticSector(id: first, geometry: .collected(from: group), group: group))
                continue
            }

            let unionedGeometry: SectorGeometry
            do {
                let multiPoly = GEOSwift.MultiPolygon(polygons: geoPolygons)
                let result = try multiPoly.unaryUnion()
                guard let sectorGeom = SectorGeometry(from: result) else {
                    unionedGeometry = SectorGeometry.collected(from: group)
                    merged.append(syntheticSector(id: first, geometry: unionedGeometry, group: group))
                    continue
                }
                unionedGeometry = sectorGeom
            } catch {
                unionedGeometry = SectorGeometry.collected(from: group) // fallback
            }

            merged.append(syntheticSector(id: first, geometry: unionedGeometry, group: group))
        }

        return merged
    }

    private static func syntheticSector(id first: VatglassesSector, geometry: SectorGeometry, group: [VatglassesSector] = []) -> VatglassesSector {
        let mergedID: String
        if group.count > 1 {
            let base = first.activeOwnerRef ?? first.ownerRefs.first ?? first.id
            mergedID = "\(base) (\(group.count) sectors)"
        } else {
            mergedID = first.id
        }
        return VatglassesSector(
            id: mergedID,
            ownerRefs: first.ownerRefs,
            frequency: first.frequency,
            geometry: geometry,
            properties: first.properties,
            isActive: true,
            activeOwnerColorHex: first.activeOwnerColorHex,
            activeOwnerRef: first.activeOwnerRef,
            activeController: first.activeController,
            isBasicDataOnly: first.isBasicDataOnly
        )
    }
}

// MARK: - GEOSwift ↔ SectorGeometry Conversion

extension SectorGeometry {

    // MARK: SectorGeometry → GEOSwift

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

    private func makeGEOSwiftPolygon(from rings: [[[Double]]]) -> GEOSwift.Polygon? {
        guard let exteriorRaw = rings.first else { return nil }
        guard let exterior = makeLinearRing(from: exteriorRaw) else { return nil }

        let holes: [GEOSwift.Polygon.LinearRing] = rings.dropFirst().compactMap {
            makeLinearRing(from: $0)
        }

        return GEOSwift.Polygon(exterior: exterior, holes: holes)
    }

    /// Closes the ring if needed; returns nil for rings with fewer than 4 points (invalid for GEOS).
    private func makeLinearRing(from raw: [[Double]]) -> GEOSwift.Polygon.LinearRing? {
        var points = raw.compactMap { coord -> GEOSwift.Point? in
            guard coord.count >= 2 else { return nil }
            return GEOSwift.Point(x: coord[0], y: coord[1])
        }
        guard !points.isEmpty else { return nil }

        if points.first != points.last { points.append(points[0]) }
        guard points.count >= 4 else { return nil } // GEOS: 3 unique + closing point

        return try? GEOSwift.Polygon.LinearRing(points: points)
    }

    // MARK: GEOSwift → SectorGeometry

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

    private static func rawRings(from polygon: GEOSwift.Polygon) -> [[[Double]]] {
        var rings: [[[Double]]] = []
        rings.append(rawPoints(from: polygon.exterior))
        for hole in polygon.holes {
            rings.append(rawPoints(from: hole))
        }
        return rings
    }

    private static func rawPoints(from ring: GEOSwift.Polygon.LinearRing) -> [[Double]] {
        ring.points.map { [$0.x, $0.y] }
    }

    // MARK: Fallback

    /// Fallback when GEOS union fails: packs all polygons into a MultiPolygon without dissolving.
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

    // MARK: - Synthetic circle geometry

    private static let metresPerNm: Double = 1852.0

    /// Haversine-inverse circle approximation. 64 vertices = smooth but lightweight.
    static func circleGeometry(
        centre: CLLocationCoordinate2D,
        radiusNm: Double,
        steps: Int = 64
    ) -> SectorGeometry {
        let radiusM = radiusNm * metresPerNm
        let latRad = centre.latitude * .pi / 180
        let lonRad = centre.longitude * .pi / 180
        let earthRadius: Double = 6_371_000

        var ring: [[Double]] = []
        ring.reserveCapacity(steps + 1)

        for i in 0...steps {
            let bearing = (Double(i % steps) / Double(steps)) * 2 * .pi
            let angularDist = radiusM / earthRadius

            let lat2 = asin(sin(latRad) * cos(angularDist) +
                            cos(latRad) * sin(angularDist) * cos(bearing))
            let lon2 = lonRad + atan2(
                sin(bearing) * sin(angularDist) * cos(latRad),
                cos(angularDist) - sin(latRad) * sin(lat2)
            )

            let lat2Deg = lat2 * 180 / .pi
            let lon2Deg = lon2 * 180 / .pi
            ring.append([lon2Deg, lat2Deg])
        }

        return SectorGeometry(type: "Polygon", coordinates: [[ring]])
    }
}
