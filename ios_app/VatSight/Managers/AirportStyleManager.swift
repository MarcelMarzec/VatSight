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
    static let airportIndicatorLayerId = "airport-indicator-layer"

    /// Prefix for sprite image keys registered with Mapbox
    private static let indicatorImagePrefix = "indicator-"

    enum AirportStyleError: Error {
        case layerAlreadyExists
    }

    // MARK: - Configure

    func configureAirports(on mapView: MapView) throws {
        registerIndicatorImages(on: mapView)
        try addAirportSource(to: mapView)
        try addAirportLayer(to: mapView)
        try addAirportLabelLayer(to: mapView)
        try addAirportIndicatorLayer(to: mapView)
    }

    // MARK: - Update Source

    func updateAirports(
        on mapView: MapView,
        airports: [VatglassesAirport],
        filledICAOs: Set<String>
    ) {
        guard mapView.mapboxMap.sourceExists(withId: Self.airportSourceId) else { return }
        let collection = AirportGeoJSON.featureCollection(from: airports, filledICAOs: filledICAOs)
        mapView.mapboxMap.updateGeoJSONSource(
            withId: Self.airportSourceId,
            geoJSON: .featureCollection(collection)
        )
    }

    // MARK: - Ensure Layer Order

    func ensureAirportLabelIsOnTop(on mapView: MapView) {
        // Move label layer to top
        if mapView.mapboxMap.layerExists(withId: Self.airportLabelLayerId) {
            let allLayers = mapView.mapboxMap.allLayerIdentifiers
            if allLayers.last?.id != Self.airportLabelLayerId {
                if let layer = try? mapView.mapboxMap.layer(withId: Self.airportLabelLayerId, type: SymbolLayer.self) {
                    try? mapView.mapboxMap.removeLayer(withId: Self.airportLabelLayerId)
                    try? mapView.mapboxMap.addLayer(layer, layerPosition: nil)
                }
            }
        }
        // Move indicator layer just below label layer
        if mapView.mapboxMap.layerExists(withId: Self.airportIndicatorLayerId) {
            if let layer = try? mapView.mapboxMap.layer(withId: Self.airportIndicatorLayerId, type: SymbolLayer.self) {
                try? mapView.mapboxMap.removeLayer(withId: Self.airportIndicatorLayerId)
                try? mapView.mapboxMap.addLayer(layer, layerPosition: nil)
            }
        }
    }

    // MARK: - Remove Layers

    func removeAirportLayers(from mapView: MapView) {
        try? mapView.mapboxMap.removeLayer(withId: Self.airportIndicatorLayerId)
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
                Exp(.eq) { Exp(.get) { "isFilled" }; true }
                3.0
                2.0
            }
        )

        layer.circleColor = .expression(
            Exp(.switchCase) {
                Exp(.eq) { Exp(.get) { "isFilled" }; true }
                Exp(.rgba) { 255; 255; 255; 1.0 }
                Exp(.rgba) { 0; 0; 0; 0.0 }
            }
        )

        layer.circleStrokeColor = .constant(StyleColor(.white))
        layer.circleStrokeWidth = .constant(1.5)
        layer.circleStrokeOpacity = .constant(1.0)

        try mapView.mapboxMap.addLayer(layer)
    }

    // MARK: - Airport Label Layer

    private func addAirportLabelLayer(to mapView: MapView) throws {
        var layer = SymbolLayer(
            id: Self.airportLabelLayerId,
            source: Self.airportSourceId
        )

        layer.textField = .expression(Exp(.get) { "icao" })

        layer.textSize = .constant(10)
        layer.textColor = .constant(StyleColor(.white))
        layer.textHaloColor = .constant(StyleColor(.black))
        layer.textHaloWidth = .constant(1.0)
        layer.textPadding = .constant(5)
        layer.textFont = .constant(["DIN Pro Medium", "Arial Unicode MS Regular"])

        // Anchor to the left so the label sits to the right of the circle
        layer.textAnchor = .constant(.left)
        layer.textOffset = .constant([0.8, 0])

        layer.textOpacity = .expression(
            Exp(.step) {
                Exp(.zoom)
                0
                5
                1
            }
        )

        layer.textAllowOverlap = .constant(false)
        layer.textIgnorePlacement = .constant(false)
        layer.textOptional = .constant(false)
        layer.symbolSortKey = .constant(10000)
        layer.symbolZOrder = .constant(.auto)

        try mapView.mapboxMap.addLayer(layer)
    }

    // MARK: - Airport Indicator Icon Layer

    private func addAirportIndicatorLayer(to mapView: MapView) throws {
        var layer = SymbolLayer(
            id: Self.airportIndicatorLayerId,
            source: Self.airportSourceId
        )

        // Only render features that have a groundServiceIndicators property
        layer.filter = Exp(.has) { "groundServiceIndicators" }

        // Pick the pre-rendered sprite by prepending the prefix to the indicators string
        layer.iconImage = .expression(
            Exp(.concat) {
                Self.indicatorImagePrefix
                Exp(.get) { "groundServiceIndicators" }
            }
        )

        layer.iconAnchor = .constant(.top)
        // Position the badge below the airport dot
        layer.iconOffset = .constant([0, 6])
        layer.iconAllowOverlap = .constant(false)
        layer.iconIgnorePlacement = .constant(false)
        layer.iconOptional = .constant(true)

        layer.iconOpacity = .expression(
            Exp(.step) {
                Exp(.zoom)
                0
                5
                1
            }
        )

        layer.symbolSortKey = .constant(10000)
        layer.symbolZOrder = .constant(.auto)

        try mapView.mapboxMap.addLayer(layer)
    }

    // MARK: - Indicator Image Generation

    /// Generates and registers a sprite image for every possible indicator combination.
    private func registerIndicatorImages(on mapView: MapView) {
        let letters = ["T", "G", "D", "A"]

        // Build every non-empty subset, preserving T→G→D→A order
        var combinations: [String] = []
        for mask in 1..<(1 << letters.count) {
            var parts: [String] = []
            for (i, letter) in letters.enumerated() where (mask >> i) & 1 == 1 {
                parts.append(letter)
            }
            combinations.append(parts.joined(separator: " "))
        }

        for indicators in combinations {
            let key = Self.indicatorImagePrefix + indicators
            guard let image = makeIndicatorImage(for: indicators) else { continue }
            try? mapView.mapboxMap.addImage(image, id: key, sdf: false)
        }
    }

    /// Renders a pill-shaped badge: system-blue fill, black outline, white bold text.
    private func makeIndicatorImage(for indicators: String) -> UIImage? {
        let font = UIFont.boldSystemFont(ofSize: 9)
        let text = indicators as NSString
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white
        ]

        let textSize = text.size(withAttributes: textAttributes)
        let hPad: CGFloat = 4
        let vPad: CGFloat = 2
        let cornerRadius: CGFloat = 3
        let strokeWidth: CGFloat = 1

        let totalWidth = textSize.width + hPad * 2
        let totalHeight = textSize.height + vPad * 2

        let scale: CGFloat = 3 // @3x for crisp rendering on all devices
        let size = CGSize(width: totalWidth, height: totalHeight)

        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }

        let rect = CGRect(origin: .zero, size: size)
        let pillPath = UIBezierPath(roundedRect: rect.insetBy(dx: strokeWidth / 2, dy: strokeWidth / 2), cornerRadius: cornerRadius)

        // Fill: system blue
        UIColor.systemBlue.setFill()
        pillPath.fill()

        // Stroke: black outline
        UIColor.black.setStroke()
        pillPath.lineWidth = strokeWidth
        pillPath.stroke()

        // Text centred in the badge
        let textRect = CGRect(
            x: (totalWidth - textSize.width) / 2,
            y: (totalHeight - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        text.draw(in: textRect, withAttributes: textAttributes)

        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
