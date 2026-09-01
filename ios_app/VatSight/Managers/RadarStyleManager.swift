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
    static let selfPilotIconImageId = "selfPilot"
    static let pilotIconLayerId = "pilot-icon-layer"
    static let pilotLabelLayerId = "pilot-label-layer"
    static let pilotGroundIconLayerId = "pilot-ground-icon-layer"
    static let pilotGroundLabelLayerId = "pilot-ground-label-layer"

    private var isDarkTheme: Bool = true

    enum RadarStyleError: Error {
        case missingPilotAsset
    }

    // MARK: - Configure

    func configurePilots(on mapView: MapView, isDark: Bool = true) throws {
        isDarkTheme = isDark
        try addPilotImage(to: mapView)
        try addPilotSource(to: mapView)
        try addPilotIconLayer(to: mapView)
        try addPilotLabelLayer(to: mapView)
        try addPilotGroundIconLayer(to: mapView)
        try addPilotGroundLabelLayer(to: mapView)
    }

    /// Call this when the app theme changes without a full style reload,
    /// to update the icon and label tint colors on existing layers.
    func applyTheme(on mapView: MapView, isDark: Bool) {
        isDarkTheme = isDark

        let iconExp = pilotIconColorExpression()
        let labelExp = pilotLabelColorExpression()
        let haloColor = pilotLabelHaloColor()

        for layerId in [Self.pilotIconLayerId, Self.pilotGroundIconLayerId] {
            try? mapView.mapboxMap.updateLayer(withId: layerId, type: SymbolLayer.self) { layer in
                layer.iconColor = .expression(iconExp)
            }
        }
        for layerId in [Self.pilotLabelLayerId, Self.pilotGroundLabelLayerId] {
            try? mapView.mapboxMap.updateLayer(withId: layerId, type: SymbolLayer.self) { layer in
                layer.textColor = .expression(labelExp)
                layer.textHaloColor = .constant(haloColor)
            }
        }
    }

    // MARK: - Update Source

    func updatePilots(
        on mapView: MapView,
        pilots: [Pilot],
        selectedCID: Int?,
        friendCIDs: Set<Int> = [],
        myCID: Int = 0
    ) {

        let collection = PilotGeoJSON.featureCollection(
            from: pilots,
            selectedCID: selectedCID,
            friendCIDs: friendCIDs,
            myCID: myCID
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

        // Register as SDF (Signed Distance Field) so Mapbox can tint via iconColor at runtime.
        try mapView.mapboxMap.addImage(pilot,    id: "pilot",         sdf: true)
        try mapView.mapboxMap.addImage(selected, id: "selectedPilot", sdf: true)
        try mapView.mapboxMap.addImage(friend,   id: "friendPilot",   sdf: true)
        // "selfPilot" reuses the same sprite as "pilot" — the gold colour is applied via iconColor.
        try mapView.mapboxMap.addImage(pilot,    id: "selfPilot",     sdf: true)
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

        // All images are registered as SDF, so iconColor tints them at runtime.
        // isSelf is checked first (highest priority) so the user's own aircraft always
        // renders in gold regardless of selected/friend state.
        layer.iconImage = .expression(
            Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isSelf" }; true }
                "selfPilot"
                Exp(.eq) { Exp(.get) { "isSelected" }; true }
                "selectedPilot"
                Exp(.eq) { Exp(.get) { "isFriend" }; true }
                "friendPilot"
                "pilot"
            }
        )

        layer.iconColor = .expression(pilotIconColorExpression())

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
        // textAllowOverlap: false  → hide this label if it overlaps another aircraft label
        // textIgnorePlacement: false → register this label's footprint so other aircraft
        //                              labels avoid it. Does NOT block sector/airport labels
        //                              because those layers run their own placement passes.
        layer.textAllowOverlap = .constant(false)
        layer.textIgnorePlacement = .constant(false)
        layer.textColor = .expression(pilotLabelColorExpression())
        layer.textHaloColor = .constant(pilotLabelHaloColor())
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
                Exp(.eq) { Exp(.get) { "isSelf" }; true }
                "selfPilot"
                Exp(.eq) { Exp(.get) { "isSelected" }; true }
                "selectedPilot"
                Exp(.eq) { Exp(.get) { "isFriend" }; true }
                "friendPilot"
                "pilot"
            }
        )

        layer.iconColor = .expression(pilotIconColorExpression())

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
        // Same collision policy as the airborne label layer — aircraft-vs-aircraft only.
        layer.textAllowOverlap = .constant(false)
        layer.textIgnorePlacement = .constant(false)
        layer.textColor = .expression(pilotLabelColorExpression())
        layer.textHaloColor = .constant(pilotLabelHaloColor())
        layer.textHaloWidth = .constant(1.0)
        layer.textFont = .constant(["Arial Unicode MS Regular"])
        layer.textPadding = .constant(2)
        layer.symbolSortKey = .constant(1000)
        layer.symbolZOrder = .constant(.auto)
        layer.minZoom = 10

        try mapView.mapboxMap.addLayer(layer)
    }

    // MARK: - Helpers

    /// Returns a switchCase Exp that tints the SDF pilot icon by state and theme.
    /// Priority order: isSelf (gold) > isSelected (red) > isFriend (green) > default.
    private func pilotIconColorExpression() -> Exp {
        if isDarkTheme {
            return Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isSelf" }; true }
                Exp(.rgba) { 255; 200; 0; 1.0 }    // gold
                Exp(.eq) { Exp(.get) { "isSelected" }; true }
                Exp(.rgba) { 255; 59; 48; 1.0 }    // red
                Exp(.eq) { Exp(.get) { "isFriend" }; true }
                Exp(.rgba) { 48; 230; 110; 1.0 }   // bright lime-green — vivid on dark map
                Exp(.rgba) { 255; 255; 255; 1.0 }  // white
            }
        } else {
            return Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isSelf" }; true }
                Exp(.rgba) { 200; 150; 0; 1.0 }    // deeper gold — readable on light map
                Exp(.eq) { Exp(.get) { "isSelected" }; true }
                Exp(.rgba) { 255; 59; 48; 1.0 }    // red
                Exp(.eq) { Exp(.get) { "isFriend" }; true }
                Exp(.rgba) { 20; 155; 65; 1.0 }    // deep forest green — reads well on light map
                Exp(.rgba) { 51; 64; 102; 1.0 }    // matches sector label stroke
            }
        }
    }

    private func pilotLabelColorExpression() -> Exp {
        if isDarkTheme {
            return Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isSelf" }; true }
                Exp(.rgba) { 255; 200; 0; 1.0 }    // gold — matches icon
                Exp(.eq) { Exp(.get) { "isFriend" }; true }
                Exp(.rgba) { 48; 230; 110; 1.0 }   // matches icon
                Exp(.rgba) { 255; 255; 255; 1.0 }
            }
        } else {
            return Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isSelf" }; true }
                Exp(.rgba) { 200; 150; 0; 1.0 }    // deeper gold — matches icon
                Exp(.eq) { Exp(.get) { "isFriend" }; true }
                Exp(.rgba) { 20; 155; 65; 1.0 }    // matches icon
                Exp(.rgba) { 51; 64; 102; 1.0 }    // matches sector label stroke
            }
        }
    }

    private func pilotLabelHaloColor() -> StyleColor {
        isDarkTheme ? StyleColor(.black) : StyleColor(.white)
    }
}
