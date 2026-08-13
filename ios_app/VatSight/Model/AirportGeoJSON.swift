//
//  AirportGeoJSON.swift
//  VatSight
//
//  Created by Marcel Marzec on 29/07/2026.
//

import Foundation
import MapboxMaps
import CoreLocation

enum AirportGeoJSON {
    
    /// Converts airports to GeoJSON FeatureCollection.
    /// - Parameters:
    ///   - airports: Airports to render (must have isActive stamped by VatglassesService.getActiveAirports).
    ///   - filledICAOs: Set of ICAO codes that should render as filled circles (active controller or flight plan).
    static func featureCollection(from airports: [VatglassesAirport], filledICAOs: Set<String>, selectedICAO: String? = nil) -> FeatureCollection {
        let features: [Feature] = airports.map { airport in
            let coordinate = CLLocationCoordinate2D(
                latitude: airport.latitude,
                longitude: airport.longitude
            )
            var feature = Feature(geometry: .point(Point(coordinate)))
            feature.identifier = .string(airport.icao)
            
            var properties = JSONObject()
            properties["icao"] = .string(airport.icao)
            properties["isActive"] = .boolean(airport.isActive)
            properties["isFilled"] = .boolean(filledICAOs.contains(airport.icao))
            properties["isSelected"] = .boolean(airport.icao == selectedICAO)
            
            if let controller = airport.activeController {
                properties["controllerCallsign"] = .string(controller.callsign)
                properties["controllerFrequency"] = .string(controller.frequency)
            }

            if !airport.groundServiceIndicators.isEmpty {
                properties["groundServiceIndicators"] = .string(airport.groundServiceIndicators)
            }
            
            feature.properties = properties
            return feature
        }
        
        return FeatureCollection(features: features)
    }
}
