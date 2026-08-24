//
//  SectorStyleManager.swift
//  VatSight
//
//  Created by Marcel Marzec on 28/07/2026.
//

import Foundation
import UIKit
import MapboxMaps

final class SectorStyleManager {
    static let sectorSourceId = "sectors-source"
    static let sectorLabelSourceId = "sectors-label-source"
    static let sectorFillLayerId = "sector-fill-layer"
    static let sectorOutlineLayerId = "sector-outline-layer"
    static let sectorLabelLayerId = "sector-label-layer"

    private let activeSectorFillColor = StyleColor(UIColor.systemBlue.withAlphaComponent(0.08))
    private let activeSectorStrokeColor = StyleColor(UIColor.systemBlue.withAlphaComponent(0.6))
    private let inactiveSectorFillColor = StyleColor(UIColor.systemGray.withAlphaComponent(0.03))
    private let inactiveSectorStrokeColor = StyleColor(UIColor.systemGray.withAlphaComponent(0.2))
    
    enum SectorStyleError: Error {
        case layerAlreadyExists
    }
    
    // MARK: - Configure
    
    func configureSectors(on mapView: MapView) throws {
        try addSectorSource(to: mapView)
        try addSectorFillLayer(to: mapView)
        try addSectorOutlineLayer(to: mapView)
        try addSectorLabelSource(to: mapView)
        try addSectorLabelLayer(to: mapView)
    }
    
    // MARK: - Update Source
    
    func updateSectors(
        on mapView: MapView,
        sectors: [VatglassesSector],
        controllers: [Controllers],
        airports: [VatglassesAirport] = [],
        selectedControllerCID: Int? = nil,
        friendCIDs: Set<Int> = []
    ) {
        let collection = SectorGeoJSON.featureCollection(
            from: sectors,
            controllers: controllers,
            selectedControllerCID: selectedControllerCID
        )
        mapView.mapboxMap.updateGeoJSONSource(
            withId: Self.sectorSourceId,
            geoJSON: .featureCollection(collection)
        )

        let labelCollection = SectorGeoJSON.labelPointFeatureCollection(
            from: sectors,
            airports: airports,
            selectedControllerCID: selectedControllerCID,
            friendCIDs: friendCIDs
        )
        mapView.mapboxMap.updateGeoJSONSource(
            withId: Self.sectorLabelSourceId,
            geoJSON: .featureCollection(labelCollection)
        )
    }
    
    // MARK: - Ensure Layer Order
    
    /// Moves the sector label layer to the top of the layer stack so it renders above pilots.
    func ensureSectorLabelIsOnTop(on mapView: MapView) {
        guard mapView.mapboxMap.layerExists(withId: Self.sectorLabelLayerId) else { return }
        
        let allLayers = mapView.mapboxMap.allLayerIdentifiers
        if let lastLayer = allLayers.last, lastLayer.id == Self.sectorLabelLayerId { return }
        
        do {
            guard let currentLayer = try? mapView.mapboxMap.layer(withId: Self.sectorLabelLayerId, type: SymbolLayer.self) else { return }
            try mapView.mapboxMap.removeLayer(withId: Self.sectorLabelLayerId)
            try mapView.mapboxMap.addLayer(currentLayer, layerPosition: nil)
        } catch {
            print("Failed to move sector label layer to top: \(error)")
        }
    }
    
    // MARK: - Remove Layers
    
    func removeSectorLayers(from mapView: MapView) {
        try? mapView.mapboxMap.removeLayer(withId: Self.sectorLabelLayerId)
        try? mapView.mapboxMap.removeLayer(withId: Self.sectorOutlineLayerId)
        try? mapView.mapboxMap.removeLayer(withId: Self.sectorFillLayerId)
        try? mapView.mapboxMap.removeSource(withId: Self.sectorSourceId)
        try? mapView.mapboxMap.removeSource(withId: Self.sectorLabelSourceId)
    }
    
    // MARK: - Add Source
    
    private func addSectorSource(to mapView: MapView) throws {
        var source = GeoJSONSource(id: Self.sectorSourceId)
        source.data = .featureCollection(FeatureCollection(features: []))
        try mapView.mapboxMap.addSource(source)
    }

    private func addSectorLabelSource(to mapView: MapView) throws {
        var source = GeoJSONSource(id: Self.sectorLabelSourceId)
        source.data = .featureCollection(FeatureCollection(features: []))
        try mapView.mapboxMap.addSource(source)
    }
    
    // MARK: - Fill Layer
    
