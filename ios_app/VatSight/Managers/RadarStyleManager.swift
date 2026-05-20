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

    static let pilotIconLayerId = "pilot-icon-layer"

    static let pilotLabelLayerId = "pilot-label-layer"

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
    }

    // MARK: - Update Source

    func updatePilots(
        on mapView: MapView,
        pilots: [Pilot]
    ) {

        let collection = PilotGeoJSON
            .featureCollection(from: pilots)

        mapView.mapboxMap.updateGeoJSONSource(
            withId: Self.pilotSourceId,
            geoJSON: .featureCollection(collection)
        )
    }

    // MARK: - Add Image

    private func addPilotImage(
        to mapView: MapView
    ) throws {

        guard let image = UIImage(named: "pilot") else {
            throw RadarStyleError.missingPilotAsset
        }

        try mapView.mapboxMap.addImage(
            image,
            id: Self.pilotIconImageId
        )
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
        
        layer.slot = "top"
        
        layer.iconImage = .constant(
            .name(Self.pilotIconImageId)
        )
        
        layer.iconSize = .constant(0.75)
        
        layer.iconAllowOverlap = .constant(true)
        
        layer.iconRotationAlignment = .constant(.map)
        
        layer.iconRotate = .expression(
            Exp(.get) {
                "heading"
            }
        )
        
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

        layer.slot = "top"

        layer.textField = .expression(
            Exp(.get) {
                "callsign"
            }
        )

        layer.textSize = .constant(12)

        layer.textAnchor = .constant(.top)

        layer.textOffset = .constant([0, -1.8])

        layer.textAllowOverlap = .constant(false)

        layer.textColor = .constant(
            StyleColor(.white)
        )

        layer.textHaloColor = .constant(
            StyleColor(.black)
        )

        layer.textHaloWidth = .constant(1)

        // SHOW ONLY WHEN ZOOM >= 5

        layer.textOpacity = .expression(

            Exp(.step) {

                Exp(.zoom)

                0

                5

                1
            }
        )

        try mapView.mapboxMap.addLayer(layer)
    }
}
