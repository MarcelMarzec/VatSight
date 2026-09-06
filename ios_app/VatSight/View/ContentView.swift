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
    @State private var selectedTab: Int = 0
    
    @Environment(\.modelContext) private var context
    @State private var manager: PreferencesManager?
    @StateObject private var radarViewModel = RadarViewModel()
    
    var body: some View {
        Group {
            if let manager {
                TabView(selection: $selectedTab) {

                    Tab("Map", systemImage: "map.fill", value: 0) {
                        RadarView()
                    }

                    Tab("Settings", systemImage: "gearshape.fill", value: 1) {
                        SettingsView()
                    }
                }
                .environment(manager)
                .environmentObject(radarViewModel)
                .preferredColorScheme(manager.userPrefs.appTheme.colorScheme)
                .onChange(of: manager.pendingNavigateToCID) { _, cid in
                    if cid != nil { selectedTab = 0 }
                }
                .onChange(of: manager.pendingNavigateToSectorId) { _, sectorId in
                    guard let id = sectorId else { return }
                    selectedTab = 0
                    if let coord = manager.pendingNavigateToSectorCoordinate {
                        radarViewModel.selectSectorAndFly(id: id, coordinate: coord)
                    } else {
                        radarViewModel.selectSector(id: id)
                    }
                    manager.pendingNavigateToSectorId = nil
                    manager.pendingNavigateToSectorCoordinate = nil
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
