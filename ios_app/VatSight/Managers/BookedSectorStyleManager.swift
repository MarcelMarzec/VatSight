//
//  BookedSectorStyleManager.swift
//  VatSight
//
//  Draws airspace that booked controllers will cover: a faint fill and dashed outline
//  (in the spirit of basic-data sectors) plus a callsign/time pill per booking.
//  Uses its own sources so live sector diffing is untouched.
//

import Foundation
import UIKit
import MapboxMaps
import Turf
import CoreLocation

final class BookedSectorStyleManager {
    static let sourceId = "booked-sectors-source"
    static let labelSourceId = "booked-sectors-label-source"
    static let fillLayerId = "booked-sector-fill-layer"
    static let outlineLayerId = "booked-sector-outline-layer"
    static let labelLayerId = "booked-sector-label-layer"
    private static let pillImageId = "booked-sector-pill"

    private var isDarkTheme = true

    // Cyan, matching booked-airport rings.
    private static let darkTint = UIColor(red: 0.39, green: 0.82, blue: 1.00, alpha: 1)
    private static let lightTint = UIColor(red: 0.00, green: 0.55, blue: 0.75, alpha: 1)

    private var tint: UIColor { isDarkTheme ? Self.darkTint : Self.lightTint }

    // MARK: - Configure

    func configure(on mapView: MapView, isDark: Bool) throws {
        isDarkTheme = isDark
        registerPill(on: mapView)

        var source = GeoJSONSource(id: Self.sourceId)
        source.data = .featureCollection(FeatureCollection(features: []))
        try mapView.mapboxMap.addSource(source)

        var labelSource = GeoJSONSource(id: Self.labelSourceId)
        labelSource.data = .featureCollection(FeatureCollection(features: []))
        try mapView.mapboxMap.addSource(labelSource)

        var fill = FillLayer(id: Self.fillLayerId, source: Self.sourceId)
        fill.fillColor = .constant(StyleColor(tint))
        fill.fillOpacity = .constant(isDark ? 0.05 : 0.04)
        fill.fillAntialias = .constant(false)
        try mapView.mapboxMap.addLayer(fill)

        var outline = LineLayer(id: Self.outlineLayerId, source: Self.sourceId)
        outline.lineColor = .constant(StyleColor(tint))
        outline.lineWidth = .constant(1.5)
        outline.lineDasharray = .constant([3, 2.5])
        outline.lineOpacity = .constant(0.85)
        try mapView.mapboxMap.addLayer(outline)

        var label = SymbolLayer(id: Self.labelLayerId, source: Self.labelSourceId)
        label.textField = .expression(Exp(.get) { "label" })
        label.textSize = .constant(11)
        label.textFont = .constant(["Arial Unicode MS Regular"])
        label.textColor = .constant(StyleColor(.white))
        label.textLineHeight = .constant(1.2)
        label.iconImage = .constant(.name(Self.pillImageId))
        label.iconTextFit = .constant(.both)
        label.iconTextFitPadding = .constant([3, 7, 3, 7])
        // Lowest priority of the map's labels: never displaces live sectors, airports or pilots.
        label.textAllowOverlap = .constant(false)
        label.iconAllowOverlap = .constant(false)
        label.textOptional = .constant(false)
        label.iconOptional = .constant(false)
        label.textOpacity = .expression(labelOpacity())
        label.iconOpacity = .expression(labelOpacity())
        label.symbolPlacement = .constant(.point)
        try mapView.mapboxMap.addLayer(label)
    }

    // MARK: - Fading

    /// 0 = normal, 1 = faded while an airport is focused. Animated by the map coordinator.
    private var dimProgress: Double = 0

    private func labelOpacity() -> Exp {
        Exp(.step) { Exp(.zoom); 0.0; 5; 1.0 + (SectorStyleManager.dimmedLabelOpacity - 1.0) * dimProgress }
    }

    func applyDimProgress(_ progress: Double, on mapView: MapView) {
        dimProgress = progress
        let opacity = labelOpacity()
        try? mapView.mapboxMap.updateLayer(withId: Self.labelLayerId, type: SymbolLayer.self) { layer in
            layer.textOpacity = .expression(opacity)
            layer.iconOpacity = .expression(opacity)
        }
    }

