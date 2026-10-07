//
//  FlightRouteStyleManager.swift
//  VatSight
//

import Foundation
import UIKit
import MapboxMaps
import CoreLocation

final class FlightRouteStyleManager {

    // MARK: - Layer/Source IDs

    static let routeSourceId        = "flight-route-source"
    static let coloredRouteLayerId  = "flight-route-colored-layer"
    static let dashedRouteLayerId   = "flight-route-dashed-layer"

    private static let kindDeparture = "departure" // red
    private static let kindArrival   = "arrival"   // green
    private static let kindDashed    = "dashed"    // gray dashed

    // MARK: - Configure

    func configureRoutes(on mapView: MapView) throws {
        try addRouteSource(to: mapView)
        try addColoredRouteLayer(to: mapView)
        try addDashedRouteLayer(to: mapView)
    }

    // MARK: - Update (pilot selected)

    func updateRoutes(on mapView: MapView, pilot: Pilot?, airportCoordinates: [String: CLLocationCoordinate2D]) {
        guard mapView.mapboxMap.sourceExists(withId: Self.routeSourceId) else { return }
        var features: [Feature] = []
        if let pilot, let fp = pilot.flight_plan {
            let pilotCoord = pilot.coordinate
            if !fp.departure.isEmpty, let depCoord = airportCoordinates[fp.departure] {
                features.append(makeLineFeature(from: pilotCoord, to: depCoord, kind: Self.kindDeparture))
            }
            if !fp.arrival.isEmpty, let arrCoord = airportCoordinates[fp.arrival] {
                features.append(makeLineFeature(from: pilotCoord, to: arrCoord, kind: Self.kindArrival))
            }
            if !fp.alternate.isEmpty, let altCoord = airportCoordinates[fp.alternate] {
                features.append(makeLineFeature(from: pilotCoord, to: altCoord, kind: Self.kindDashed))
            }
        }
        mapView.mapboxMap.updateGeoJSONSource(withId: Self.routeSourceId, geoJSON: .featureCollection(FeatureCollection(features: features)))
    }

    // MARK: - Update (airport selected)

    func updateAirportRoutes(
        on mapView: MapView,
        airportCoordinate: CLLocationCoordinate2D?,
        airborneDepartures: [Pilot],
        airborneArrivals: [Pilot]
    ) {
        guard mapView.mapboxMap.sourceExists(withId: Self.routeSourceId) else { return }
        var features: [Feature] = []
        if let airportCoord = airportCoordinate {
            for pilot in airborneDepartures {
                features.append(makeLineFeature(from: airportCoord, to: pilot.coordinate, kind: Self.kindDeparture))
            }
            for pilot in airborneArrivals {
                features.append(makeLineFeature(from: airportCoord, to: pilot.coordinate, kind: Self.kindArrival))
            }
        }
        mapView.mapboxMap.updateGeoJSONSource(withId: Self.routeSourceId, geoJSON: .featureCollection(FeatureCollection(features: features)))
    }

    // MARK: - Remove

    func removeRouteLayers(from mapView: MapView) {
        try? mapView.mapboxMap.removeLayer(withId: Self.dashedRouteLayerId)
        try? mapView.mapboxMap.removeLayer(withId: Self.coloredRouteLayerId)
        try? mapView.mapboxMap.removeSource(withId: Self.routeSourceId)
    }

    // MARK: - Private Helpers

    private func makeLineFeature(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, kind: String) -> Feature {
        let coords = greatCircleCoordinates(from: start, to: end, stepMeters: 50_000)
        let segments = splitAtAntimeridian(coords)
        var props = JSONObject()
        props["kind"] = .string(kind)
        // Use MultiLineString when the path crosses the antimeridian to avoid Mapbox drawing across the full map width.
        let geometry: Geometry = segments.count == 1
            ? .lineString(LineString(segments[0]))
            : .multiLineString(MultiLineString(segments))
        var feature = Feature(geometry: geometry)
        feature.properties = props
        return feature
    }

