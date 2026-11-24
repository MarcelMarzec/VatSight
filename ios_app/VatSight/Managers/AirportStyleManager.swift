//
//  AirportStyleManager.swift
//  VatSight
//

import Foundation
import UIKit
import MapboxMaps

final class AirportStyleManager {
    static let airportSourceId = "airports-source"
    static let airportLayerId = "airport-layer"
    static let airportLabelLayerId = "airport-label-layer"
    /// Soft glow drawn under airports with an event happening now.
    static let airportHaloLayerId = "airport-halo-layer"
    /// Thin outer ring around airports with an event happening now.
    static let airportEventRingLayerId = "airport-event-ring-layer"
    private static let indicatorImagePrefix = "indicator-"

    // Event / booking highlight colours (dark theme, light theme).
    private static let eventRGB: (dark: (Double, Double, Double), light: (Double, Double, Double)) = ((191, 90, 242), (150, 60, 200))
    private static let bookingRGB: (dark: (Double, Double, Double), light: (Double, Double, Double)) = ((100, 210, 255), (0, 140, 190))

    /// Badge drawn at the front of the indicator row for each highlight.
    private static let highlightBadges: [(code: String, symbol: String, color: UIColor)] = [
        ("E", "star.fill", UIColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 1)),
        ("U", "calendar", UIColor(red: 0.55, green: 0.30, blue: 0.72, alpha: 1)),
        ("B", "headphones", UIColor(red: 0.00, green: 0.55, blue: 0.75, alpha: 1))
    ]

    private static func badgeCode(for highlight: AirportHighlight?) -> String {
        switch highlight {
        case .activeEvent: return "E"
        case .upcomingEvent: return "U"
        case .upcomingBooking: return "B"
        case nil: return ""
        }
    }

    /// Image name for an airport's badge row, or nil when it has nothing to show.
    /// `letters` is the space-separated ground service string, e.g. "T G".
    static func indicatorImageKey(highlight: AirportHighlight?, letters: String) -> String? {
        let badge = badgeCode(for: highlight)
        guard !badge.isEmpty || !letters.isEmpty else { return nil }
        return indicatorImagePrefix + badge + "|" + letters
    }

    private static let letterColors: [String: UIColor] = [
        "T": UIColor(red: 0.20, green: 0.60, blue: 1.00, alpha: 1), // blue — Tower
        "G": UIColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1), // green — Ground
        "D": UIColor(red: 1.00, green: 0.58, blue: 0.00, alpha: 1), // orange — Delivery
        "A": UIColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 1)  // purple — ATIS
    ]

    enum AirportStyleError: Error {
        case layerAlreadyExists
    }

    private var isDarkTheme: Bool = true
    /// 0 = nothing faded, 1 = airports marked `isDimmed` fully faded. Animated by the map coordinator.
    private var dimProgress: Double = 0

    // MARK: - Configure

    func configureAirports(on mapView: MapView, isDark: Bool = true, airportIconMultiplier: Double = 1.0) throws {
        isDarkTheme = isDark
        registerIndicatorImages(on: mapView)
        try addAirportSource(to: mapView)
        try addAirportHaloLayer(to: mapView, airportIconMultiplier: airportIconMultiplier)
        try addAirportEventRingLayer(to: mapView, airportIconMultiplier: airportIconMultiplier)
        try addAirportLayer(to: mapView, airportIconMultiplier: airportIconMultiplier)
        try addAirportLabelLayer(to: mapView)
    }

    /// Updates airport layer colours without a full style reload.
    func applyTheme(on mapView: MapView, isDark: Bool) {
        isDarkTheme = isDark
        let halo: StyleColor = isDark ? StyleColor(.black) : StyleColor(.white)
        try? mapView.mapboxMap.updateLayer(withId: Self.airportLayerId, type: CircleLayer.self) { layer in
            layer.circleColor = .expression(airportFillColorExpression())
            layer.circleStrokeColor = .expression(airportStrokeColorExpression())
        }
        try? mapView.mapboxMap.updateLayer(withId: Self.airportHaloLayerId, type: CircleLayer.self) { layer in
            layer.circleColor = .expression(Self.rgba(isDark ? Self.eventRGB.dark : Self.eventRGB.light))
        }
        try? mapView.mapboxMap.updateLayer(withId: Self.airportEventRingLayerId, type: CircleLayer.self) { layer in
            layer.circleStrokeColor = .expression(Self.rgba(isDark ? Self.eventRGB.dark : Self.eventRGB.light))
        }
        try? mapView.mapboxMap.updateLayer(withId: Self.airportLabelLayerId, type: SymbolLayer.self) { layer in
            layer.textColor = .expression(airportLabelColorExpression())
            layer.textHaloColor = .constant(halo)
        }
    }

    /// Updates the airport circle radius without a full style reload.
    func applyAirportIconSize(on mapView: MapView, multiplier: Double) {
        try? mapView.mapboxMap.updateLayer(withId: Self.airportLayerId, type: CircleLayer.self) { layer in
            layer.circleRadius = .expression(Self.radiusExpression(multiplier: multiplier))
        }
        try? mapView.mapboxMap.updateLayer(withId: Self.airportHaloLayerId, type: CircleLayer.self) { layer in
            layer.circleRadius = .expression(Self.zoomScaled(Self.haloRadius * multiplier))
        }
        try? mapView.mapboxMap.updateLayer(withId: Self.airportEventRingLayerId, type: CircleLayer.self) { layer in
            layer.circleRadius = .expression(Self.zoomScaled(Self.ringRadius * multiplier))
        }
    }

    private static let haloRadius: Double = 15
    private static let ringRadius: Double = 8.5

    /// `normal` for most airports; for those marked `isDimmed` (no traffic to/from the selected
    /// airport) it moves towards `dimmed` as the fade progresses.
    private func dimmedOpacity(_ normal: Double, dimmed: Double) -> Exp {
        Exp(.switchCase) {
            Exp(.eq) { Exp(.get) { "isDimmed" }; true }
            normal + (dimmed - normal) * dimProgress
            normal
        }
    }

    /// Labels appear from zoom 5; live event airports from zoom 2 so they stand out early.
    /// Faded airports stay readable but recede.
    private func labelOpacityExpression() -> Exp {
        Exp(.step) {
            Exp(.zoom)
            0.0
            2
            Exp(.switchCase) {
                Self.isActiveEvent
                dimmedOpacity(1.0, dimmed: 0.0)
                0.0
            }
            5
            dimmedOpacity(1.0, dimmed: 0.15)
        }
    }

    /// Called every animation frame while the fade runs.
    func applyDimProgress(_ progress: Double, on mapView: MapView) {
        dimProgress = progress
        try? mapView.mapboxMap.updateLayer(withId: Self.airportLayerId, type: CircleLayer.self) { layer in
            layer.circleOpacity = .expression(dimmedOpacity(1.0, dimmed: 0.12))
            layer.circleStrokeOpacity = .expression(dimmedOpacity(1.0, dimmed: 0.12))
        }
        try? mapView.mapboxMap.updateLayer(withId: Self.airportHaloLayerId, type: CircleLayer.self) { layer in
            layer.circleOpacity = .expression(dimmedOpacity(0.45, dimmed: 0.04))
        }
        try? mapView.mapboxMap.updateLayer(withId: Self.airportEventRingLayerId, type: CircleLayer.self) { layer in
            layer.circleStrokeOpacity = .expression(dimmedOpacity(0.9, dimmed: 0.1))
        }
        let labelOpacity = labelOpacityExpression()
        try? mapView.mapboxMap.updateLayer(withId: Self.airportLabelLayerId, type: SymbolLayer.self) { layer in
            layer.textOpacity = .expression(labelOpacity)
            layer.iconOpacity = .expression(labelOpacity)
        }
    }

    private static var isActiveEvent: Exp {
        Exp(.eq) { Exp(.get) { "highlight" }; Double(AirportHighlight.activeEvent.rawValue) }
    }

    /// Shrinks airport markers when zoomed out so they don't clutter the world view.
    private static func zoomScaled(_ value: Exp) -> Exp {
        Exp(.interpolate) {
            Exp(.linear)
            Exp(.zoom)
            1; Exp(.product) { 0.4; value }
            3; Exp(.product) { 0.55; value }
            5; Exp(.product) { 0.8; value }
            7; value
        }
    }

    private static func zoomScaled(_ value: Double) -> Exp {
        zoomScaled(Exp(.literal) { value })
    }

    /// Highlighted airports keep at least the "filled" size so their ring is legible.
    private static func radiusExpression(multiplier: Double) -> Exp {
        zoomScaled(Exp(.switchCase) {
            isActiveEvent
            4.5 * multiplier
            Exp(.eq) { Exp(.get) { "isSelected" }; true }
            4.0 * multiplier
            Exp(.eq) { Exp(.get) { "isFriendControlled" }; true }
            3.0 * multiplier
            Exp(.eq) { Exp(.get) { "isFilled" }; true }
            3.0 * multiplier
            Exp(.gt) { Exp(.get) { "highlight" }; 0.0 }
            3.0 * multiplier
            2.0 * multiplier
        })
    }

    // MARK: - Update Source

    func updateAirports(
        on mapView: MapView,
        airports: [VatglassesAirport],
        filledICAOs: Set<String>,
        selectedICAO: String? = nil,
        friendControlledICAOs: Set<String> = [],
        highlights: [String: AirportHighlight] = [:],
        connectedICAOs: Set<String>? = nil
    ) {
        guard mapView.mapboxMap.sourceExists(withId: Self.airportSourceId) else { return }
        let collection = AirportGeoJSON.featureCollection(
            from: airports,
            filledICAOs: filledICAOs,
            selectedICAO: selectedICAO,
            friendControlledICAOs: friendControlledICAOs,
            highlights: highlights,
            connectedICAOs: connectedICAOs
        )
        mapView.mapboxMap.updateGeoJSONSource(
            withId: Self.airportSourceId,
            geoJSON: .featureCollection(collection)
        )
    }

    // MARK: - Ensure Layer Order

    /// Layer ordering is managed centrally by `ensureLabelsOnTop()` in the Coordinator.
    func ensureAirportLabelIsOnTop(on mapView: MapView) {}

    // MARK: - Remove Layers

    func removeAirportLayers(from mapView: MapView) {
        try? mapView.mapboxMap.removeLayer(withId: Self.airportLabelLayerId)
        try? mapView.mapboxMap.removeLayer(withId: Self.airportLayerId)
        try? mapView.mapboxMap.removeLayer(withId: Self.airportHaloLayerId)
        try? mapView.mapboxMap.removeLayer(withId: Self.airportEventRingLayerId)
        try? mapView.mapboxMap.removeSource(withId: Self.airportSourceId)
    }

    // MARK: - Add Source

    private func addAirportSource(to mapView: MapView) throws {
        var source = GeoJSONSource(id: Self.airportSourceId)
        source.data = .featureCollection(FeatureCollection(features: []))
        try mapView.mapboxMap.addSource(source)
    }

    // MARK: - Airport Circle Layer

    private func addAirportLayer(to mapView: MapView, airportIconMultiplier: Double = 1.0) throws {
        var layer = CircleLayer(id: Self.airportLayerId, source: Self.airportSourceId)

        layer.circleRadius = .expression(Self.radiusExpression(multiplier: airportIconMultiplier))
        layer.circleColor = .expression(airportFillColorExpression())
        layer.circleStrokeColor = .expression(airportStrokeColorExpression())
        layer.circleStrokeWidth = .expression(
            Self.zoomScaled(Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isSelected" }; true }
                1.5
                Exp(.gt) { Exp(.get) { "highlight" }; 0.0 }
                2.0
                1.5
            })
        )
        layer.circleOpacity = .expression(dimmedOpacity(1.0, dimmed: 0.12))
        layer.circleStrokeOpacity = .expression(dimmedOpacity(1.0, dimmed: 0.12))
        try mapView.mapboxMap.addLayer(layer)
    }

    // MARK: - Event Halo Layer

    private func addAirportHaloLayer(to mapView: MapView, airportIconMultiplier: Double) throws {
        var layer = CircleLayer(id: Self.airportHaloLayerId, source: Self.airportSourceId)
        layer.filter = Self.isActiveEvent
        layer.circleRadius = .expression(Self.zoomScaled(Self.haloRadius * airportIconMultiplier))
        layer.circleColor = .expression(Self.rgba(isDarkTheme ? Self.eventRGB.dark : Self.eventRGB.light))
        layer.circleOpacity = .expression(dimmedOpacity(0.45, dimmed: 0.04))
        layer.circleBlur = .constant(0.55)
        layer.circleStrokeWidth = .constant(0)
        try mapView.mapboxMap.addLayer(layer)
    }

    private func addAirportEventRingLayer(to mapView: MapView, airportIconMultiplier: Double) throws {
        var layer = CircleLayer(id: Self.airportEventRingLayerId, source: Self.airportSourceId)
        layer.filter = Self.isActiveEvent
        layer.circleRadius = .expression(Self.zoomScaled(Self.ringRadius * airportIconMultiplier))
        layer.circleColor = .constant(StyleColor(.clear))
        layer.circleStrokeColor = .expression(Self.rgba(isDarkTheme ? Self.eventRGB.dark : Self.eventRGB.light))
        layer.circleStrokeWidth = .expression(Self.zoomScaled(1.5))
        layer.circleStrokeOpacity = .expression(dimmedOpacity(0.9, dimmed: 0.1))
        try mapView.mapboxMap.addLayer(layer)
    }

    // MARK: - Airport Label + Indicator Layer
    // Text (ICAO) and icon (badge row) share one SymbolLayer so Mapbox treats them as a single symbol.

    private func addAirportLabelLayer(to mapView: MapView) throws {
        var layer = SymbolLayer(id: Self.airportLabelLayerId, source: Self.airportSourceId)

        layer.textField = .expression(Exp(.get) { "icao" })
        layer.textSize = .expression(Exp(.switchCase) { Self.isActiveEvent; 13.5; 12.0 })
        layer.textColor = .expression(airportLabelColorExpression())
        layer.textHaloColor = .constant(isDarkTheme ? StyleColor(.black) : StyleColor(.white))
        layer.textHaloWidth = .constant(1.0)
        layer.textPadding = .constant(5)
        layer.textFont = .constant(["Arial Unicode MS Regular"])
        layer.textAnchor = .constant(.left)
        layer.textOffset = .constant([0.8, 0])

        // Image key is "indicator-<badge>|T G D" etc., matching what was pre-rendered.
        layer.iconImage = .expression(
            Exp(.switchCase) {
                Exp(.has) { "indicatorKey" }
                Exp(.get) { "indicatorKey" }
                ""
            }
        )
        layer.iconAnchor = .constant(.topLeft)
        layer.iconOffset = .constant([12, 8])
        layer.iconAllowOverlap = .constant(false)
        layer.iconOptional = .constant(true)

        let zoomFade = labelOpacityExpression()
        layer.textOpacity = .expression(zoomFade)
        layer.iconOpacity = .expression(zoomFade)
        layer.textAllowOverlap = .constant(false)
        layer.textIgnorePlacement = .constant(false)
        layer.textOptional = .constant(false)
        // Lower keys are placed first: events win label collisions, faded airports lose them.
        layer.symbolSortKey = .expression(
            Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isDimmed" }; true }
                20000.0
                Self.isActiveEvent
                0.0
                Exp(.gt) { Exp(.get) { "highlight" }; 0.0 }
                5000.0
                10000.0
            }
        )
        layer.symbolZOrder = .constant(.auto)
        try mapView.mapboxMap.addLayer(layer)
    }

    // MARK: - Indicator Image Generation

    /// Pre-renders every badge + letter combination as a pill row and registers with Mapbox
    /// (4 badge states × 16 letter sets, minus the empty one: 63 small images, once per style load).
    private func registerIndicatorImages(on mapView: MapView) {
        let orderedLetters = ["T", "G", "D", "A"]
        let badges: [(code: String, symbol: String, color: UIColor)?] = [nil] + Self.highlightBadges.map { Optional($0) }
        for badge in badges {
            for mask in 0..<(1 << orderedLetters.count) {
                guard badge != nil || mask != 0 else { continue }
                var letters: [String] = []
                for (i, letter) in orderedLetters.enumerated() where (mask >> i) & 1 == 1 {
                    letters.append(letter)
                }
                let key = Self.indicatorImagePrefix + (badge?.code ?? "") + "|" + letters.joined(separator: " ")
                guard let image = makeIndicatorRowImage(for: letters, badge: badge) else { continue }
                try? mapView.mapboxMap.addImage(image, id: key, sdf: false)
            }
        }
    }

    /// Renders a horizontal row of coloured pill badges: an optional event/booking symbol, then one per letter.
    private func makeIndicatorRowImage(for letters: [String], badge: (code: String, symbol: String, color: UIColor)?) -> UIImage? {
        let font = UIFont.boldSystemFont(ofSize: 10)
        let textAttributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white]
        let hPad: CGFloat = 4, vPad: CGFloat = 2, cornerRadius: CGFloat = 3
        let strokeWidth: CGFloat = 1, gap: CGFloat = 2

        let letterHeight = ("T" as NSString).size(withAttributes: textAttributes).height + vPad * 2
        let symbolImage: UIImage? = badge.flatMap { badge in
            UIImage(systemName: badge.symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 7.5, weight: .bold))?
                .withTintColor(.white, renderingMode: .alwaysOriginal)
        }
        let badgeSize: CGSize? = symbolImage.map { image in
            CGSize(width: image.size.width + hPad * 2, height: letterHeight)
        }

        let pillSizes: [CGSize] = letters.map { letter in
            let ts = (letter as NSString).size(withAttributes: textAttributes)
            return CGSize(width: ts.width + hPad * 2, height: ts.height + vPad * 2)
        }
        let itemCount = letters.count + (badgeSize == nil ? 0 : 1)
        guard itemCount > 0 else { return nil }
        let totalWidth = pillSizes.reduce(0) { $0 + $1.width } + (badgeSize?.width ?? 0) + gap * CGFloat(itemCount - 1)
        let totalHeight = max(pillSizes.map(\.height).max() ?? 0, badgeSize?.height ?? 0)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: totalWidth, height: totalHeight), format: format)
        return renderer.image { _ in
            var xCursor: CGFloat = 0
            if let badge, let symbolImage, let badgeSize {
                let pillRect = CGRect(x: 0, y: (totalHeight - badgeSize.height) / 2, width: badgeSize.width, height: badgeSize.height)
                let pillPath = UIBezierPath(
                    roundedRect: pillRect.insetBy(dx: strokeWidth / 2, dy: strokeWidth / 2),
                    cornerRadius: cornerRadius
                )
                badge.color.setFill(); pillPath.fill()
                UIColor.black.setStroke(); pillPath.lineWidth = strokeWidth; pillPath.stroke()
                symbolImage.draw(in: CGRect(
                    x: pillRect.midX - symbolImage.size.width / 2,
                    y: pillRect.midY - symbolImage.size.height / 2,
                    width: symbolImage.size.width,
                    height: symbolImage.size.height
                ))
                xCursor += badgeSize.width + gap
            }
            for (letter, pillSize) in zip(letters, pillSizes) {
                let color = Self.letterColors[letter] ?? UIColor.systemBlue
                let pillRect = CGRect(x: xCursor, y: 0, width: pillSize.width, height: pillSize.height)
                let pillPath = UIBezierPath(
                    roundedRect: pillRect.insetBy(dx: strokeWidth / 2, dy: strokeWidth / 2),
                    cornerRadius: cornerRadius
                )
                color.setFill(); pillPath.fill()
                UIColor.black.setStroke(); pillPath.lineWidth = strokeWidth; pillPath.stroke()

                let ts = (letter as NSString).size(withAttributes: textAttributes)
                let textRect = CGRect(
                    x: xCursor + (pillSize.width - ts.width) / 2,
                    y: (pillSize.height - ts.height) / 2,
                    width: ts.width, height: ts.height
                )
                (letter as NSString).draw(in: textRect, withAttributes: textAttributes)
                xCursor += pillSize.width + gap
            }
        }
    }

    // MARK: - Theme Color Expressions

    private func airportFillColorExpression() -> Exp {
        if isDarkTheme {
            return Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isSelected" }; true }; Exp(.rgba) { 255; 59; 48; 1.0 }
                Exp(.eq) { Exp(.get) { "isFriendControlled" }; true }; Exp(.rgba) { 48; 230; 110; 1.0 } // lime-green
                Exp(.eq) { Exp(.get) { "isFilled" }; true }; Exp(.rgba) { 255; 255; 255; 1.0 }
                Exp(.rgba) { 0; 0; 0; 0.0 }
            }
        } else {
            return Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isSelected" }; true }; Exp(.rgba) { 255; 59; 48; 1.0 }
                Exp(.eq) { Exp(.get) { "isFriendControlled" }; true }; Exp(.rgba) { 20; 155; 65; 1.0 }  // forest green
                Exp(.eq) { Exp(.get) { "isFilled" }; true }; Exp(.rgba) { 51; 64; 102; 1.0 }            // navy
                Exp(.rgba) { 0; 0; 0; 0.0 }
            }
        }
    }

    /// Ring colour. Priority: selected > friend > event (now/upcoming) > booking > default.
    private func airportStrokeColorExpression() -> Exp {
        let event = Self.rgba(isDarkTheme ? Self.eventRGB.dark : Self.eventRGB.light)
        let booking = Self.rgba(isDarkTheme ? Self.bookingRGB.dark : Self.bookingRGB.light)
        if isDarkTheme {
            return Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isSelected" }; true }; Exp(.rgba) { 255; 59; 48; 1.0 }
                Exp(.eq) { Exp(.get) { "isFriendControlled" }; true }; Exp(.rgba) { 48; 230; 110; 1.0 }
                Exp(.gte) { Exp(.get) { "highlight" }; Double(AirportHighlight.upcomingEvent.rawValue) }; event
                Exp(.eq) { Exp(.get) { "highlight" }; Double(AirportHighlight.upcomingBooking.rawValue) }; booking
                Exp(.rgba) { 255; 255; 255; 1.0 }
            }
        } else {
            return Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isSelected" }; true }; Exp(.rgba) { 255; 59; 48; 1.0 }
                Exp(.eq) { Exp(.get) { "isFriendControlled" }; true }; Exp(.rgba) { 20; 155; 65; 1.0 }
                Exp(.gte) { Exp(.get) { "highlight" }; Double(AirportHighlight.upcomingEvent.rawValue) }; event
                Exp(.eq) { Exp(.get) { "highlight" }; Double(AirportHighlight.upcomingBooking.rawValue) }; booking
                Exp(.rgba) { 51; 64; 102; 1.0 }
            }
        }
    }

    private static func rgba(_ rgb: (Double, Double, Double)) -> Exp {
        Exp(.rgba) { rgb.0; rgb.1; rgb.2; 1.0 }
    }

    private func airportLabelColorExpression() -> Exp {
        if isDarkTheme {
            return Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isSelected" }; true }; Exp(.rgba) { 255; 59; 48; 1.0 }
                Exp(.eq) { Exp(.get) { "isFriendControlled" }; true }; Exp(.rgba) { 48; 230; 110; 1.0 }
                Self.isActiveEvent; Exp(.rgba) { 225; 175; 255; 1.0 }
                Exp(.rgba) { 255; 255; 255; 1.0 }
            }
        } else {
            return Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isSelected" }; true }; Exp(.rgba) { 255; 59; 48; 1.0 }
                Exp(.eq) { Exp(.get) { "isFriendControlled" }; true }; Exp(.rgba) { 20; 155; 65; 1.0 }
                Self.isActiveEvent; Exp(.rgba) { 120; 40; 170; 1.0 }
                Exp(.rgba) { 51; 64; 102; 1.0 }
            }
        }
    }

}
