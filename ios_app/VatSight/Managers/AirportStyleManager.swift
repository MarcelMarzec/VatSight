//
//  AirportStyleManager.swift
//  VatSight
//
//  Created by Marcel Marzec on 29/07/2026.
//

import Foundation
import UIKit
import MapboxMaps

final class AirportStyleManager {
    static let airportSourceId = "airports-source"
    static let airportLayerId = "airport-layer"
    static let airportLabelLayerId = "airport-label-layer"
    private static let indicatorImagePrefix = "indicator-"

    /// Colour per indicator letter, rendered into each composite row image.
    private static let letterColors: [String: UIColor] = [
        "T": UIColor(red: 0.20, green: 0.60, blue: 1.00, alpha: 1), // blue   — Tower
        "G": UIColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1), // green  — Ground
        "D": UIColor(red: 1.00, green: 0.58, blue: 0.00, alpha: 1), // orange — Delivery
        "A": UIColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 1)  // purple — ATIS
    ]

    enum AirportStyleError: Error {
        case layerAlreadyExists
    }

    private var isDarkTheme: Bool = true

    // MARK: - Configure

    func configureAirports(on mapView: MapView, isDark: Bool = true) throws {
        isDarkTheme = isDark
        registerIndicatorImages(on: mapView)
        try addAirportSource(to: mapView)
        try addAirportLayer(to: mapView)
        try addAirportLabelLayer(to: mapView)
    }

    /// Call when the app theme changes to update existing airport layers without a full reload.
    func applyTheme(on mapView: MapView, isDark: Bool) {
        isDarkTheme = isDark

        let fillColor = airportFillColorExpression()
        let strokeColor = airportStrokeColorExpression()
        let labelColor = airportLabelColorExpression()
        let halo: StyleColor = isDark ? StyleColor(.black) : StyleColor(.white)

        try? mapView.mapboxMap.updateLayer(withId: Self.airportLayerId, type: CircleLayer.self) { layer in
            layer.circleColor = .expression(fillColor)
            layer.circleStrokeColor = .expression(strokeColor)
        }
        try? mapView.mapboxMap.updateLayer(withId: Self.airportLabelLayerId, type: SymbolLayer.self) { layer in
            layer.textColor = .expression(labelColor)
            layer.textHaloColor = .constant(halo)
        }
    }

    // MARK: - Update Source

    func updateAirports(
        on mapView: MapView,
        airports: [VatglassesAirport],
        filledICAOs: Set<String>,
        selectedICAO: String? = nil,
        friendControlledICAOs: Set<String> = []
    ) {
        guard mapView.mapboxMap.sourceExists(withId: Self.airportSourceId) else { return }
        let collection = AirportGeoJSON.featureCollection(
            from: airports,
            filledICAOs: filledICAOs,
            selectedICAO: selectedICAO,
            friendControlledICAOs: friendControlledICAOs
        )
        mapView.mapboxMap.updateGeoJSONSource(
            withId: Self.airportSourceId,
            geoJSON: .featureCollection(collection)
        )
    }

    // MARK: - Ensure Layer Order

    /// Layer ordering is now managed centrally by `ensureLabelsOnTop()` in the Coordinator.
    /// This stub is kept so existing call-sites compile without changes.
    func ensureAirportLabelIsOnTop(on mapView: MapView) {}

    // MARK: - Remove Layers

    func removeAirportLayers(from mapView: MapView) {
        try? mapView.mapboxMap.removeLayer(withId: Self.airportLabelLayerId)
        try? mapView.mapboxMap.removeLayer(withId: Self.airportLayerId)
        try? mapView.mapboxMap.removeSource(withId: Self.airportSourceId)
    }

    // MARK: - Add Source

    private func addAirportSource(to mapView: MapView) throws {
        var source = GeoJSONSource(id: Self.airportSourceId)
        source.data = .featureCollection(FeatureCollection(features: []))
        try mapView.mapboxMap.addSource(source)
    }

    // MARK: - Airport Circle Layer

    private func addAirportLayer(to mapView: MapView) throws {
        var layer = CircleLayer(
            id: Self.airportLayerId,
            source: Self.airportSourceId
        )

        layer.circleRadius = .expression(
            Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isSelected" }; true }
                4.0
                Exp(.eq) { Exp(.get) { "isFriendControlled" }; true }
                3.0
                Exp(.eq) { Exp(.get) { "isFilled" }; true }
                3.0
                2.0
            }
        )

        layer.circleColor = .expression(airportFillColorExpression())
        layer.circleStrokeColor = .expression(airportStrokeColorExpression())
        layer.circleStrokeWidth = .constant(1.5)
        layer.circleStrokeOpacity = .constant(1.0)

        try mapView.mapboxMap.addLayer(layer)
    }

    // MARK: - Airport Label + Indicator Layer
    //
    // Text (ICAO) and icon (composite badge row) are on the SAME SymbolLayer so
    // Mapbox treats them as a single symbol and they don't compete for placement.

    private func addAirportLabelLayer(to mapView: MapView) throws {
        var layer = SymbolLayer(
            id: Self.airportLabelLayerId,
            source: Self.airportSourceId
        )

        // ICAO text
        layer.textField = .expression(Exp(.get) { "icao" })
        layer.textSize = .constant(12)
        layer.textColor = .expression(airportLabelColorExpression())
        layer.textHaloColor = .constant(isDarkTheme ? StyleColor(.black) : StyleColor(.white))
        layer.textHaloWidth = .constant(1.0)
        layer.textPadding = .constant(5)
        layer.textFont = .constant(["Arial Unicode MS Regular"])
        layer.textAnchor = .constant(.left)
        layer.textOffset = .constant([0.8, 0])

        // Composite badge row — shown only when groundServiceIndicators is present.
        // The image key is "indicator-T G D" etc., matching what was pre-rendered.
        layer.iconImage = .expression(
            Exp(.switchCase) {
                Exp(.has) { "groundServiceIndicators" }
                Exp(.concat) {
                    Self.indicatorImagePrefix
                    Exp(.get) { "groundServiceIndicators" }
                }
                ""
            }
        )
        layer.iconAnchor = .constant(.topLeft)
        layer.iconOffset = .constant([12, 8])
        layer.iconAllowOverlap = .constant(false)
        layer.iconOptional = .constant(true)

        let zoomFade = Exp(.step) {
            Exp(.zoom)
            0
            5
            1
        }
        layer.textOpacity = .expression(zoomFade)
        layer.iconOpacity = .expression(zoomFade)

        layer.textAllowOverlap = .constant(false)
        layer.textIgnorePlacement = .constant(false)
        layer.textOptional = .constant(false)
        layer.symbolSortKey = .constant(10000)
        layer.symbolZOrder = .constant(.auto)

        try mapView.mapboxMap.addLayer(layer)
    }

    // MARK: - Indicator Image Generation

    /// Pre-renders every possible combination of letters as a row of coloured pills
    /// and registers each with Mapbox using key "indicator-T G D A" etc.
    private func registerIndicatorImages(on mapView: MapView) {
        let orderedLetters = ["T", "G", "D", "A"]

        // Build every non-empty subset, preserving T→G→D→A order
        for mask in 1..<(1 << orderedLetters.count) {
            var letters: [String] = []
            for (i, letter) in orderedLetters.enumerated() where (mask >> i) & 1 == 1 {
                letters.append(letter)
            }
            // The GeoJSON property is space-separated, so the key must match
            let key = Self.indicatorImagePrefix + letters.joined(separator: " ")
            guard let image = makeIndicatorRowImage(for: letters) else { continue }
            try? mapView.mapboxMap.addImage(image, id: key, sdf: false)
        }
    }

    /// Renders a horizontal row of individually-coloured pill badges, one per letter,
    /// tightly packed with a 1 pt gap between them.
    private func makeIndicatorRowImage(for letters: [String]) -> UIImage? {
        let font = UIFont.boldSystemFont(ofSize: 10)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white
        ]
        let hPad: CGFloat = 4
        let vPad: CGFloat = 2
        let cornerRadius: CGFloat = 3
        let strokeWidth: CGFloat = 1
        let gap: CGFloat = 2
        let scale: CGFloat = 3

        // Measure each letter so badges are individually sized
        let pillSizes: [CGSize] = letters.map { letter in
            let ts = (letter as NSString).size(withAttributes: textAttributes)
            return CGSize(width: ts.width + hPad * 2, height: ts.height + vPad * 2)
        }

        let totalWidth = pillSizes.reduce(0) { $0 + $1.width } + gap * CGFloat(letters.count - 1)
        let totalHeight = pillSizes.map(\.height).max() ?? 0

        UIGraphicsBeginImageContextWithOptions(CGSize(width: totalWidth, height: totalHeight), false, scale)
        defer { UIGraphicsEndImageContext() }
        guard UIGraphicsGetCurrentContext() != nil else { return nil }

        var xCursor: CGFloat = 0
        for (letter, pillSize) in zip(letters, pillSizes) {
            let color = Self.letterColors[letter] ?? UIColor.systemBlue
            let pillRect = CGRect(x: xCursor, y: 0, width: pillSize.width, height: pillSize.height)
            let pillPath = UIBezierPath(
                roundedRect: pillRect.insetBy(dx: strokeWidth / 2, dy: strokeWidth / 2),
                cornerRadius: cornerRadius
            )

            color.setFill()
            pillPath.fill()
            UIColor.black.setStroke()
            pillPath.lineWidth = strokeWidth
            pillPath.stroke()

            let ts = (letter as NSString).size(withAttributes: textAttributes)
            let textRect = CGRect(
                x: xCursor + (pillSize.width - ts.width) / 2,
                y: (pillSize.height - ts.height) / 2,
                width: ts.width,
                height: ts.height
            )
            (letter as NSString).draw(in: textRect, withAttributes: textAttributes)

            xCursor += pillSize.width + gap
        }

        return UIGraphicsGetImageFromCurrentImageContext()
    }

    // MARK: - Theme Color Expressions

    private func airportFillColorExpression() -> Exp {
        if isDarkTheme {
            return Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isSelected" }; true }
                Exp(.rgba) { 255; 59; 48; 1.0 }
                Exp(.eq) { Exp(.get) { "isFriendControlled" }; true }
                Exp(.rgba) { 48; 230; 110; 1.0 }   // bright lime-green
                Exp(.eq) { Exp(.get) { "isFilled" }; true }
                Exp(.rgba) { 255; 255; 255; 1.0 }
                Exp(.rgba) { 0; 0; 0; 0.0 }
            }
        } else {
            return Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isSelected" }; true }
                Exp(.rgba) { 255; 59; 48; 1.0 }
                Exp(.eq) { Exp(.get) { "isFriendControlled" }; true }
                Exp(.rgba) { 20; 155; 65; 1.0 }    // deep forest green
                Exp(.eq) { Exp(.get) { "isFilled" }; true }
                Exp(.rgba) { 26; 38; 68; 1.0 }     // dark navy
                Exp(.rgba) { 0; 0; 0; 0.0 }
            }
        }
    }

    private func airportStrokeColorExpression() -> Exp {
        if isDarkTheme {
            return Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isSelected" }; true }
                Exp(.rgba) { 255; 59; 48; 1.0 }
                Exp(.eq) { Exp(.get) { "isFriendControlled" }; true }
                Exp(.rgba) { 48; 230; 110; 1.0 }   // bright lime-green
                Exp(.rgba) { 255; 255; 255; 1.0 }
            }
        } else {
            return Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isSelected" }; true }
                Exp(.rgba) { 255; 59; 48; 1.0 }
                Exp(.eq) { Exp(.get) { "isFriendControlled" }; true }
                Exp(.rgba) { 20; 155; 65; 1.0 }    // deep forest green
                Exp(.rgba) { 26; 38; 68; 1.0 }     // dark navy
            }
        }
    }

    private func airportLabelColorExpression() -> Exp {
        if isDarkTheme {
            return Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isSelected" }; true }
                Exp(.rgba) { 255; 59; 48; 1.0 }
                Exp(.eq) { Exp(.get) { "isFriendControlled" }; true }
                Exp(.rgba) { 48; 230; 110; 1.0 }   // bright lime-green
                Exp(.rgba) { 255; 255; 255; 1.0 }
            }
        } else {
            return Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isSelected" }; true }
                Exp(.rgba) { 255; 59; 48; 1.0 }
                Exp(.eq) { Exp(.get) { "isFriendControlled" }; true }
                Exp(.rgba) { 20; 155; 65; 1.0 }    // deep forest green
                Exp(.rgba) { 26; 38; 68; 1.0 }     // dark navy
            }
        }
    }
}