    /// Splits coordinates into sub-arrays at antimeridian crossings so Mapbox renders each segment correctly.
    private func splitAtAntimeridian(_ coords: [CLLocationCoordinate2D]) -> [[CLLocationCoordinate2D]] {
        guard coords.count > 1 else { return [coords] }
        var segments: [[CLLocationCoordinate2D]] = []
        var current: [CLLocationCoordinate2D] = [coords[0]]
        for i in 1..<coords.count {
            let prev = coords[i - 1], next = coords[i]
            let dLon = next.longitude - prev.longitude
            if abs(dLon) > 180 {
                let crossLat = prev.latitude + (next.latitude - prev.latitude) * 0.5
                current.append(CLLocationCoordinate2D(latitude: crossLat, longitude: dLon > 0 ? -180 : 180))
                segments.append(current)
                current = [CLLocationCoordinate2D(latitude: crossLat, longitude: dLon > 0 ? 180 : -180)]
            }
            current.append(next)
        }
        segments.append(current)
        return segments
    }

    /// Samples great-circle coordinates between two points so the line follows the shortest globe path.
    private func greatCircleCoordinates(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, stepMeters: Double = 50_000) -> [CLLocationCoordinate2D] {
        let toRad = Double.pi / 180, toDeg = 180 / Double.pi
        let lat1 = start.latitude * toRad, lon1 = start.longitude * toRad
        let lat2 = end.latitude * toRad,   lon2 = end.longitude * toRad
        let dLat = lat2 - lat1, dLon = lon2 - lon1
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let angularDistance = 2 * atan2(sqrt(a), sqrt(1 - a))
        let steps = max(2, Int(ceil(angularDistance * 6_371_000.0 / stepMeters)))
        var coords: [CLLocationCoordinate2D] = []
        coords.reserveCapacity(steps + 1)
        for i in 0...steps {
            let f = Double(i) / Double(steps)
            guard angularDistance > 1e-10 else { coords.append(start); continue }
            let sinD = sin(angularDistance)
            let A = sin((1 - f) * angularDistance) / sinD
            let B = sin(f * angularDistance) / sinD
            let x = A * cos(lat1) * cos(lon1) + B * cos(lat2) * cos(lon2)
            let y = A * cos(lat1) * sin(lon1) + B * cos(lat2) * sin(lon2)
            let z = A * sin(lat1) + B * sin(lat2)
            coords.append(CLLocationCoordinate2D(latitude: atan2(z, sqrt(x * x + y * y)) * toDeg, longitude: atan2(y, x) * toDeg))
        }
        return coords
    }

    private func addRouteSource(to mapView: MapView) throws {
        var source = GeoJSONSource(id: Self.routeSourceId)
        source.data = .featureCollection(FeatureCollection(features: []))
        try mapView.mapboxMap.addSource(source)
    }

    private func addColoredRouteLayer(to mapView: MapView) throws {
        var layer = LineLayer(id: Self.coloredRouteLayerId, source: Self.routeSourceId)
        layer.filter = Exp(.inExpression) {
            Exp(.get) { "kind" }
            Exp(.literal) { [Self.kindDeparture, Self.kindArrival] }
        }
        layer.lineColor = .expression(
            Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "kind" }; Self.kindDeparture }; Exp(.rgba) { 255; 59; 48; 1 }   // red
                Exp(.eq) { Exp(.get) { "kind" }; Self.kindArrival };   Exp(.rgba) { 52; 199; 89; 1 }   // green
                Exp(.rgba) { 255; 255; 255; 1 }
            }
        )
        layer.lineWidth = .constant(1.5)
        layer.lineOpacity = .constant(0.9)
        try mapView.mapboxMap.addLayer(layer)
    }

    private func addDashedRouteLayer(to mapView: MapView) throws {
        var layer = LineLayer(id: Self.dashedRouteLayerId, source: Self.routeSourceId)
        layer.filter = Exp(.eq) { Exp(.get) { "kind" }; Self.kindDashed }
        layer.lineColor     = .constant(StyleColor(.systemGray))
        layer.lineWidth     = .constant(1.5)
        layer.lineOpacity   = .constant(0.7)
        layer.lineDasharray = .constant([4, 4])
        try mapView.mapboxMap.addLayer(layer)
    }
}
