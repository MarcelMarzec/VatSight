//
//  AirspaceDataView.swift
//  VatSight
//
//  Created by Marcel Marzec on 28/07/2026.
//

import SwiftUI
import Combine

struct AirspaceDataView: View {
    @ObservedObject var viewModel: RadarViewModel
    @State private var isRedownloading = false
    @State private var lastUpdatedText = "Loading..."
    @State private var dataVersion = "Loading..."
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var cancellables = Set<AnyCancellable>()
    
    // Data counts
    @State private var sectorCount = 0
    @State private var positionCount = 0
    @State private var airportCount = 0
    
    var body: some View {
        List {
                Section("Vatglasses Sector Data") {
                    HStack {
                        VStack(spacing: 4) {
                            Text("Nu of Sectors")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(sectorCount)")
                                .font(.body)
                        }
                        Spacer()
                        Divider()
                        Spacer()
                        VStack(spacing: 4) {
                            Text("Nu of Positions")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(positionCount)")
                                .font(.body)
                        }
                        Spacer()
                        Divider()
                        Spacer()
                        VStack(spacing: 4) {
                            Text("Nu of Airports")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(airportCount)")
                                .font(.body)
                        }
                    }
                    LabeledContent("Last Updated", value: lastUpdatedText)
                    LabeledContent("Data Version", value: dataVersion)
                    Button {
                        redownloadData()
                    } label: {
                        if isRedownloading {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                Text("Redownloading...")
                            }
                        } else {
                            Text("Redownload Vatglasses Sectors")
                        }
                    }
                    .buttonSizing(.flexible)
                    .buttonStyle(.borderedProminent)
                    .disabled(isRedownloading)
                }
                
                Section {
                    Link(destination: URL(string: "https://github.com/lennycolton/vatglasses-data")!) {
                        HStack {
                            Image("githubLogo")
                                .resizable()
                                .foregroundStyle(.primary)
                                .frame(width: 30, height: 30)
                            Text("Checkout the Vatglasses GitHub")
                        }
                    }
                } footer: {
                    Text("Thank you to Vatglasses for making their data available to use under the CC BY-NC-SA 4.0 License. See their github for more details about the license and contributing.")
                }
            }
            .navigationTitle("Vatglasses Sector Data")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                updateDataInfo()
            }
            .alert(alertTitle, isPresented: $showingAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
    }
    
    private func updateDataInfo() {
        // Access the cached data info from the VatglassesService
        let cachedData = getCachedVatglassesData()
        
        if let data = cachedData {
            // Format the last updated date
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            lastUpdatedText = formatter.localizedString(for: data.lastUpdated, relativeTo: Date())
            
            // Show short version of commit SHA (first 7 characters)
            dataVersion = String(data.commitSHA.prefix(7))
            
            // Count sectors
            sectorCount = data.sectors.count
            
            // Count positions
            positionCount = data.allPositions.count
            
            // Count airports (unique facility prefixes from positions)
            // Extract all facility prefixes and count unique ones
            let allPrefixes = data.allPositions.values.flatMap { $0.facilityPrefixes }
            airportCount = Set(allPrefixes).count
            
        } else {
            lastUpdatedText = "No data cached"
            dataVersion = "N/A"
            sectorCount = 0
            positionCount = 0
            airportCount = 0
        }
    }
    
    private func getCachedVatglassesData() -> VatglassesData? {
        // Read the cached data from disk
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cacheFileURL = documentsPath.appendingPathComponent("vatglasses_cache.json")
        
        guard FileManager.default.fileExists(atPath: cacheFileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: cacheFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(VatglassesData.self, from: data)
        } catch {
            print("❌ Failed to load cached Vatglasses data: \(error)")
            return nil
        }
    }
    
    private func redownloadData() {
        isRedownloading = true
        
        // Clear both in-memory and on-disk cache in the VatglassesService
        viewModel.clearVatglassesCache()
        
        // Clear the viewModel's sectors to force UI update
        viewModel.sectors = []
        
        // Trigger a fresh download through the viewModel
        viewModel.loadSectorData()
        
        // Observe the sectors array for changes - wait for NON-EMPTY data
        let subscription = viewModel.$sectors
            .dropFirst() // Skip the current (now empty) value
            .filter { !$0.isEmpty } // Only proceed when we get non-empty sectors
            .first() // Take only the first non-empty change
            .receive(on: DispatchQueue.main)
            .sink { sectors in
                // Data has been updated with actual content
                // Give the map a moment to process the update
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.isRedownloading = false
                    self.updateDataInfo()
                    
                    self.alertTitle = "Success"
                    self.alertMessage = "Vatglasses data has been successfully redownloaded and parsed. Found \(sectors.count) sectors."
                    self.showingAlert = true
                    
                    print("✅ Redownload complete: \(sectors.count) sectors loaded")
                }
            }
        
        // Store the subscription
        cancellables.insert(subscription)
        
        // Fallback timeout in case the download takes too long or fails
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
            if self.isRedownloading {
                self.isRedownloading = false
                self.updateDataInfo()
                self.alertTitle = "Timeout"
                self.alertMessage = "The redownload took too long. The data may still be loading in the background. Try restarting the app if sectors don't appear."
                self.showingAlert = true
            }
        }
    }
}

#Preview {
    AirspaceDataView(viewModel: RadarViewModel())
}
