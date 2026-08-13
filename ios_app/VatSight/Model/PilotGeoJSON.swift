//
//  PilotGeoJSON.swift
//  VatSight
//
//  Created by Marcel Marzec on 14/05/2026.
//

import Foundation
import MapboxMaps
import Turf

enum PilotGeoJSON {

    static func featureCollection(
        from pilots: [Pilot],
        selectedCID: Int?
    ) -> FeatureCollection {

        FeatureCollection(
            features: pilots.map {
                feature(from: $0, selectedCID: selectedCID)
            }
        )
    }

    static func feature(
        from pilot: Pilot,
        selectedCID: Int?
    ) -> Feature {

        var feature = Feature(
            geometry: .point(
                Point(
                    CLLocationCoordinate2D(
                        latitude: pilot.latitude,
                        longitude: pilot.longitude
                    )
                )
            )
        )

        let isSelected = pilot.cid == selectedCID
        let isOnGround = pilot.groundspeed < 40

        feature.properties = [
            "cid": .number(Double(pilot.cid)),
            "callsign": .string(pilot.callsign),
            "heading": .number(Double(pilot.heading)),
            "isSelected": .boolean(isSelected),
            "isOnGround": .boolean(isOnGround)
        ]

        return feature
    }
}
