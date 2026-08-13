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
        try addSectorLabelLayer(to: mapView)
    }
    
    // MARK: - Update Source
    
    func updateSectors(
        on mapView: MapView,
        sectors: [VatglassesSector],
        controllers: [Controllers]
    ) {
        let collection = SectorGeoJSON.featureCollection(
            from: sectors,
            controllers: controllers
        )
        
        mapView.mapboxMap.updateGeoJSONSource(
            withId: Self.sectorSourceId,
            geoJSON: .featureCollection(collection)
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
    }
    
    // MARK: - Add Source
    
    private func addSectorSource(to mapView: MapView) throws {
        var source = GeoJSONSource(id: Self.sectorSourceId)
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
                Exp(.eq) {
                    Exp(.get) { "isActive" }
                    true
                }
                Exp(.switchCase) {
                    Exp(.has) { "colorHex" }
                    Exp(.toColor) {
                        Exp(.get) { "colorHex" }
                    }
                    Exp(.rgba) { 30; 144; 255; 0.08 }
                }
                Exp(.rgba) { 128; 128; 128; 0.03 }
            }
        )

        // Active sectors with a custom color use fillOpacity for transparency;
        // others encode alpha directly in their fill color.
        layer.fillOpacity = .expression(
            Exp(.switchCase) {
                Exp(.all) {
                    Exp(.eq) {
                        Exp(.get) { "isActive" }
                        true
                    }
                    Exp(.has) { "colorHex" }
                }
                0.08
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
                Exp(.rgba) { 128; 128; 128; 0.2 }
            }
        )

        layer.lineWidth = .expression(
            Exp(.switchCase) {
                Exp(.eq) {
                    Exp(.get) { "isActive" }
                    true
                }
                2.5
                1.5
            }
        )
        
        // Active sectors with a custom color use lineOpacity; others encode alpha in the color itself.
        layer.lineOpacity = .expression(
            Exp(.switchCase) {
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
    
    private func addSectorLabelLayer(to mapView: MapView) throws {
        var layer = SymbolLayer(
            id: Self.sectorLabelLayerId,
            source: Self.sectorSourceId
        )
        
        // Only display a label for active sectors that have controller info
        layer.textField = .expression(
            Exp(.switchCase) {
                Exp(.all) {
                    Exp(.eq) {
                        Exp(.get) { "isActive" }
                        true
                    }
                    Exp(.has) { "controllerCallsign" }
                    Exp(.has) { "controllerFrequency" }
                }
                Exp(.concat) {
                    Exp(.get) { "controllerCallsign" }
                    "\n"
                    Exp(.get) { "controllerFrequency" }
                }
                ""
            }
        )

        layer.textSize = .constant(12)
        layer.textColor = .constant(StyleColor(.white))
        layer.textHaloColor = .constant(StyleColor(UIColor.black))
        layer.textHaloWidth = .constant(50.0)
        layer.textLetterSpacing = .constant(0.05)
        layer.textLineHeight = .constant(1.2)
        layer.textAllowOverlap = .constant(false)
        layer.textIgnorePlacement = .constant(true)
        layer.textOptional = .constant(false)
        layer.textPadding = .constant(5)

        // Match the zoom threshold used by pilot labels
        layer.textOpacity = .expression(
            Exp(.step) {
                Exp(.zoom)
                0
                5
                1
            }
        )

        layer.symbolPlacement = .constant(.point)
        layer.symbolSortKey = .constant(10000)
        layer.symbolZOrder = .constant(.auto)

        try mapView.mapboxMap.addLayer(layer)
    }
}
