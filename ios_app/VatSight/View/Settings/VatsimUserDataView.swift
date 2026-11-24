//
//  VatsimUserDataView.swift
//  VatSight
//
//  Created by Marcel Marzec on 24/08/2026.
//

import SwiftUI
import SwiftData

struct VatsimUserDataView: View {
    @EnvironmentObject var viewModel: RadarViewModel
    @Environment(PreferencesManager.self) private var prefsManager
    @ScaledMetric private var iconSize: CGFloat = 24

    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Text("Pilots")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(viewModel.pilots.count)")
                            .font(.body)
                    }
                    Spacer()
                    Divider()
                    Spacer()
                    VStack(spacing: 4) {
                        Text("ATC")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(viewModel.controllers.count)")
                            .font(.body)
                    }
                    Spacer()
                    Divider()
                    Spacer()
                    VStack(spacing: 4) {
                        Text("ATIS")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(viewModel.atis.count)")
                            .font(.body)
                    }
                    Spacer()
                    Divider()
                    Spacer()
                    VStack(spacing: 4) {
                        Text("Prefiles")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(viewModel.prefiles.count)")
                            .font(.body)
                    }
                    Spacer()
                }
            } header: {
                Text("Live Network Statistics")
            } footer: {
                Text("Last updated: \(viewModel.general?.update_timestampFormatted ?? "Error")")
            }

            Section {
                Picker("Refresh Rate", selection: Binding(
                    get: { prefsManager.userPrefs.vatsimRefreshRate },
                    set: { prefsManager.updateRefreshRate($0) }
                )) {
                    ForEach(["15s", "30s", "1min"], id: \.self) { Text($0) }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Refresh Rate")
            }

            Section {
                LabeledContent("Data Endpoint", value: "data.vatsim.net")
                LabeledContent("API Version", value: "v3")
                Link(destination: URL(string: "https://vatsim.dev/api/data-api/")!) {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                            .frame(width: iconSize)
                            .foregroundStyle(.blue)
                        Text("VATSIM API Documentation")
                    }
                }
            } header: {
                Text("API Information")
            } footer: {
                Text("VatSight fetches live VATSIM network data from the public VATSIM Data API (v3) under the VATSIM Code of Conduct and Terms of Service. Data is provided by VATSIM and refreshed at the interval set above.")
            }
        }
        .navigationTitle("VATSIM User Data")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserPreferencesModel.self, configurations: config)

    return NavigationStack {
        VatsimUserDataView()
            .environmentObject(RadarViewModel())
            .environment(PreferencesManager(context: ModelContext(container)))
    }
}
