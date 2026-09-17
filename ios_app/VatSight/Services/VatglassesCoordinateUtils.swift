//
//  VatglassesCoordinateUtils.swift
//  VatSight
//

import Foundation

// MARK: - Coordinate Conversion and Circle Geometry
extension VatglassesService {

    /// Converts Vatglasses DDMMSS strings to GeoJSON `[longitude, latitude]` pairs.
    func convertVatglassesCoordinates(_ points: [[String]]) -> [[Double]] {
        points.compactMap { point in
            guard point.count == 2,
                  let lat = parseDMSCoordinate(point[0], isLongitude: false),
                  let lon = parseDMSCoordinate(point[1], isLongitude: true) else { return nil }
            return [lon, lat]
        }
    }

    /// Parses a DMS string (6 or 7 digits) to decimal degrees.
    /// Western hemisphere longitudes (>180°) are normalised to negative values.
    func parseDMSCoordinate(_ dms: String, isLongitude: Bool) -> Double? {
        var coordinateString = dms
        var isNegative = false

        if coordinateString.hasPrefix("-") || coordinateString.hasPrefix("W") || coordinateString.hasPrefix("S") {
            isNegative = true
            coordinateString = String(coordinateString.dropFirst())
        }

        guard coordinateString.count == 6 || coordinateString.count == 7 else { return nil }

        let degreeEnd = coordinateString.count == 7 ? 3 : 2
        let minuteEnd = degreeEnd + 2

        guard let degrees = Double(String(coordinateString.prefix(degreeEnd))),
              let minutes = Double(String(coordinateString.dropFirst(degreeEnd).prefix(2))),
              let seconds = Double(String(coordinateString.dropFirst(minuteEnd))) else {
            return nil
        }

        var decimal = degrees + (minutes / 60.0) + (seconds / 3600.0)
        if isNegative { decimal = -decimal }
        if isLongitude && decimal > 180 { decimal -= 360 }

        return decimal
    }

    /// Parses a coordinate pair that may contain either `Double` or `String` values.
    /// Some data sources (e.g. US/FAA airports) store coords as integers scaled by 1e6
    /// (e.g. 41979594 instead of 41.979594). Values outside ±360 are normalised by ÷1e6.
    func parseCoord(_ raw: Any) -> (latitude: Double, longitude: Double)? {
        func normalise(_ v: Double) -> Double {
            return abs(v) > 360 ? v / 1_000_000 : v
        }
        if let doubles = raw as? [Double], doubles.count == 2 {
            return (normalise(doubles[0]), normalise(doubles[1]))
        }
        if let mixed = raw as? [Any], mixed.count == 2 {
            let vals = mixed.compactMap { v -> Double? in
                if let d = v as? Double { return d }
                if let s = v as? String { return Double(s) }
                return nil
            }
            if vals.count == 2 { return (normalise(vals[0]), normalise(vals[1])) }
        }
        return nil
    }

    /// Generates a GeoJSON Polygon approximating a circle on the Earth's surface.
    ///
    /// Uses the haversine-inverse formula for accurate placement at any latitude.
    /// 64 vertices give a smooth appearance while remaining lightweight for Mapbox.
    func makeCircleGeometry(latitude: Double, longitude: Double, radiusNm: Double, steps: Int = 64) -> SectorGeometry {
        let radiusM = radiusNm * 1852.0   // nm → metres
        let latRad  = latitude  * .pi / 180
        let lonRad  = longitude * .pi / 180
        let earthR: Double = 6_371_000
        let angularDist = radiusM / earthR

        var ring: [[Double]] = []
        ring.reserveCapacity(steps + 1)

        for i in 0...steps {
            let bearing = (Double(i % steps) / Double(steps)) * 2 * .pi
            let lat2 = asin(sin(latRad) * cos(angularDist) +
                            cos(latRad) * sin(angularDist) * cos(bearing))
            let lon2 = lonRad + atan2(
                sin(bearing) * sin(angularDist) * cos(latRad),
                cos(angularDist) - sin(latRad) * sin(lat2)
            )
            ring.append([lon2 * 180 / .pi, lat2 * 180 / .pi])
        }

        // GeoJSON Polygon → [outerRing] → wrapped in [[[[Double]]]]
        return SectorGeometry(type: "Polygon", coordinates: [[ring]])
    }
}
