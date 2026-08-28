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
    /// Separate symbol layer that shows a small dot/square at low zoom instead of the full label.
    static let sectorDotLayerId = "sector-dot-layer"

    /// Image IDs for the four pill/dot states — default, selected (red), friend (green), self (gold).
    /// Non-SDF so the drawn fill and stroke colours render as-is (SDF causes
    /// icon-text-fit-padding mis-sizing — known Mapbox bug).
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

    /// Generates a 9-patch (stretchable) rounded-rectangle image suitable for use as
    /// an `icon-text-fit` background behind symbol text.
    ///
    /// **Why non-SDF?**
    /// Mapbox's `icon-text-fit` resizes the icon sprite to match the text bounding box.
    /// When `template: true` (SDF) is used the SDK applies an additional tint pass that
    /// interacts badly with `icon-text-fit-padding`, producing mis-sized backgrounds.
    /// A non-SDF (rasterised) image renders the stroke and fill exactly as drawn.
    ///
    /// **Why `resizableImage(withCapInsets:)`?**
    /// Mapbox treats images added with `style.addImage(_:stretchX:stretchY:)` (or their
    /// `content` variant) as 9-patch sprites: only the stretch regions scale; the corner
    /// cap areas stay at their drawn size. We produce a minimal canvas (cornerRadius * 2
    /// wide/tall) so the corners occupy the whole non-stretch region and the single
    /// central pixel is the only stretch zone, keeping corners perfectly crisp on Retina.
    ///
    /// - Parameters:
    ///   - fillColor: Fill colour of the pill.
    ///   - strokeColor: Stroke/outline colour.
    ///   - cornerRadius: Corner radius in points (default 6).
    /// - Returns: A `UIImage` marked as resizable with cap insets matching the corner radius.
    private static func makePillBackgroundImage(
        fillColor: UIColor,
        strokeColor: UIColor,
        cornerRadius: CGFloat = 6
    ) -> UIImage {
        // Canvas must be at least (2 × cornerRadius + 1) so there is exactly one
        // stretchable centre pixel. The stroke is rendered at 1 logical point = 1×
        // on non-Retina, 2px on @2x, etc., so we work in logical points and let
        // UIGraphicsImageRenderer handle the scale factor.
        let side = cornerRadius * 2 + 1
        let size = CGSize(width: side, height: side)
        let strokeWidth: CGFloat = 1.0

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let cgCtx = ctx.cgContext
            let inset = strokeWidth / 2.0
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius - inset)

            // Fill
            cgCtx.setFillColor(fillColor.cgColor)
            cgCtx.addPath(path.cgPath)
            cgCtx.fillPath()

            // Stroke — rendered at 1pt regardless of screen scale because
            // UIGraphicsImageRenderer already applies the display scale factor.
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
    // Each state has a fill and a stroke. Stroke is always a darker shade of the fill
    // so the 1pt outline reads crisply against both light and dark basemaps.

    // Default — dark mode: dark navy; light mode: near-white with navy tint
    private static let darkDefaultFill   = UIColor(red: 0.05, green: 0.15, blue: 0.40, alpha: 0.92)
    private static let darkDefaultStroke = UIColor.black
    private static let lightDefaultFill   = UIColor(red: 0.93, green: 0.95, blue: 1.00, alpha: 0.95)
    private static let lightDefaultStroke = UIColor(red: 0.20, green: 0.25, blue: 0.40, alpha: 1.00)

    // Selected — red. Dark mode: vivid red; light mode: slightly deeper red for contrast.
    private static let darkSelectedFill   = UIColor(red: 0.82, green: 0.10, blue: 0.08, alpha: 0.95)
    private static let darkSelectedStroke = UIColor(red: 0.50, green: 0.00, blue: 0.00, alpha: 1.00)
    private static let lightSelectedFill   = UIColor(red: 0.90, green: 0.15, blue: 0.12, alpha: 0.95)
    private static let lightSelectedStroke = UIColor(red: 0.55, green: 0.02, blue: 0.02, alpha: 1.00)

    // Friend — green. Dark mode: vivid lime-green; light mode: forest green.
    private static let darkFriendFill   = UIColor(red: 0.07, green: 0.58, blue: 0.22, alpha: 0.95)
    private static let darkFriendStroke = UIColor(red: 0.00, green: 0.30, blue: 0.08, alpha: 1.00)
    private static let lightFriendFill   = UIColor(red: 0.10, green: 0.55, blue: 0.20, alpha: 0.95)
    private static let lightFriendStroke = UIColor(red: 0.02, green: 0.28, blue: 0.08, alpha: 1.00)

    // Self (user's own CID) — gold. Dark mode: vivid gold; light mode: deeper amber-gold.
    private static let darkSelfFill   = UIColor(red: 0.90, green: 0.72, blue: 0.00, alpha: 0.95)
    private static let darkSelfStroke = UIColor(red: 0.55, green: 0.40, blue: 0.00, alpha: 1.00)
    private static let lightSelfFill   = UIColor(red: 0.78, green: 0.58, blue: 0.00, alpha: 0.95)
    private static let lightSelfStroke = UIColor(red: 0.48, green: 0.32, blue: 0.00, alpha: 1.00)

    // Text: always white on dark fills; dark-navy on the light default pill only.
    // Selected, friend, and self fills are dark enough in both themes that white text works.

    /// Generates a small fixed-size rounded-square used as the zoomed-out dot indicator.
    /// Uses the same fill/stroke palette as the pill so it matches the current theme.
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

    /// Registers all pill and dot image variants with the Mapbox style.
    ///
    /// Six pill images and six dot images are registered — one per state (default, selected,
    /// friend) per theme (dark, light). Because the images are non-SDF (rasterised), their
    /// colours are baked in at registration time. We register the full set regardless of the
    /// current theme so the `switchCase` expression on `iconImage` can always pick the correct
    /// variant at render time.
    ///
    /// Called after every style load (images don't survive style reloads) and from `applyTheme`
    /// when the theme changes. `sdf: false` is critical — see `makePillBackgroundImage`.
    private func registerImages(on mapView: MapView) {
        // Build a flat list of (imageId, fillColor, strokeColor) tuples for pills and dots.
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

            // Defensive remove before add to avoid "image already exists" on hot-reload.
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
        // The pill and dot are rasterised non-SDF images — their fill/stroke colours are baked in.
        // Re-register them with the new theme colours so subsequent renders use the right palette.
        registerImages(on: mapView)

        // Update the textColor expression to reflect the new theme. The expression picks
        // white or dark-navy depending on both the theme and the feature's state.
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

    /// Shows a small square indicator at each sector label position.
    ///
    /// The dot is always drawn (allow-overlap, ignore-placement) so it acts as the guaranteed
    /// fallback whenever a label is either:
    ///   a) hidden by the zoom threshold (below zoom 5), or
    ///   b) suppressed by the collision engine because another sector label won the space.
    ///
    /// The dot is always visible at every zoom level. When the label is shown (zoom ≥ 5 and
    /// no collision) the dot sits behind the pill and is completely covered by it. When the
    /// label is hidden — either because zoom < 5 or because a collision suppressed it — the
    /// dot remains visible as a fallback indicator.
    private func addSectorDotLayer(to mapView: MapView) throws {
        var layer = SymbolLayer(
            id: Self.sectorDotLayerId,
            source: Self.sectorLabelSourceId
        )

        // Pick the dot variant that matches the feature's state.
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

        // Always draw at full opacity — never hidden by zoom or the collision engine.
        layer.iconAllowOverlap = .constant(true)
        layer.iconIgnorePlacement = .constant(true)
        layer.iconOpacity = .constant(1.0)

        layer.symbolPlacement = .constant(.point)
        layer.symbolZOrder = .constant(.auto)

        try mapView.mapboxMap.addLayer(layer)
    }

    // MARK: - Label Layer

    /// The label layer reads from the dedicated label-point source, not the polygon source.
    ///
    /// **Pill background technique:**
    /// Mapbox has no native `text-background-color` property. Instead we use a stretchable
    /// sprite registered as `sector-label-pill` (non-SDF) combined with `icon-text-fit: both`
    /// so the icon image automatically resizes to the text bounding box.
    ///
    /// **Layer ordering within the symbol:**
    /// The icon is drawn before (behind) the text by default in a SymbolLayer — no extra layer
    /// is needed. `icon-allow-overlap` and `text-allow-overlap` are both set to `true` so the
    /// badge never collides with other features and disappears.
    ///
    /// **Known Mapbox gotchas addressed here:**
    /// - `sdf: false` on the registered image — SDF tint pass interferes with `icon-text-fit-padding`.
    /// - `iconAllowOverlap` must be `true` whenever `textAllowOverlap` is, otherwise the icon
    ///   gets hidden independently by the collision engine.
    /// - The pill image is re-registered on every style load in `configureSectors` because custom
    ///   images do not survive a style URI change.
    ///
    /// Below zoom 7: shows only the short callsign (e.g. "LRBB_S").
    /// At zoom 7+, or when selected: shows full callsign + frequency on two lines.
    private func addSectorLabelLayer(to mapView: MapView) throws {
        var layer = SymbolLayer(
            id: Self.sectorLabelLayerId,
            source: Self.sectorLabelSourceId
        )

        // --- Text field ---
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

        // --- Text styling ---
        // Default dark: white on dark-navy pill.
        // Default light: dark-navy on near-white pill (lightDefaultStroke colour).
        // Selected/friend: both fills are dark enough that white text works in both themes.
        // No halo in either mode — the pill background provides contrast instead.
        layer.textSize = .constant(12)
        layer.textFont = .constant(["Arial Unicode MS Regular"])
        layer.textColor = .expression(Self.textColorExpression(isDark: isDarkTheme))
        layer.textHaloWidth = .constant(0)
        layer.textLineHeight = .constant(1.2)

        // --- Pill (icon) background ---
        // Pick the pill variant that matches the feature's state.
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

        // `iconTextFit: .both` makes the icon stretch to exactly cover the text bounding box.
        layer.iconTextFit = .constant(.both)

        // Padding (pt) added around the text box before the pill is sized.
        // Values are [top, right, bottom, left] — same as CSS.
        layer.iconTextFitPadding = .constant([4, 8, 4, 8])

        // Collision behaviour:
        // - textAllowOverlap: false  → sector labels compete against each other; the one
        //   placed first wins, the loser is hidden (its dot remains visible instead).
        // - textIgnorePlacement: false → sector labels DO block other features from rendering
        //   inside their bounding box (normal collision participation).
        // - iconAllowOverlap / iconIgnorePlacement both false → the pill icon participates in
        //   the same collision as the text, so they are hidden/shown together.
        // - iconOptional: false, textOptional: false → if one is hidden, both are hidden, so
        //   the pill background never floats without its text or vice versa.
        //
        // Crucially, textIgnorePlacement is NOT set to true here, so only features in the
        // same layer (other sector labels) can cause a collision. Pilots and airport labels
        // are on separate layers and will NOT displace sector labels because those other layers
        // use their own allow-overlap/ignore-placement settings.
        layer.iconAllowOverlap = .constant(false)
        layer.iconIgnorePlacement = .constant(false)
        layer.textAllowOverlap = .constant(false)
        layer.textIgnorePlacement = .constant(false)
        layer.iconOptional = .constant(false)
        layer.textOptional = .constant(false)

        // Hidden below zoom 5 (matches airport label appearance threshold).
        // The dot layer covers zoom < 5; labels cover zoom ≥ 5.
        let labelFade = Exp(.step) {
            Exp(.zoom)
            0.0   // < zoom 5: hidden (dot is shown instead)
            5
            1.0   // ≥ zoom 5: fully visible
        }
        layer.textOpacity = .expression(labelFade)
        layer.iconOpacity = .expression(labelFade)

        layer.symbolPlacement = .constant(.point)
        layer.symbolZOrder = .constant(.auto)

        try mapView.mapboxMap.addLayer(layer)
    }

    // MARK: - Theme Color Helpers

    /// Returns a `switchCase` expression that picks the correct text colour for each label state.
    ///
    /// Rules:
    ///   - Default, dark theme  → white  (legible on dark-navy pill)
    ///   - Default, light theme → dark-navy  (legible on near-white pill)
    ///   - Selected (red pill)  → white in both themes (red is dark enough)
    ///   - Friend (green pill)  → white in both themes (green is dark enough)
    ///   - Self (gold pill)     → white in both themes (gold is dark enough)
    private static func textColorExpression(isDark: Bool) -> Exp {
        // In light mode the default pill is near-white, so default text must be dark-navy.
        // Selected, friend, and self pills are dark enough that white works in both themes.
        let defaultTextColor = isDark ? "#FFFFFF" : StyleColor(lightDefaultStroke).rawValue
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

}
