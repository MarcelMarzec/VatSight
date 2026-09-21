//
//  ContentView.swift
//  VatSight
//
//  Created by Marcel Marzec on 06/05/2026.
//

import SwiftUI
import SwiftData
import MapboxMaps

private enum AppTab: Hashable {
    case map
    case settings
    case search
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .map
    
    @Environment(\.modelContext) private var context
    @State private var manager: PreferencesManager?
    @StateObject private var radarViewModel = RadarViewModel()
    
    var body: some View {
        Group {
            if let manager {
                TabView(selection: $selectedTab) {

                    Tab("Map", systemImage: "map.fill", value: AppTab.map) {
                        RadarView()
                    }

                    Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                        SettingsView()
                    }

                    Tab(value: AppTab.search, role: .search) {
                        SearchView(
                            airports: radarViewModel.airports,
                            pilots: radarViewModel.pilots,
                            controllers: radarViewModel.controllers,
                            prefiles: radarViewModel.prefiles,
                            onAirportSelected: { icao in
                                selectedTab = .map
                                radarViewModel.selectAirportAndFly(icao: icao)
                            },
                            onPilotSelected: { cid in
                                guard let pilot = radarViewModel.pilots.first(where: { $0.cid == cid }) else { return }
                                selectedTab = .map
                                radarViewModel.selectPilotAndFly(
                                    cid: cid,
                                    coordinate: pilot.coordinate,
                                    enableTracking: true
                                )
                            },
                            onControllerSelected: { controller in
                                if let airport = radarViewModel.airports.first(where: { $0.activeController?.cid == controller.cid }) {
                                    selectedTab = .map
                                    radarViewModel.selectAirportAndFly(icao: airport.icao)
                                } else if let sector = radarViewModel.sectors.first(where: { $0.activeController?.cid == controller.cid }) {
                                    selectedTab = .map
                                    radarViewModel.selectSector(id: sector.id)
                                }
                            }
                        )
                    }
                }
                .environment(manager)
                .environmentObject(radarViewModel)
                .preferredColorScheme(manager.userPrefs.appTheme.colorScheme)
                .onChange(of: radarViewModel.pendingNavigateToCID) { _, cid in
                    if cid != nil { selectedTab = .map }
                }
                .onChange(of: radarViewModel.pendingNavigateToSectorId) { _, sectorId in
                    guard let id = sectorId else { return }
                    selectedTab = .map
                    if let coord = radarViewModel.pendingNavigateToSectorCoordinate {
                        radarViewModel.selectSectorAndFly(id: id, coordinate: coord)
                    } else {
                        radarViewModel.selectSector(id: id)
                    }
                    radarViewModel.pendingNavigateToSectorId = nil
                    radarViewModel.pendingNavigateToSectorCoordinate = nil
                }
                .fullScreenCover(isPresented: Binding(
                    get: { !manager.userPrefs.hasCompletedOnboarding },
                    set: { _ in }
                )) {
                    OnboardingView()
                        .environment(manager)
                }
                .overlay {
                    if radarViewModel.isLoadingData {
                        SplashScreenView()
                            .transition(.identity)
                    }
                }
            } else {
                SplashScreenView()
                    .transition(.identity)
            }
        }
        .onAppear {
            if manager == nil {
                manager = PreferencesManager(context: context)
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserPreferencesModel.self, configurations: config)
    
    return ContentView()
        .modelContainer(container)
}
