//
//  SectorStyleManager.swift
//  VatSight
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
    static let sectorDotLayerId = "sector-dot-layer"

    // Non-SDF images — SDF causes icon-text-fit-padding mis-sizing (known Mapbox bug).
    private static let pillImageId         = "sector-label-pill"
    private static let pillSelectedImageId = "sector-label-pill-selected"
    private static let pillFriendImageId   = "sector-label-pill-friend"
    private static let pillSelfImageId     = "sector-label-pill-self"
    private static let dotImageId          = "sector-label-dot"
    private static let dotSelectedImageId  = "sector-label-dot-selected"
    private static let dotFriendImageId    = "sector-label-dot-friend"
    private static let dotSelfImageId      = "sector-label-dot-self"

    private var isDarkTheme: Bool = true

    enum SectorStyleError: Error {
        case layerAlreadyExists
    }

    // MARK: - Pill Background Image

    /// Stretchable rounded-rectangle for use as an `icon-text-fit` background.
    /// Non-SDF (rasterised) — SDF tint pass interferes with icon-text-fit-padding.
    /// Canvas is (cornerRadius*2 + 1) so only the single centre pixel stretches.
    private static func makePillBackgroundImage(
        fillColor: UIColor,
        strokeColor: UIColor,
        cornerRadius: CGFloat = 6
    ) -> UIImage {
        let side = cornerRadius * 2 + 1
        let size = CGSize(width: side, height: side)
        let strokeWidth: CGFloat = 1.0

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let cgCtx = ctx.cgContext
            let inset = strokeWidth / 2.0
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius - inset)

            cgCtx.setFillColor(fillColor.cgColor)
            cgCtx.addPath(path.cgPath)
            cgCtx.fillPath()

            cgCtx.setStrokeColor(strokeColor.cgColor)
            cgCtx.setLineWidth(strokeWidth)
            cgCtx.addPath(path.cgPath)
            cgCtx.strokePath()
        }

        // Cap insets = corner radius in all directions; only the 1-pt centre pixel stretches.
        let capInsets = UIEdgeInsets(
            top: cornerRadius,
            left: cornerRadius,
            bottom: cornerRadius,
            right: cornerRadius
        )
        return image.resizableImage(withCapInsets: capInsets, resizingMode: .stretch)
    }

    // MARK: - Theme palettes

    // navy
    private static let darkDefaultFill   = UIColor(red: 0.05, green: 0.15, blue: 0.40, alpha: 0.92)
    private static let darkDefaultStroke = UIColor.black
    private static let lightDefaultFill   = UIColor(red: 0.20, green: 0.25, blue: 0.40, alpha: 0.95)
    private static let lightDefaultStroke = UIColor(red: 0.93, green: 0.95, blue: 1.00, alpha: 1.00)

    // red
    private static let darkSelectedFill   = UIColor(red: 0.82, green: 0.10, blue: 0.08, alpha: 0.95)
    private static let darkSelectedStroke = UIColor(red: 0.50, green: 0.00, blue: 0.00, alpha: 1.00)
    private static let lightSelectedFill   = UIColor(red: 0.90, green: 0.15, blue: 0.12, alpha: 0.95)
    private static let lightSelectedStroke = UIColor(red: 0.55, green: 0.02, blue: 0.02, alpha: 1.00)

    // green
    private static let darkFriendFill   = UIColor(red: 0.07, green: 0.58, blue: 0.22, alpha: 0.95)
    private static let darkFriendStroke = UIColor(red: 0.00, green: 0.30, blue: 0.08, alpha: 1.00)
    private static let lightFriendFill   = UIColor(red: 0.10, green: 0.55, blue: 0.20, alpha: 0.95)
    private static let lightFriendStroke = UIColor(red: 0.02, green: 0.28, blue: 0.08, alpha: 1.00)

    // gold
    private static let darkSelfFill   = UIColor(red: 0.90, green: 0.72, blue: 0.00, alpha: 0.95)
    private static let darkSelfStroke = UIColor(red: 0.55, green: 0.40, blue: 0.00, alpha: 1.00)
    private static let lightSelfFill   = UIColor(red: 0.78, green: 0.58, blue: 0.00, alpha: 0.95)
    private static let lightSelfStroke = UIColor(red: 0.48, green: 0.32, blue: 0.00, alpha: 1.00)

    private static func makeDotImage(fillColor: UIColor, strokeColor: UIColor) -> UIImage {
        let size = CGSize(width: 10, height: 10)
        let cornerRadius: CGFloat = 3
        let strokeWidth: CGFloat = 1.0
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cgCtx = ctx.cgContext
            let inset = strokeWidth / 2.0
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius - inset)
            cgCtx.setFillColor(fillColor.cgColor)
            cgCtx.addPath(path.cgPath)
            cgCtx.fillPath()
            cgCtx.setStrokeColor(strokeColor.cgColor)
            cgCtx.setLineWidth(strokeWidth)
            cgCtx.addPath(path.cgPath)
            cgCtx.strokePath()
        }
    }

    /// Registers all pill and dot variants (all states, both themes). Called on style load and theme change.
    private func registerImages(on mapView: MapView) {
        let variants: [(pillId: String, dotId: String, fill: UIColor, stroke: UIColor)] = [
            (Self.pillImageId,         Self.dotImageId,
             isDarkTheme ? Self.darkDefaultFill   : Self.lightDefaultFill,
             isDarkTheme ? Self.darkDefaultStroke : Self.lightDefaultStroke),
            (Self.pillSelectedImageId, Self.dotSelectedImageId,
             isDarkTheme ? Self.darkSelectedFill   : Self.lightSelectedFill,
             isDarkTheme ? Self.darkSelectedStroke : Self.lightSelectedStroke),
            (Self.pillFriendImageId,   Self.dotFriendImageId,
             isDarkTheme ? Self.darkFriendFill   : Self.lightFriendFill,
             isDarkTheme ? Self.darkFriendStroke : Self.lightFriendStroke),
            (Self.pillSelfImageId,     Self.dotSelfImageId,
             isDarkTheme ? Self.darkSelfFill   : Self.lightSelfFill,
             isDarkTheme ? Self.darkSelfStroke : Self.lightSelfStroke),
        ]

        for v in variants {
            let pill = Self.makePillBackgroundImage(fillColor: v.fill, strokeColor: v.stroke)
            let dot  = Self.makeDotImage(fillColor: v.fill, strokeColor: v.stroke)

            try? mapView.mapboxMap.removeImage(withId: v.pillId)
            try? mapView.mapboxMap.addImage(pill, id: v.pillId, sdf: false)

            try? mapView.mapboxMap.removeImage(withId: v.dotId)
            try? mapView.mapboxMap.addImage(dot, id: v.dotId, sdf: false)
        }
    }

    // MARK: - Configure
    
    func configureSectors(on mapView: MapView, isDark: Bool = true) throws {
        isDarkTheme = isDark
        registerImages(on: mapView)
        try addSectorSource(to: mapView)
        try addSectorFillLayer(to: mapView)
        try addSectorOutlineLayer(to: mapView)
        try addSectorBasicOutlineLayer(to: mapView)
        try addSectorLabelSource(to: mapView)
        try addSectorDotLayer(to: mapView)
        try addSectorLabelLayer(to: mapView)
    }

    /// Re-tints sector layers in place when the app theme changes.
    func applyTheme(on mapView: MapView, isDark: Bool) {
        isDarkTheme = isDark

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
        // Re-register images with new theme colours (baked into non-SDF rasters).
        registerImages(on: mapView)

        try? mapView.mapboxMap.updateLayer(withId: Self.sectorLabelLayerId, type: SymbolLayer.self) { [self] layer in
            layer.textColor = .expression(Self.textColorExpression(isDark: isDarkTheme))
        }
    }
    
    // MARK: - Update Source
    
    func updateSectors(
        on mapView: MapView,
        sectors: [VatglassesSector],
        controllers: [Controllers],
        airports: [VatglassesAirport] = [],
        selectedControllerCID: Int? = nil,
        friendCIDs: Set<Int> = [],
        myCID: Int = 0
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
            friendCIDs: friendCIDs,
            myCID: myCID
        )
        mapView.mapboxMap.updateGeoJSONSource(
            withId: Self.sectorLabelSourceId,
            geoJSON: .featureCollection(labelCollection)
        )
    }
    
    // MARK: - Ensure Layer Order

    /// Layer ordering is now managed centrally by `ensureLabelsOnTop()` in the Coordinator.
    /// This stub is kept so existing call-sites compile without changes.
    func ensureSectorLabelIsOnTop(on mapView: MapView) {}
    
    // MARK: - Remove Layers
    
    func removeSectorLayers(from mapView: MapView) {
        try? mapView.mapboxMap.removeLayer(withId: Self.sectorLabelLayerId)
        try? mapView.mapboxMap.removeLayer(withId: Self.sectorDotLayerId)
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

    // MARK: - Dot Indicator Layer

    /// Always-visible dot behind the pill; fallback indicator when label is hidden (zoom < 5 or collision).
    private func addSectorDotLayer(to mapView: MapView) throws {
        var layer = SymbolLayer(
            id: Self.sectorDotLayerId,
            source: Self.sectorLabelSourceId
        )

        // Priority: isSelf (gold) > isSelected (red) > isFriend (green) > default.
        layer.iconImage = .expression(
            Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isSelf" }; true }
                Self.dotSelfImageId
                Exp(.eq) { Exp(.get) { "isSelected" }; true }
                Self.dotSelectedImageId
                Exp(.eq) { Exp(.get) { "isFriend" }; true }
                Self.dotFriendImageId
                Self.dotImageId
            }
        )

        layer.iconAllowOverlap = .constant(true)
        layer.iconIgnorePlacement = .constant(true)
        layer.iconOpacity = .constant(1.0)

        layer.symbolPlacement = .constant(.point)
        layer.symbolZOrder = .constant(.auto)

        try mapView.mapboxMap.addLayer(layer)
    }

    // MARK: - Label Layer

    /// Pill-background label layer using a stretchable non-SDF sprite + `icon-text-fit: both`.
    /// Below zoom 7: short callsign only (full label when selected). At zoom 7+: callsign + frequency.
    private func addSectorLabelLayer(to mapView: MapView) throws {
        var layer = SymbolLayer(
            id: Self.sectorLabelLayerId,
            source: Self.sectorLabelSourceId
        )

        layer.textField = .expression(
            Exp(.step) {
                Exp(.zoom)
                Exp(.switchCase) {
                    Exp(.eq) { Exp(.get) { "isSelected" }; true }
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
        layer.textColor = .expression(Self.textColorExpression(isDark: isDarkTheme))
        layer.textHaloWidth = .constant(0)
        layer.textLineHeight = .constant(1.2)

        // Priority: isSelf (gold) > isSelected (red) > isFriend (green) > default.
        layer.iconImage = .expression(
            Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isSelf" }; true }
                Self.pillSelfImageId
                Exp(.eq) { Exp(.get) { "isSelected" }; true }
                Self.pillSelectedImageId
                Exp(.eq) { Exp(.get) { "isFriend" }; true }
                Self.pillFriendImageId
                Self.pillImageId
            }
        )

        layer.iconTextFit = .constant(.both)

        layer.iconTextFitPadding = .constant([4, 8, 4, 8])

        // Sector labels compete only with each other. textIgnorePlacement: false ensures they
        // block other same-layer features but do NOT displace pilots/airport labels on other layers.
        // iconOptional/textOptional both false keeps pill and text hidden/shown together.
        layer.iconAllowOverlap = .constant(false)
        layer.iconIgnorePlacement = .constant(false)
        layer.textAllowOverlap = .constant(false)
        layer.textIgnorePlacement = .constant(false)
        layer.iconOptional = .constant(false)
        layer.textOptional = .constant(false)

        // Hidden below zoom 5; dot layer covers that range.
        let labelFade = Exp(.step) {
            Exp(.zoom)
            0.0
            5
            1.0
        }
        layer.textOpacity = .expression(labelFade)
        layer.iconOpacity = .expression(labelFade)

        layer.symbolPlacement = .constant(.point)
        layer.symbolZOrder = .constant(.auto)

        try mapView.mapboxMap.addLayer(layer)
    }

    // MARK: - Theme Color Helpers

    /// White text on all states; light-mode default uses navy (near-white pill needs contrast).
    private static func textColorExpression(isDark: Bool) -> Exp {
        let defaultTextColor = "#FFFFFF"
        return Exp(.switchCase) {
            Exp(.eq) { Exp(.get) { "isSelf" }; true }
            "#FFFFFF"
            Exp(.eq) { Exp(.get) { "isSelected" }; true }
            "#FFFFFF"
            Exp(.eq) { Exp(.get) { "isFriend" }; true }
            "#FFFFFF"
            defaultTextColor
        }
    }

    private static let basicDataAmber = Exp(.rgba) { 255; 180; 0; 1.0 } // amber

    // Transparency is controlled via fillOpacity, not colour alpha, to preserve the VATGlasses hex.
    private func sectorFillColorExpression() -> Exp {
        return Exp(.switchCase) {
            Exp(.eq) { Exp(.get) { "isSelected" }; true }
            Exp(.rgba) { 255; 59; 48; 1.0 }
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

}
