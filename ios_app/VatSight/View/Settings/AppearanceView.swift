//
//  AppearanceView.swift
//  VatSight
//
//  Created by Marcel Marzec on 26/08/2026.
//

import SwiftUI
import SwiftData

struct AppearanceView: View {
    @Environment(PreferencesManager.self) private var prefsManager

    var body: some View {
        List {
            // MARK: - Map Style
            Section {
                VStack(alignment: .leading) {
                    Text("Map Style")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Picker("Map Style", selection: Binding(
                        get: { prefsManager.userPrefs.mapStyle },
                        set: { newStyle in
                            prefsManager.updateMapStyle(newStyle)
                            // Keep the app theme in sync with the map style choice.
                            prefsManager.updateAppTheme(newStyle.preferredAppTheme)
                        }
                    )) {
                        ForEach(MapStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                VStack(alignment: .leading) {
                    Text("App Theme")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Picker("App Theme", selection: Binding(
                        get: { prefsManager.userPrefs.appTheme },
                        set: { prefsManager.updateAppTheme($0) }
                    )) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            } header: {
                Label("Map Styling", systemImage: "map")
            }
            
            // MARK: - Aircraft Icon Size
            Section {
                VStack(alignment: .leading) {
                    Text("Aircraft Icon Size")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Picker("Aircraft Icon Size", selection: Binding(
                        get: { prefsManager.userPrefs.planeIconMultiplier },
                        set: { prefsManager.updatePlaneIconMultiplier($0) }
                    )) {
                        ForEach([0.5, 0.75, 1.0, 1.25, 1.5], id: \.self) { multiplier in
                            Text(String(format: "%.2gx", multiplier)).tag(multiplier)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                VStack(alignment: .leading) {
                    Text("Airport Icon Size")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Picker("Airport Icon Size", selection: Binding(
                        get: { prefsManager.userPrefs.airportIconMultiplier },
                        set: { prefsManager.updateAirportIconMultiplier($0) }
                    )) {
                        ForEach([0.5, 0.75, 1.0, 1.25, 1.5], id: \.self) { multiplier in
                            Text(String(format: "%.2gx", multiplier)).tag(multiplier)
                        }
                    }
                    .pickerStyle(.segmented)
                }

            } header: {
                Label("Icon Styling", systemImage: "paperplane")
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserPreferencesModel.self, configurations: config)
    let context = ModelContext(container)

    return NavigationStack {
        AppearanceView()
            .environment(PreferencesManager(context: context))
    }
}
