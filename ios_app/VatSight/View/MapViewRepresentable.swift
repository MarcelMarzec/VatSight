//
//  MapViewRepresentable.swift
//  VatSight
//

import SwiftUI
import MapboxMaps

struct MapViewRepresentable: UIViewRepresentable {
    
    @ObservedObject var viewModel: MapViewModel
    
    private let styleManager = MapStyleManager()
    
    // MARK: - Create MapView
    
    func makeUIView(context: Context) -> MapView {
        
        let mapView = MapView(
            frame: .zero,
            mapInitOptions: MapInitOptions(
                styleURI: .standard
            )
        )
        
        mapView.mapboxMap.onStyleLoaded.observeNext { _ in
            
            // STEP 2:
            // Add the GeoJSON source
            
            styleManager.addPilotSource(to: mapView)
            
            // Initial pilot data
            
            styleManager.updatePilotSource(
                on: mapView,
                pilots: viewModel.pilots
            )
        }
        
        return mapView
    }
    
    // MARK: - Update
    
    func updateUIView(
        _ mapView: MapView,
        context: Context
    ) {
        
        styleManager.updatePilotSource(
            on: mapView,
            pilots: viewModel.pilots
        )
    }
}