    private func addSectorFillLayer(to mapView: MapView) throws {
        var layer = FillLayer(
            id: Self.sectorFillLayerId,
            source: Self.sectorSourceId
        )
        
        layer.fillColor = .expression(
            Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isSelected" }; true }
                Exp(.rgba) { 255; 59; 48; 0.1 }
                Exp(.eq) {
                    Exp(.get) { "isActive" }
                    true
                }
                Exp(.switchCase) {
                    Exp(.has) { "colorHex" }
                    Exp(.toColor) {
                        Exp(.get) { "colorHex" }
                    }
                    Exp(.rgba) { 30; 144; 255; 0.05 }
                }
                Exp(.rgba) { 128; 128; 128; 0.03 }
            }
        )

        // Selected sectors use a fixed opacity; active sectors with a custom color use
        // fillOpacity for transparency; others encode alpha directly in their fill color.
        layer.fillOpacity = .expression(
            Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isSelected" }; true }
                1.0
                Exp(.all) {
                    Exp(.eq) {
                        Exp(.get) { "isActive" }
                        true
                    }
                    Exp(.has) { "colorHex" }
                }
                0.05
                1.0
            }
        )
        
        try mapView.mapboxMap.addLayer(layer)
    }
    
    // MARK: - Outline Layer
    
    private func addSectorOutlineLayer(to mapView: MapView) throws {
        var layer = LineLayer(
            id: Self.sectorOutlineLayerId,
            source: Self.sectorSourceId
        )
        
        layer.lineColor = .expression(
            Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isSelected" }; true }
                Exp(.rgba) { 255; 59; 48; 1.0 }
                Exp(.eq) {
                    Exp(.get) { "isActive" }
                    true
                }
                Exp(.switchCase) {
                    Exp(.has) { "colorHex" }
                    Exp(.toColor) {
                        Exp(.get) { "colorHex" }
                    }
                    Exp(.rgba) { 30; 144; 255; 0.6 }
                }
                Exp(.rgba) { 128; 128; 128; 0.5 }
            }
        )

        layer.lineWidth = .expression(
            Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isSelected" }; true }
                3.0
                Exp(.eq) {
                    Exp(.get) { "isActive" }
                    true
                }
                2.5
                1.5
            }
        )
        
        // Selected and active sectors with custom color use lineOpacity; others encode alpha in the color itself.
        layer.lineOpacity = .expression(
            Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isSelected" }; true }
                1.0
                Exp(.all) {
                    Exp(.eq) {
                        Exp(.get) { "isActive" }
                        true
                    }
                    Exp(.has) { "colorHex" }
                }
                0.6
                1.0
            }
        )
        
        try mapView.mapboxMap.addLayer(layer)
    }
    
    // MARK: - Label Layer

    /// The label layer reads from the dedicated label-point source, not the polygon source.
    /// Below zoom 7: shows only the short callsign (e.g. "LRBB_S").
    /// At zoom 7+, or when selected: shows full callsign + frequency on two lines.
    private func addSectorLabelLayer(to mapView: MapView) throws {
        var layer = SymbolLayer(
            id: Self.sectorLabelLayerId,
            source: Self.sectorLabelSourceId
        )

        // Below zoom 7 show short callsign; at zoom 7+ (or when selected) show full label.
        layer.textField = .expression(
            Exp(.step) {
                Exp(.zoom)
                // zoom < 7: short callsign, unless selected
                Exp(.switchCase) {
                    Exp(.eq) { Exp(.get) { "isSelected" }; true }
                    Exp(.concat) {
                        Exp(.get) { "controllerCallsign" }
                        "\n"
                        Exp(.get) { "controllerFrequency" }
                    }
                    Exp(.get) { "controllerShortCallsign" }
                }
                7
                // zoom >= 7: always full callsign + frequency
                Exp(.concat) {
                    Exp(.get) { "controllerCallsign" }
                    "\n"
                    Exp(.get) { "controllerFrequency" }
                }
            }
        )

        layer.textSize = .constant(12)
        layer.textFont = .constant(["Arial Unicode MS Regular"])

        // White text, red when selected, green for friend controllers.
        layer.textColor = .expression(
            Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isSelected" }; true }
                Exp(.rgba) { 255; 59; 48; 1.0 }
                Exp(.eq) { Exp(.get) { "isFriend" }; true }
                Exp(.rgba) { 52; 199; 89; 1.0 }
                Exp(.rgba) { 255; 255; 255; 1.0 }
            }
        )

        layer.textHaloColor = .constant(StyleColor(.black))
        layer.textHaloWidth = .constant(1.0)
        layer.textPadding = .constant(5)
        layer.textLineHeight = .constant(1.2)

        // Always show — the placement algorithm already avoids airports.
        layer.textAllowOverlap = .constant(true)
        layer.textIgnorePlacement = .constant(true)

        // Fade in above zoom 4 to match airport labels.
        layer.textOpacity = .expression(
            Exp(.step) {
                Exp(.zoom)
                0
                4
                1
            }
        )

        layer.symbolPlacement = .constant(.point)
        layer.symbolZOrder = .constant(.auto)

        try mapView.mapboxMap.addLayer(layer)
    }
}
