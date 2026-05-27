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
    @State private var slider: Double = 0.5
    
    @State private var selectedPilot: Pilot = Pilot(cid: 0, name: "N/A", callsign: "N/A", server: "N/A", pilot_rating: 0, military_rating: 0, latitude: 0.0, longitude: 0.0, altitude: 0, groundspeed: 0, transponder: "0", heading: 0, qnh_i_hg: 0, qnh_mb: 0, logon_time: Date.now, last_updated: Date.now, flight_plan: nil)
    
    var body: some View {
        let backgroundColor = Color.Resolved(red: 0.2, green: 0.2, blue: 0.2)
        
        ZStack {
            RadarViewRepresentable(viewModel: viewModel,
                                   prefsManager: prefsManager)
            .ignoresSafeArea()
            .sheet(isPresented: $viewModel.isShowingPilotSheet,
                onDismiss: { viewModel.dismissPilotSheet() }
            ) { if let pilot = viewModel.selectedPilot {
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
                        .presentationDetents([.fraction(0.275), .medium, .large])
                        .presentationBackgroundInteraction(.enabled)
                }
            }
            .onAppear {
                viewModel.startAutoRefresh()
            }
            .onDisappear {
                viewModel.stopAutoRefresh()
            }
        }
    }
    
    func resetSelectedPilot() {
        selectedPilot = Pilot(cid: 0, name: "N/A", callsign: "N/A", server: "N/A", pilot_rating: 0, military_rating: 0, latitude: 0.0, longitude: 0.0, altitude: 0, groundspeed: 0, transponder: "0", heading: 0, qnh_i_hg: 0, qnh_mb: 0, logon_time: Date.now, last_updated: Date.now, flight_plan: nil)
        viewModel.selectedCID = nil
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
