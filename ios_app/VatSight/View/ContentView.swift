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
    
    var body: some View {
        let backgroundColor = Color.Resolved(red: 0.2, green: 0.2, blue: 0.2)
        let center = CLLocationCoordinate2D(latitude: 52.0, longitude: 5.0)
        
        ZStack {
            Map(initialViewport:.camera(
                center: center, zoom: 3, bearing: 0, pitch: 0)) {
                    PointAnnotationGroup(viewModel.pilots, id: \.cid) { pilot in
                        PointAnnotation(coordinate: pilot.coordinate)
                            .image(.init(image: UIImage(named: "pilot")!, name: "pilot"))
                            .iconRotate(pilot.heading)
                            .iconSize(0.8)
                    }
            }.mapStyle(MapStyle(uri: StyleURI(rawValue: "mapbox://styles/marcelm005/cmovo48xo002201s30ohu1t9r/draft")!))
                .ornamentOptions(
                    OrnamentOptions(
                        scaleBar: ScaleBarViewOptions(visibility: .hidden),
                        compass: CompassViewOptions(visibility: .hidden),
                        attributionButton: AttributionButtonOptions(
                            position: .bottomLeading,
                            margins: CGPoint(x: 90, y: 7)
                        )
                    )
                )
                .ignoresSafeArea()
            
            VStack {
                HStack{
                    Spacer()
                    Button{}label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size:20))
                    }.padding()
                        .background(Color(backgroundColor))
                        .cornerRadius(10)
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