    func applyTheme(on mapView: MapView, isDark: Bool) {
        isDarkTheme = isDark
        registerPill(on: mapView)
        try? mapView.mapboxMap.updateLayer(withId: Self.fillLayerId, type: FillLayer.self) { layer in
            layer.fillColor = .constant(StyleColor(tint))
            layer.fillOpacity = .constant(isDark ? 0.05 : 0.04)
        }
        try? mapView.mapboxMap.updateLayer(withId: Self.outlineLayerId, type: LineLayer.self) { layer in
            layer.lineColor = .constant(StyleColor(tint))
        }
    }

    func removeLayers(from mapView: MapView) {
        try? mapView.mapboxMap.removeLayer(withId: Self.labelLayerId)
        try? mapView.mapboxMap.removeLayer(withId: Self.outlineLayerId)
        try? mapView.mapboxMap.removeLayer(withId: Self.fillLayerId)
        try? mapView.mapboxMap.removeSource(withId: Self.sourceId)
        try? mapView.mapboxMap.removeSource(withId: Self.labelSourceId)
    }

    // MARK: - Update

    func update(
        on mapView: MapView,
        bookedSectors: [BookedSector],
        airports: [VatglassesAirport],
        timeDisplay: EventTimeDisplay
    ) {
        guard mapView.mapboxMap.sourceExists(withId: Self.sourceId) else { return }

        var features: [Feature] = []
        features.reserveCapacity(bookedSectors.count)
        // One label per booking, on its largest sector.
        var labelSector: [Int: (sector: VatglassesSector, size: Int, booking: AtcBooking)] = [:]

        for booked in bookedSectors {
            guard let geometry = booked.sector.geometry.turfGeometry else { continue }
            var feature = Feature(geometry: geometry)
            feature.identifier = .string(booked.sector.id)
            feature.properties = [
                "bookingId": .number(Double(booked.booking.id)),
                "callsign": .string(booked.booking.callsign)
            ]
            features.append(feature)

            let size = booked.sector.geometry.coordinates.reduce(0) { $0 + ($1.first?.count ?? 0) }
            if let existing = labelSector[booked.booking.id], existing.size >= size { continue }
            labelSector[booked.booking.id] = (booked.sector, size, booked.booking)
        }

        var labels: [Feature] = []
        for (_, entry) in labelSector.sorted(by: { $0.value.booking.start < $1.value.booking.start }) {
            guard let coordinate = SectorGeoJSON.labelCoordinate(for: entry.sector, airports: airports) else { continue }
            let range = EventTimeFormatting.range(start: entry.booking.start, end: entry.booking.end, display: timeDisplay)
            var label = Feature(geometry: .point(Point(coordinate)))
            label.properties = [
                "label": .string("\(entry.booking.callsign)\n\(range.primary)"),
                "bookingId": .number(Double(entry.booking.id))
            ]
            labels.append(label)
        }

        mapView.mapboxMap.updateGeoJSONSource(withId: Self.sourceId, geoJSON: .featureCollection(FeatureCollection(features: features)))
        mapView.mapboxMap.updateGeoJSONSource(withId: Self.labelSourceId, geoJSON: .featureCollection(FeatureCollection(features: labels)))
    }

    // MARK: - Pill

    private func registerPill(on mapView: MapView) {
        let cornerRadius: CGFloat = 6
        let side = cornerRadius * 2 + 1
        let fill = tint.withAlphaComponent(isDarkTheme ? 0.55 : 0.85)
        let stroke = tint
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let image = renderer.image { context in
            let rect = CGRect(x: 0, y: 0, width: side, height: side).insetBy(dx: 0.5, dy: 0.5)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius - 0.5)
            context.cgContext.setFillColor(fill.cgColor)
            context.cgContext.addPath(path.cgPath)
            context.cgContext.fillPath()
            context.cgContext.setStrokeColor(stroke.cgColor)
            context.cgContext.setLineWidth(1)
            context.cgContext.addPath(path.cgPath)
            context.cgContext.strokePath()
        }
        let stretchable = image.resizableImage(
            withCapInsets: UIEdgeInsets(top: cornerRadius, left: cornerRadius, bottom: cornerRadius, right: cornerRadius),
            resizingMode: .stretch
        )
        try? mapView.mapboxMap.removeImage(withId: Self.pillImageId)
        try? mapView.mapboxMap.addImage(stretchable, id: Self.pillImageId, sdf: false)
    }
}
