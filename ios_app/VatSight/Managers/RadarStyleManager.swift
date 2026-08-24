//
//  RadarStyleManager.swift
//  VatSight
//

import Foundation
import UIKit
import MapboxMaps

final class RadarStyleManager {
    static let pilotSourceId = "pilots-source"
    static let pilotIconImageId = "pilot"
    static let selectedPilotIconImageId = "selectedPilot"
    static let friendPilotIconImageId = "friendPilot"
    static let pilotIconLayerId = "pilot-icon-layer"
    static let pilotLabelLayerId = "pilot-label-layer"
    static let pilotGroundIconLayerId = "pilot-ground-icon-layer"
    static let pilotGroundLabelLayerId = "pilot-ground-label-layer"

    enum RadarStyleError: Error {
        case missingPilotAsset
    }

    // MARK: - Configure

    func configurePilots(
        on mapView: MapView
    ) throws {

        try addPilotImage(to: mapView)
        try addPilotSource(to: mapView)
        try addPilotIconLayer(to: mapView)
        try addPilotLabelLayer(to: mapView)
        try addPilotGroundIconLayer(to: mapView)
        try addPilotGroundLabelLayer(to: mapView)
    }

    // MARK: - Update Source

    func updatePilots(
        on mapView: MapView,
        pilots: [Pilot],
        selectedCID: Int?,
        friendCIDs: Set<Int> = []
    ) {

        let collection = PilotGeoJSON.featureCollection(
            from: pilots,
            selectedCID: selectedCID,
            friendCIDs: friendCIDs
        )

        mapView.mapboxMap.updateGeoJSONSource(
            withId: Self.pilotSourceId,
            geoJSON: .featureCollection(collection)
        )
    }

    // MARK: - Add Image

    private func addPilotImage(to mapView: MapView) throws {

        guard let pilot = UIImage(named: "pilot"),
              let selected = UIImage(named: "selectedPilot"),
              let friend = UIImage(named: "friendPilot") else {
            throw RadarStyleError.missingPilotAsset
        }

        try mapView.mapboxMap.addImage(pilot, id: "pilot")
        try mapView.mapboxMap.addImage(selected, id: "selectedPilot")
        try mapView.mapboxMap.addImage(friend, id: "friendPilot")
    }

    // MARK: - Add Source

    private func addPilotSource(
        to mapView: MapView
    ) throws {

        var source = GeoJSONSource(
            id: Self.pilotSourceId
        )

        source.data = .featureCollection(
            FeatureCollection(
                features: []
            )
        )

        try mapView.mapboxMap.addSource(source)
    }

    // MARK: - Icon Layer

    private func addPilotIconLayer(
        to mapView: MapView
    ) throws {

        var layer = SymbolLayer(
            id: Self.pilotIconLayerId,
            source: Self.pilotSourceId
        )

        layer.iconImage = .expression(
            Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isSelected" }; true }
                "selectedPilot"
                Exp(.eq) { Exp(.get) { "isFriend" }; true }
                "friendPilot"
                "pilot"
            }
        )

        layer.iconSize = .constant(0.65)

        layer.iconRotate = .expression(
            Exp(.get) { "heading" }
        )

        // Only show airborne aircraft on this layer
        layer.filter = Exp(.eq) { Exp(.get) { "isOnGround" }; false }

        layer.iconAllowOverlap = .constant(true)
        layer.iconIgnorePlacement = .constant(true)
        layer.iconRotationAlignment = .constant(.map)
        layer.symbolSortKey = .constant(1000)
        layer.symbolZOrder = .constant(.auto)

        try mapView.mapboxMap.addLayer(layer)
    }

    // MARK: - Callsign Layer

    private func addPilotLabelLayer(
        to mapView: MapView
    ) throws {

        var layer = SymbolLayer(
            id: Self.pilotLabelLayerId,
            source: Self.pilotSourceId
        )

        layer.textField = .expression(
            Exp(.get) {
                "callsign"
            }
        )

        // Only show airborne aircraft labels on this layer
        layer.filter = Exp(.eq) { Exp(.get) { "isOnGround" }; false }

        layer.textSize = .constant(12)
        layer.textAnchor = .constant(.left)
        layer.textOffset = .constant([0.8, 0])
        layer.textAllowOverlap = .constant(false)
        layer.textIgnorePlacement = .constant(true)
        layer.textColor = .expression(
            Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isFriend" }; true }
                Exp(.rgba) { 52; 199; 89; 1.0 }
                Exp(.rgba) { 255; 255; 255; 1.0 }
            }
        )
        layer.textHaloColor = .constant(StyleColor(.black))
        layer.textHaloWidth = .constant(1.0)
        layer.textFont = .constant(["Arial Unicode MS Regular"])
        layer.textPadding = .constant(2)

        layer.textOpacity = .expression(Exp(.step) {
            Exp(.zoom)
            0.0
            7
            1.0
        })

        layer.symbolSortKey = .constant(1000)
        layer.symbolZOrder = .constant(.auto)

        try mapView.mapboxMap.addLayer(layer)
    }

    // MARK: - On-Ground Icon Layer (shown only when zoomed in)

    private func addPilotGroundIconLayer(to mapView: MapView) throws {
        var layer = SymbolLayer(
            id: Self.pilotGroundIconLayerId,
            source: Self.pilotSourceId
        )

        layer.filter = Exp(.eq) { Exp(.get) { "isOnGround" }; true }

        layer.iconImage = .expression(
            Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isSelected" }; true }
                "selectedPilot"
                Exp(.eq) { Exp(.get) { "isFriend" }; true }
                "friendPilot"
                "pilot"
            }
        )

        layer.iconSize = .constant(0.65)

        layer.iconRotate = .expression(
            Exp(.get) { "heading" }
        )

        layer.iconAllowOverlap = .constant(true)
        layer.iconIgnorePlacement = .constant(true)
        layer.iconRotationAlignment = .constant(.map)
        layer.symbolSortKey = .constant(1000)
        layer.symbolZOrder = .constant(.auto)
        layer.minZoom = 10

        try mapView.mapboxMap.addLayer(layer)
    }

    // MARK: - On-Ground Label Layer (shown only when zoomed in)

    private func addPilotGroundLabelLayer(to mapView: MapView) throws {
        var layer = SymbolLayer(
            id: Self.pilotGroundLabelLayerId,
            source: Self.pilotSourceId
        )

        layer.filter = Exp(.eq) { Exp(.get) { "isOnGround" }; true }

        layer.textField = .expression(Exp(.get) { "callsign" })
        layer.textSize = .constant(12)
        layer.textAnchor = .constant(.left)
        layer.textOffset = .constant([0.8, 0])
        layer.textAllowOverlap = .constant(false)
        layer.textIgnorePlacement = .constant(true)
        layer.textColor = .expression(
            Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isFriend" }; true }
                Exp(.rgba) { 52; 199; 89; 1.0 }
                Exp(.rgba) { 255; 255; 255; 1.0 }
            }
        )
        layer.textHaloColor = .constant(StyleColor(.black))
        layer.textHaloWidth = .constant(1.0)
        layer.textFont = .constant(["Arial Unicode MS Regular"])
        layer.textPadding = .constant(2)
        layer.symbolSortKey = .constant(1000)
        layer.symbolZOrder = .constant(.auto)
        layer.minZoom = 10

        try mapView.mapboxMap.addLayer(layer)
    }
}
