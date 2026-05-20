//
//  MapView.swift
//  VatSight
//
//  Created by Marcel Marzec on 12/05/2026.
//

import SwiftUI
import SwiftData
import MapboxMaps

struct RadarView: View {
    
    @Environment(PreferencesManager.self) private var prefsManager
    @StateObject private var viewModel = RadarViewModel()
    
    @State private var selectedPilot: Pilot = Pilot(cid: 0, name: "N/A", callsign: "N/A", server: "N/A", pilot_rating: 0, military_rating: 0, latitude: 0.0, longitude: 0.0, altitude: 0, groundspeed: 0, transponder: "0", heading: 0, qnh_i_hg: 0, qnh_mb: 0, logon_time: "0", last_updated: "0", flight_plan: nil)
    
    
    @State private var isShowingSheet: Bool = false
    
    var body: some View {
        let backgroundColor = Color.Resolved(red: 0.2, green: 0.2, blue: 0.2)
        
        ZStack {
            RadarViewRepresentable(viewModel: viewModel,
                                   prefsManager: prefsManager)
            .ignoresSafeArea()
            .sheet(item: $viewModel.selectedPilot) { pilot in
                PilotDetailsView(pilot: pilot)
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
                    .presentationDetents([.fraction(0.3), .medium,.large])
                    .presentationBackgroundInteraction(.enabled)
            }
            .onAppear {
                viewModel.startAutoRefresh()
            }
            .onDisappear {
                viewModel.stopAutoRefresh()
            }
            
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
        }
    }
    
    func resetSelectedPilot() {
        selectedPilot = Pilot(cid: 0, name: "N/A", callsign: "N/A", server: "N/A", pilot_rating: 0, military_rating: 0, latitude: 0.0, longitude: 0.0, altitude: 0, groundspeed: 0, transponder: "0", heading: 0, qnh_i_hg: 0, qnh_mb: 0, logon_time: "0", last_updated: "0", flight_plan: nil)
        isShowingSheet = false
    }
}

#Preview {
    RadarView()
        .environment(
            PreferencesManager(
                context: try! ModelContext(
                    ModelContainer(for: UserPreferencesModel.self)
                )
            )
        )
}
