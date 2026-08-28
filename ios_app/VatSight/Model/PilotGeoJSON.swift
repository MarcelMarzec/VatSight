//
//  PilotGeoJSON.swift
//  VatSight
//
//  Created by Marcel Marzec on 14/05/2026.
//

import Foundation
import MapboxMaps

enum PilotGeoJSON {

    static func featureCollection(
        from pilots: [Pilot],
        selectedCID: Int?,
        friendCIDs: Set<Int> = [],
        myCID: Int = 0
    ) -> FeatureCollection {

        FeatureCollection(
            features: pilots.map {
                feature(from: $0, selectedCID: selectedCID, friendCIDs: friendCIDs, myCID: myCID)
            }
        )
    }

    static func feature(
        from pilot: Pilot,
        selectedCID: Int?,
        friendCIDs: Set<Int> = [],
        myCID: Int = 0
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
        let isFriend = friendCIDs.contains(pilot.cid)
        let isSelf = myCID > 0 && pilot.cid == myCID

        feature.properties = [
            "cid": .number(Double(pilot.cid)),
            "callsign": .string(pilot.callsign),
            "heading": .number(Double(pilot.heading)),
            "isSelected": .boolean(isSelected),
            "isOnGround": .boolean(isOnGround),
            "isFriend": .boolean(isFriend),
            "isSelf": .boolean(isSelf)
        ]

        return feature
    }
}
