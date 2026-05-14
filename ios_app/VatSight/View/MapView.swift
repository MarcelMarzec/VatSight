//
//  MapView.swift
//  VatSight
//
//  Created by Marcel Marzec on 12/05/2026.
//

import SwiftUI
import SwiftData
import MapboxMaps

struct MapView: View {
    @Environment(PreferencesManager.self) private var prefsManager
    @StateObject private var viewModel = MapViewModel()
    
    @State private var selectedPilot: Pilot = Pilot(cid: 0, name: "N/A", callsign: "N/A", server: "N/A", pilot_rating: 0, military_rating: 0, latitude: 0.0, longitude: 0.0, altitude: 0, groundspeed: 0, transponder: "0", heading: 0, qnh_i_hg: 0, qnh_mb: 0, logon_time: "0", last_updated: "0", flight_plan: nil)
    
    
    @State private var isShowingSheet: Bool = false
    
    var body: some View {
        let backgroundColor = Color.Resolved(red: 0.2, green: 0.2, blue: 0.2)
        
        ZStack {
            Map(initialViewport:.camera(center: CLLocationCoordinate2D(latitude: prefsManager.userPrefs.lastLatitude, longitude: prefsManager.userPrefs.lastLongitude), zoom: prefsManager.userPrefs.lastZoom, bearing: 0, pitch: 0)){
                
                PointAnnotationGroup(viewModel.pilots, id: \.cid) { pilot in
                    PointAnnotation(coordinate: pilot.coordinate)
                        .image(.init(image: UIImage(named: "pilot")!, name: "pilot"))
                        .iconRotate(pilot.heading)
                        .iconSize(0.8)
                        .onTapGesture {
                            selectedPilot = pilot
                            isShowingSheet = true
                        }
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
                            .onTapGesture {
                                selectedPilot = pilot
                                isShowingSheet = true
                            }
                    }.minZoom(6)
                }
            }
            .onCameraChanged { context in
                prefsManager.userPrefs.lastZoom = context.cameraState.zoom
                prefsManager.userPrefs.lastLatitude = context.cameraState.center.latitude
                prefsManager.userPrefs.lastLongitude = context.cameraState.center.longitude
            }
            .mapStyle(MapStyle(uri: StyleURI(rawValue: "mapbox://styles/marcelm005/cmovo48xo002201s30ohu1t9r")!))
            .ornamentOptions(
                OrnamentOptions(
                    scaleBar: ScaleBarViewOptions(visibility: .hidden),
                    compass: CompassViewOptions(
                        position: .topLeading,
                        margins: CGPoint(x: 7, y: 7)
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
                Spacer()
                HStack {
                    Spacer()
                    Button{}label: {
                        Text("Pilot count: \(viewModel.pilots.count)")
                            .font(.footnote)
                    }.padding()
                        .glassEffect()
                }
            }
            .foregroundColor(.white)
            .padding(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20))
            .sheet(isPresented: $isShowingSheet, onDismiss: resetSelectedPilot) {
                PilotDetailsView(selectedPilot: $selectedPilot, isShowingSheet: $isShowingSheet)
                    .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 20,
                                bottomLeadingRadius: 50,
                                bottomTrailingRadius: 50,
                                topTrailingRadius: 20,
                                style: .continuous
                            )
                        )
                    .presentationDragIndicator(.visible)
                    .presentationDetents([.fraction(0.30), .medium,.large])
            }
        }.onAppear(
            perform: viewModel.startAutoRefresh
        )
    }
    
    func resetSelectedPilot() {
        selectedPilot = Pilot(cid: 0, name: "N/A", callsign: "N/A", server: "N/A", pilot_rating: 0, military_rating: 0, latitude: 0.0, longitude: 0.0, altitude: 0, groundspeed: 0, transponder: "0", heading: 0, qnh_i_hg: 0, qnh_mb: 0, logon_time: "0", last_updated: "0", flight_plan: nil)
        isShowingSheet = false
    }
}

#Preview {
    MapView()
        .environment(
            PreferencesManager(
                context: try! ModelContext(
                    ModelContainer(for: UserPreferencesModel.self)
                )
            )
        )
}
