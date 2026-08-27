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
    static let sectorBasicOutlineLayerId = "sector-basic-outline-layer"
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
        try addSectorBasicOutlineLayer(to: mapView)
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
        try? mapView.mapboxMap.updateLayer(withId: Self.sectorBasicOutlineLayerId, type: LineLayer.self) { layer in
            layer.lineOpacity = .expression(Self.basicOutlineOpacityExpression())
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

        // The line layer handles all sector borders. Suppress fill-outline-color so Mapbox
        // does not draw its own per-ring hairline inside the fill layer.
        try? mapView.mapboxMap.updateLayer(withId: Self.sectorFillLayerId, type: FillLayer.self) { layer in
            layer.fillOutlineColor = .constant(StyleColor(.clear))
        }

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
        try? mapView.mapboxMap.removeLayer(withId: Self.sectorBasicOutlineLayerId)
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
        layer.fillAntialias = .constant(false)
        
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
    
    // MARK: - Basic Data Dashed Outline Layer

    /// Dashed amber outline layer rendered exclusively for active basic-data-only (nodata.json) sectors.
    private func addSectorBasicOutlineLayer(to mapView: MapView) throws {
        var layer = LineLayer(
            id: Self.sectorBasicOutlineLayerId,
            source: Self.sectorSourceId
        )

        layer.lineColor = .constant(StyleColor(UIColor(red: 1.0, green: 0.71, blue: 0.0, alpha: 1.0)))
        layer.lineWidth = .constant(2.0)
        layer.lineDasharray = .constant([4, 3])
        layer.lineOpacity = .expression(Self.basicOutlineOpacityExpression())

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

        // Below zoom 7: short callsign only, unless selected — then full label.
        // At zoom 7+: full callsign + frequency always shown.
        // Basic-data-only sectors always append "Basic Data Only" whenever frequency is shown.
        layer.textField = .expression(
            Exp(.step) {
                Exp(.zoom)
                // zoom < 7: short callsign, or full label if selected
                Exp(.switchCase) {
                    Exp(.eq) { Exp(.get) { "isSelected" }; true }
                    // selected: show callsign + frequency + "Basic Data Only" if applicable
                    Exp(.switchCase) {
                        Exp(.eq) { Exp(.get) { "isBasicDataOnly" }; true }
                        Exp(.concat) {
                            Exp(.get) { "controllerCallsign" }
                            "\n"
                            Exp(.get) { "controllerFrequency" }
                            "\nBasic Data Only"
                        }
                        Exp(.concat) {
                            Exp(.get) { "controllerCallsign" }
                            "\n"
                            Exp(.get) { "controllerFrequency" }
                        }
                    }
                    Exp(.get) { "controllerShortCallsign" }
                }
                7
                // zoom >= 7: callsign + frequency, plus "Basic Data Only" for nodata sectors
                Exp(.switchCase) {
                    Exp(.eq) { Exp(.get) { "isBasicDataOnly" }; true }
                    Exp(.concat) {
                        Exp(.get) { "controllerCallsign" }
                        "\n"
                        Exp(.get) { "controllerFrequency" }
                        "\nBasic Data Only"
                    }
                    Exp(.concat) {
                        Exp(.get) { "controllerCallsign" }
                        "\n"
                        Exp(.get) { "controllerFrequency" }
                    }
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

    // Amber colour used for basic-data-only (nodata.json) active sectors.
    private static let basicDataAmber = Exp(.rgba) { 255; 180; 0; 1.0 }

    // Fill color: use the raw VATGlasses hex (full opacity) for active sectors in both
    // themes. Transparency is controlled separately via fillOpacity, not the color alpha,
    // so we get the actual sector colour without it being baked opaque.
    // Basic-data-only active sectors use a muted amber fill.
    private func sectorFillColorExpression() -> Exp {
        return Exp(.switchCase) {
            Exp(.eq) { Exp(.get) { "isSelected" }; true }
            Exp(.rgba) { 255; 59; 48; 1.0 }
            // Basic-data-only active: amber
            Exp(.all) {
                Exp(.eq) { Exp(.get) { "isActive" }; true }
                Exp(.eq) { Exp(.get) { "isBasicDataOnly" }; true }
            }
            Self.basicDataAmber
            Exp(.eq) { Exp(.get) { "isActive" }; true }
            Exp(.switchCase) {
                Exp(.has) { "colorHex" }
                Exp(.toColor) { Exp(.get) { "colorHex" } }
                Exp(.rgba) { 30; 144; 255; 1.0 }
            }
            Exp(.rgba) { 128; 128; 128; 1.0 }
        }
    }

    // Fill opacity: keep fills very translucent so the map underneath shows through.
    // Light mode uses slightly lower opacity since the white background makes colors
    // appear more vivid than on the dark map.
    // Basic-data-only sectors are slightly more transparent to distinguish them.
    private func sectorFillOpacityExpression() -> Exp {
        return Exp(.switchCase) {
            Exp(.eq) { Exp(.get) { "isSelected" }; true }
            isDarkTheme ? 0.12 : 0.08
            Exp(.all) {
                Exp(.eq) { Exp(.get) { "isActive" }; true }
                Exp(.eq) { Exp(.get) { "isBasicDataOnly" }; true }
            }
            isDarkTheme ? 0.07 : 0.05
            Exp(.eq) { Exp(.get) { "isActive" }; true }
            isDarkTheme ? 0.10 : 0.07
            isDarkTheme ? 0.03 : 0.02
        }
    }

    // Outline color: VATGlasses hex at full opacity for the stroke in both themes.
    // The solid outline layer is hidden for basic-data-only sectors (the dashed layer handles them).
    private func sectorOutlineColorExpression() -> Exp {
        return Exp(.switchCase) {
            Exp(.eq) { Exp(.get) { "isSelected" }; true }
            Exp(.rgba) { 255; 59; 48; 1.0 }
            Exp(.eq) { Exp(.get) { "isActive" }; true }
            Exp(.switchCase) {
                Exp(.has) { "colorHex" }
                Exp(.toColor) { Exp(.get) { "colorHex" } }
                Exp(.rgba) { 30; 144; 255; 1.0 }
            }
            Exp(.rgba) { 128; 128; 128; 1.0 }
        }
    }

    // Outline opacity: inactive sectors are subtler in both themes.
    // Basic-data-only active sectors use opacity 0 here — their dashed layer renders the border.
    private func sectorOutlineOpacityExpression() -> Exp {
        return Exp(.switchCase) {
            Exp(.eq) { Exp(.get) { "isSelected" }; true }
            1.0
            Exp(.all) {
                Exp(.eq) { Exp(.get) { "isActive" }; true }
                Exp(.eq) { Exp(.get) { "isBasicDataOnly" }; true }
            }
            0.0
            Exp(.eq) { Exp(.get) { "isActive" }; true }
            isDarkTheme ? 0.85 : 0.70
            isDarkTheme ? 0.40 : 0.25
        }
    }

    // Dashed outline opacity for the basic-data-only layer.
    // Only visible for active basic-data-only sectors.
    private static func basicOutlineOpacityExpression() -> Exp {
        return Exp(.switchCase) {
            Exp(.all) {
                Exp(.eq) { Exp(.get) { "isActive" }; true }
                Exp(.eq) { Exp(.get) { "isBasicDataOnly" }; true }
            }
            0.85
            0.0
        }
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
