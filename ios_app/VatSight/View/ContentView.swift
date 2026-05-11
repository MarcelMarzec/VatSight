//
//  ContentView.swift
//  VatSight
//
//  Created by Marcel Marzec on 06/05/2026.
//

import SwiftUI
import SwiftData
import MapboxMaps

struct ContentView: View {
    @StateObject private var viewModel = MapViewModel()
    @State private var zoomLevel: Double = 3
    @State private var lastCoordinates = CLLocationCoordinate2D(latitude: 52.0, longitude: 0.0)
    
    var body: some View {
        let backgroundColor = Color.Resolved(red: 0.2, green: 0.2, blue: 0.2)
        
        ZStack {
            Map(initialViewport:.camera(center: lastCoordinates, zoom: zoomLevel, bearing: 0, pitch: 0)){
                PointAnnotationGroup(viewModel.pilots, id: \.cid) { pilot in
                    PointAnnotation(coordinate: pilot.coordinate)
                        .image(.init(image: UIImage(named: "pilot")!, name: "pilot"))
                        .iconRotate(pilot.heading)
                        .iconSize(0.8)
                }
                ForEvery(viewModel.pilots, id: \.cid) { pilot in
                    MapViewAnnotation(coordinate: pilot.coordinate) {
                        Text(pilot.callsign)
                            .font(.caption)
                            .padding(4)
                            .foregroundColor(.white)
                            .background(Color(backgroundColor))
                            .cornerRadius(4)
                            .offset(x: 0, y: -25)
                    }.minZoom(6)
                }
            }
            .onCameraChanged { context in
                zoomLevel = context.cameraState.zoom
                lastCoordinates = context.cameraState.center
            }
            .mapStyle(MapStyle(uri: StyleURI(rawValue: "mapbox://styles/marcelm005/cmovo48xo002201s30ohu1t9r/draft")!))
                .ornamentOptions(
                    OrnamentOptions(
                        scaleBar: ScaleBarViewOptions(visibility: .hidden),
                        compass: CompassViewOptions(
                            position: .topLeading,
                            margins: CGPoint(x: 0, y: 0)
                        ),
                        attributionButton: AttributionButtonOptions(
                            position: .bottomLeading,
                            margins: CGPoint(x: 90, y: 7)
                        )
                    )
                )
                .gestureOptions(
                    GestureOptions(
                        pitchEnabled: false
                    ))
                .ignoresSafeArea()
            
            VStack {
                HStack{
                    Spacer()
                    Button{}label: {
                        Image(systemName: "gear")
                            .font(.system(size:28))
                    }.padding(10)
                        .glassEffect()
                }
                Spacer()
                HStack {
                    Spacer()
                    Button{}label: {
                        Text("Pilot count: \(viewModel.pilots.count)")
                            .font(.system(size:20))
                    }.padding()
                        .background(Color(backgroundColor))
                        .cornerRadius(10)
                }
            }
            .foregroundColor(.white)
                .padding(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20))
        }.onAppear(
            perform: viewModel.startAutoRefresh
        )
    }
}

#Preview {
    ContentView()
}
