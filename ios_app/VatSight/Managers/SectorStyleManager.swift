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

    private var isDarkTheme: Bool = true

    enum SectorStyleError: Error {
        case layerAlreadyExists
    }
    
    // MARK: - Configure
    
    func configureSectors(on mapView: MapView, isDark: Bool = true) throws {
        isDarkTheme = isDark
        try addSectorSource(to: mapView)
        try addSectorFillLayer(to: mapView)
        try addSectorOutlineLayer(to: mapView)
        try addSectorLabelSource(to: mapView)
        try addSectorLabelLayer(to: mapView)
    }

    /// Re-tints sector layers in place when the app theme changes.
    func applyTheme(on mapView: MapView, isDark: Bool) {
        isDarkTheme = isDark
        let halo: StyleColor = isDark ? StyleColor(.black) : StyleColor(.white)
        let labelColorExp = sectorLabelColorExpression()

        try? mapView.mapboxMap.updateLayer(withId: Self.sectorFillLayerId, type: FillLayer.self) { [self] layer in
            layer.fillColor = .expression(sectorFillColorExpression())
            layer.fillOpacity = .expression(sectorFillOpacityExpression())
        }
        try? mapView.mapboxMap.updateLayer(withId: Self.sectorOutlineLayerId, type: LineLayer.self) { [self] layer in
            layer.lineColor = .expression(sectorOutlineColorExpression())
            layer.lineOpacity = .expression(sectorOutlineOpacityExpression())
        }
        try? mapView.mapboxMap.updateLayer(withId: Self.sectorLabelLayerId, type: SymbolLayer.self) { layer in
            layer.textColor = .expression(labelColorExp)
            layer.textHaloColor = .constant(halo)
        }
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
        
        layer.fillColor = .expression(sectorFillColorExpression())
        layer.fillOpacity = .expression(sectorFillOpacityExpression())
        
        try mapView.mapboxMap.addLayer(layer)
    }
    
    // MARK: - Outline Layer
    
    private func addSectorOutlineLayer(to mapView: MapView) throws {
        var layer = LineLayer(
            id: Self.sectorOutlineLayerId,
            source: Self.sectorSourceId
        )
        
        layer.lineColor = .expression(sectorOutlineColorExpression())
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
        layer.lineOpacity = .expression(sectorOutlineOpacityExpression())
        
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

        layer.textColor = .expression(sectorLabelColorExpression())
        layer.textHaloColor = .constant(isDarkTheme ? StyleColor(.black) : StyleColor(.white))
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

    // MARK: - Theme Color Helpers

    private func sectorFillColorExpression() -> Exp {
        if isDarkTheme {
            return Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isSelected" }; true }
                Exp(.rgba) { 255; 59; 48; 0.1 }
                Exp(.eq) { Exp(.get) { "isActive" }; true }
                Exp(.switchCase) {
                    Exp(.has) { "colorHex" }
                    Exp(.toColor) { Exp(.get) { "colorHex" } }
                    Exp(.rgba) { 30; 144; 255; 0.05 }
                }
                Exp(.rgba) { 128; 128; 128; 0.03 }
            }
        } else {
            // Light mode: VATGlasses hex colors are vivid dark-mode colors, so we
            // fall back to a soft blue tint and keep all fills very light.
            return Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isSelected" }; true }
                Exp(.rgba) { 255; 59; 48; 0.08 }
                Exp(.eq) { Exp(.get) { "isActive" }; true }
                Exp(.rgba) { 30; 100; 200; 0.06 }  // soft blue instead of raw hex
                Exp(.rgba) { 100; 100; 110; 0.04 }
            }
        }
    }

    private func sectorFillOpacityExpression() -> Exp {
        // Opacity is always 1.0 here because alpha is baked into the fill color.
        return Exp(.literal) { 1.0 }
    }

    private func sectorOutlineColorExpression() -> Exp {
        if isDarkTheme {
            return Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isSelected" }; true }
                Exp(.rgba) { 255; 59; 48; 1.0 }
                Exp(.eq) { Exp(.get) { "isActive" }; true }
                Exp(.switchCase) {
                    Exp(.has) { "colorHex" }
                    Exp(.toColor) { Exp(.get) { "colorHex" } }
                    Exp(.rgba) { 30; 144; 255; 0.6 }
                }
                Exp(.rgba) { 128; 128; 128; 0.5 }
            }
        } else {
            // Light mode: use a muted blue stroke and softer inactive lines
            return Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isSelected" }; true }
                Exp(.rgba) { 255; 59; 48; 0.9 }
                Exp(.eq) { Exp(.get) { "isActive" }; true }
                Exp(.rgba) { 30; 100; 200; 0.5 }
                Exp(.rgba) { 100; 100; 110; 0.35 }
            }
        }
    }

    private func sectorOutlineOpacityExpression() -> Exp {
        return Exp(.literal) { 1.0 }
    }

    private func sectorLabelColorExpression() -> Exp {
        if isDarkTheme {
            return Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isSelected" }; true }
                Exp(.rgba) { 255; 59; 48; 1.0 }
                Exp(.eq) { Exp(.get) { "isFriend" }; true }
                Exp(.rgba) { 48; 230; 110; 1.0 }   // bright lime-green — matches pilot/airport
                Exp(.rgba) { 255; 255; 255; 1.0 }
            }
        } else {
            return Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isSelected" }; true }
                Exp(.rgba) { 255; 59; 48; 1.0 }
                Exp(.eq) { Exp(.get) { "isFriend" }; true }
                Exp(.rgba) { 20; 155; 65; 1.0 }    // deep forest green — matches pilot/airport
                Exp(.rgba) { 75; 80; 95; 1.0 }
            }
        }
    }
}
