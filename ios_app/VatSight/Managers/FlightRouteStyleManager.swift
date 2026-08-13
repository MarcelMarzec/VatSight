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

    // MARK: - Feature kind values

    /// Departure leg — rendered red
    private static let kindDeparture = "departure"
    /// Arrival leg — rendered green
    private static let kindArrival   = "arrival"
    /// Alternate leg — rendered dashed gray
    private static let kindDashed    = "dashed"

    // MARK: - Configure

    func configureRoutes(on mapView: MapView) throws {
        try addRouteSource(to: mapView)
        try addColoredRouteLayer(to: mapView)
        try addDashedRouteLayer(to: mapView)
    }

    // MARK: - Update (pilot selected)

    /// Rebuilds departure (red) and arrival (green) lines for the given pilot.
    /// Pass nil pilot (or no matching airports) to clear all lines.
    func updateRoutes(
        on mapView: MapView,
        pilot: Pilot?,
        airportCoordinates: [String: CLLocationCoordinate2D]
    ) {
        guard mapView.mapboxMap.sourceExists(withId: Self.routeSourceId) else { return }

        var features: [Feature] = []

        if let pilot, let fp = pilot.flight_plan {
            let pilotCoord = pilot.coordinate

            // Departure line — red
            if !fp.departure.isEmpty, let depCoord = airportCoordinates[fp.departure] {
                features.append(
                    makeLineFeature(from: pilotCoord, to: depCoord, kind: Self.kindDeparture)
                )
            }

            // Arrival line — green
            if !fp.arrival.isEmpty, let arrCoord = airportCoordinates[fp.arrival] {
                features.append(
                    makeLineFeature(from: pilotCoord, to: arrCoord, kind: Self.kindArrival)
                )
            }

            // Alternate line — dashed gray
            if !fp.alternate.isEmpty, let altCoord = airportCoordinates[fp.alternate] {
                features.append(
                    makeLineFeature(from: pilotCoord, to: altCoord, kind: Self.kindDashed)
                )
            }
        }

        let collection = FeatureCollection(features: features)
        mapView.mapboxMap.updateGeoJSONSource(
            withId: Self.routeSourceId,
            geoJSON: .featureCollection(collection)
        )
    }

    // MARK: - Update (airport selected)

    /// Rebuilds lines from the selected airport to all associated airborne pilots.
    /// Departure aircraft get red lines, arrival aircraft get green lines.
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
                features.append(
                    makeLineFeature(from: airportCoord, to: pilot.coordinate, kind: Self.kindDeparture)
                )
            }
            for pilot in airborneArrivals {
                features.append(
                    makeLineFeature(from: airportCoord, to: pilot.coordinate, kind: Self.kindArrival)
                )
            }
        }

        let collection = FeatureCollection(features: features)
        mapView.mapboxMap.updateGeoJSONSource(
            withId: Self.routeSourceId,
            geoJSON: .featureCollection(collection)
        )
    }

    // MARK: - Remove

    func removeRouteLayers(from mapView: MapView) {
        try? mapView.mapboxMap.removeLayer(withId: Self.dashedRouteLayerId)
        try? mapView.mapboxMap.removeLayer(withId: Self.coloredRouteLayerId)
        try? mapView.mapboxMap.removeSource(withId: Self.routeSourceId)
    }

    // MARK: - Private Helpers

    private func makeLineFeature(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D,
        kind: String
    ) -> Feature {
        let coords = greatCircleCoordinates(from: start, to: end, stepMeters: 50_000)
        let segments = splitAtAntimeridian(coords)

        var props = JSONObject()
        props["kind"] = .string(kind)

        // If the path never crosses the antimeridian use a plain LineString.
        // Otherwise use a MultiLineString so each segment is drawn correctly
        // without Mapbox connecting across the full map width.
        let geometry: Geometry
        if segments.count == 1 {
            geometry = .lineString(LineString(segments[0]))
        } else {
            geometry = .multiLineString(MultiLineString(segments))
        }

        var feature = Feature(geometry: geometry)
        feature.properties = props
        return feature
    }

    /// Splits a coordinate array into sub-arrays wherever the path crosses the
    /// antimeridian (±180°). Each segment stays within a single hemisphere so
    /// Mapbox can render it without drawing a line across the whole map.
    private func splitAtAntimeridian(
        _ coords: [CLLocationCoordinate2D]
    ) -> [[CLLocationCoordinate2D]] {
        guard coords.count > 1 else { return [coords] }

        var segments: [[CLLocationCoordinate2D]] = []
        var current: [CLLocationCoordinate2D] = [coords[0]]

        for i in 1..<coords.count {
            let prev = coords[i - 1]
            let next = coords[i]
            let dLon = next.longitude - prev.longitude

            // A jump > 180° in longitude means we crossed the antimeridian
            if abs(dLon) > 180 {
                // Interpolate the crossing latitude
                let crossLat = prev.latitude + (next.latitude - prev.latitude) * 0.5
                let crossLonPrev: Double = dLon > 0 ? -180 : 180
                let crossLonNext: Double = dLon > 0 ?  180 : -180

                current.append(CLLocationCoordinate2D(latitude: crossLat, longitude: crossLonPrev))
                segments.append(current)
                current = [CLLocationCoordinate2D(latitude: crossLat, longitude: crossLonNext)]
            }

            current.append(next)
        }

        segments.append(current)
        return segments
    }

    /// Returns a sequence of coordinates along the great circle between two points,
    /// sampled every `stepMeters` metres. This ensures the rendered line follows the
    /// shortest path on the globe, including correctly crossing the antimeridian and
    /// routing over the poles.
    private func greatCircleCoordinates(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D,
        stepMeters: Double = 50_000
    ) -> [CLLocationCoordinate2D] {
        let toRad = Double.pi / 180
        let toDeg = 180 / Double.pi

        let lat1 = start.latitude  * toRad
        let lon1 = start.longitude * toRad
        let lat2 = end.latitude    * toRad
        let lon2 = end.longitude   * toRad

        // Angular distance between the two points (haversine)
        let dLat = lat2 - lat1
        let dLon = lon2 - lon1
        let a = sin(dLat / 2) * sin(dLat / 2)
              + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let angularDistance = 2 * atan2(sqrt(a), sqrt(1 - a)) // radians

        let earthRadius = 6_371_000.0
        let totalMeters = angularDistance * earthRadius

        // Minimum two points (start + end); otherwise one step every `stepMeters`
        let steps = max(2, Int(ceil(totalMeters / stepMeters)))

        var coords: [CLLocationCoordinate2D] = []
        coords.reserveCapacity(steps + 1)

        for i in 0...steps {
            let f = Double(i) / Double(steps)
            guard angularDistance > 1e-10 else {
                coords.append(start)
                continue
            }
            let sinD = sin(angularDistance)
            let A = sin((1 - f) * angularDistance) / sinD
            let B = sin(f * angularDistance) / sinD

            let x = A * cos(lat1) * cos(lon1) + B * cos(lat2) * cos(lon2)
            let y = A * cos(lat1) * sin(lon1) + B * cos(lat2) * sin(lon2)
            let z = A * sin(lat1)              + B * sin(lat2)

            let lat = atan2(z, sqrt(x * x + y * y)) * toDeg
            let lon = atan2(y, x) * toDeg
            coords.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }

        return coords
    }

    private func addRouteSource(to mapView: MapView) throws {
        var source = GeoJSONSource(id: Self.routeSourceId)
        source.data = .featureCollection(FeatureCollection(features: []))
        try mapView.mapboxMap.addSource(source)
    }

    /// Coloured solid line for departure (red) and arrival (green) legs.
    /// Uses a data-driven expression to pick colour from the "kind" property.
    private func addColoredRouteLayer(to mapView: MapView) throws {
        var layer = LineLayer(id: Self.coloredRouteLayerId, source: Self.routeSourceId)

        // Only show departure and arrival features (exclude dashed alternate)
        layer.filter = Exp(.inExpression) {
            Exp(.get) { "kind" }
            Exp(.literal) { [Self.kindDeparture, Self.kindArrival] }
        }

        // Red for departure, green for arrival
        layer.lineColor = .expression(
            Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "kind" }; Self.kindDeparture }
                Exp(.rgba) { 255; 59; 48; 1 }    // systemRed
                Exp(.eq) { Exp(.get) { "kind" }; Self.kindArrival }
                Exp(.rgba) { 52; 199; 89; 1 }    // systemGreen
                Exp(.rgba) { 255; 255; 255; 1 }  // fallback white
            }
        )

        layer.lineWidth   = .constant(1.5)
        layer.lineOpacity = .constant(0.9)

        try mapView.mapboxMap.addLayer(layer)
    }

    /// Dashed gray line for alternate leg
    private func addDashedRouteLayer(to mapView: MapView) throws {
        var layer = LineLayer(id: Self.dashedRouteLayerId, source: Self.routeSourceId)

        // Only show features with kind == "dashed"
        layer.filter = Exp(.eq) {
            Exp(.get) { "kind" }
            Self.kindDashed
        }

        layer.lineColor     = .constant(StyleColor(.systemGray))
        layer.lineWidth     = .constant(1.5)
        layer.lineOpacity   = .constant(0.7)
        layer.lineDasharray = .constant([4, 4])

        try mapView.mapboxMap.addLayer(layer)
    }
}
