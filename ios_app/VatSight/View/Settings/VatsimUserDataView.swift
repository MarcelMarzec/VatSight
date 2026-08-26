//
//  VatsimUserDataView.swift
//  VatSight
//
//  Created by Marcel Marzec on 24/08/2026.
//

import SwiftUI

struct VatsimUserDataView: View {
    @EnvironmentObject var viewModel: RadarViewModel

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
                LabeledContent("Data Endpoint", value: "data.vatsim.net")
                LabeledContent("API Version", value: "v3")
                Link(destination: URL(string: "https://vatsim.dev/api/data-api/")!) {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                            .foregroundStyle(.blue)
                        Text("VATSIM API Documentation")
                    }
                }
            } header: {
                Text("API Information")
            } footer: {
                Text("VatSight fetches live VATSIM network data from the public VATSIM Data API (v3) under the VATSIM Code of Conduct and Terms of Service. Data is provided by VATSIM and refreshed at the interval set in Settings.")
            }
        }
        .navigationTitle("VATSIM User Data")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        VatsimUserDataView()
            .environmentObject(RadarViewModel())
    }
}
