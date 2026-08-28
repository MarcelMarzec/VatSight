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
                VStack(alignment: .leading, spacing: 8) {
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
                .padding(.vertical, 4)
            } header: {
                Label("Map", systemImage: "map")
            } footer: {
                Text("System uses Night for Dark Mode and Day for Light Mode to match your device appearance.")
            }

            // MARK: - App Theme
            Section {
                VStack(alignment: .leading, spacing: 8) {
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
                .padding(.vertical, 4)
            } header: {
                Label("Interface", systemImage: "paintpalette")
            } footer: {
                Text("System follows your device's Dark/Light Mode setting. Dark and Light override it.")
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
