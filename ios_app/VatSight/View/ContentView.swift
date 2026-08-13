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
                    .preferredColorScheme(.dark)
                } else {
                    ProgressView("Loading preferences...")
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
