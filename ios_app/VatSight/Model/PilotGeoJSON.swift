//
//  PilotGeoJSON.swift
//  VatSight
//

import Foundation
import MapboxMaps
import Turf

enum PilotGeoJSON {

    static func featureCollection(from pilots: [Pilot]) -> FeatureCollection {
        FeatureCollection(features: pilots.map(feature(from:)))
    }

    static func feature(from pilot: Pilot) -> Feature {
        var feature = Feature(
            geometry: .point(
                Point(
                    LocationCoordinate2D(
                        latitude: pilot.latitude,
                        longitude: pilot.longitude
                    )
                )
            )
        )

        feature.properties = [
            "cid": .number(Double(pilot.cid)),
            "callsign": .string(pilot.callsign),
            "name": .string(pilot.name),
            "heading": .number(Double(pilot.heading))
        ]

        return feature
    }
}
