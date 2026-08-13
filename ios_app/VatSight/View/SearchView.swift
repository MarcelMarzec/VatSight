//
//  SearchView.swift
//  VatSight
//
//  Created by Marcel Marzec on 12/08/2026.
//

import SwiftUI

/// The three searchable categories.
private enum SearchCategory: String, CaseIterable {
    case airport  = "Airport"
    case aircraft = "Aircraft"
    case atc      = "ATC"

    var icon: String {
        switch self {
        case .airport:  return "airplane.ticket"
        case .aircraft: return "paperplane"
        case .atc:      return "antenna.radiowaves.left.and.right"
        }
    }
}

private let pageSize = 30

struct SearchView: View {

    // Injected data
    let airports:    [VatglassesAirport]
    let pilots:      [Pilot]
    let controllers: [Controllers]

    // Callbacks — each handler dismisses the sheet from the caller side
    var onAirportSelected:    (String) -> Void
    var onPilotSelected:      (Int) -> Void
    var onControllerSelected: (Controllers) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var query:             String = ""
    @State private var category:          SearchCategory = .airport
    @State private var visibleCount:      Int = pageSize
    /// Facility IDs currently toggled ON by the user. Empty means all facilities shown.
    @State private var selectedFacilities: Set<Int> = []

    // MARK: - Facility chip data

    /// Distinct facilities present in the live controller list, sorted by long name.
    private var availableFacilities: [Facilities] {
        var seen  = Set<Int>()
        var result: [Facilities] = []
        for ctrl in controllers {
            guard let fac = ctrl.facilityInfo, !seen.contains(fac.id) else { continue }
            seen.insert(fac.id)
            result.append(fac)
        }
        return result.sorted { $0.long < $1.long }
    }

    // MARK: - Filtered results (full)

    private var filteredAirports: [VatglassesAirport] {
        guard !query.isEmpty else { return airports }
        let q = query.uppercased()
        return airports.filter {
            $0.icao.uppercased().contains(q) ||
            ($0.callsign?.uppercased().contains(q) ?? false)
        }
    }

    private var filteredPilots: [Pilot] {
        guard !query.isEmpty else { return pilots }
        let q = query.uppercased()
        return pilots.filter {
            $0.callsign.uppercased().contains(q) ||
            ($0.flight_plan?.departure.uppercased().contains(q) ?? false) ||
            ($0.flight_plan?.arrival.uppercased().contains(q) ?? false) ||
            $0.name.uppercased().contains(q)
        }
    }

    private var filteredControllers: [Controllers] {
        // Start with text search
        let textFiltered: [Controllers]
        if query.isEmpty {
            textFiltered = controllers
        } else {
            let q = query.uppercased()
            textFiltered = controllers.filter {
                $0.callsign.uppercased().contains(q) ||
                $0.name.uppercased().contains(q) ||
                $0.frequency.contains(q)
            }
        }
        // Apply facility chip filter (empty selection = no restriction)
        guard !selectedFacilities.isEmpty else { return textFiltered }
        return textFiltered.filter { selectedFacilities.contains($0.facility) }
    }

    // MARK: - Visible slices

    private var visibleAirports:    [VatglassesAirport] { Array(filteredAirports.prefix(visibleCount)) }
    private var visiblePilots:      [Pilot]             { Array(filteredPilots.prefix(visibleCount)) }
    private var visibleControllers: [Controllers]       { Array(filteredControllers.prefix(visibleCount)) }

    private var totalCount: Int {
        switch category {
        case .airport:  return filteredAirports.count
        case .aircraft: return filteredPilots.count
        case .atc:      return filteredControllers.count
        }
    }

    private var hasMore: Bool { visibleCount < totalCount }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category picker
                Picker("Category", selection: $category) {
                    ForEach(SearchCategory.allCases, id: \.self) { cat in
                        Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                .onChange(of: category) { _, _ in
                    visibleCount = pageSize
                    selectedFacilities = []
                }

                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(placeholder, text: $query)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
                .padding(.bottom, 8)
                .onChange(of: query) { _, _ in visibleCount = pageSize }

                // Facility filter chips — only visible on the ATC tab
                if category == .atc && !availableFacilities.isEmpty {
                    facilityChips
                }

                Divider()

                // Results list
                List {
                    switch category {
                    case .airport:
                        airportResults
                    case .aircraft:
                        aircraftResults
                    case .atc:
                        atcResults
                    }

                    // Infinite-scroll sentinel: loads the next page when this row appears
                    if hasMore {
                        Color.clear
                            .frame(height: 1)
                            .listRowSeparator(.hidden)
                            .onAppear { visibleCount += pageSize }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Facility Filter Chips

    private var facilityChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableFacilities) { fac in
                    let isOn = selectedFacilities.contains(fac.id)
                    Button {
                        visibleCount = pageSize
                        if isOn {
                            selectedFacilities.remove(fac.id)
                        } else {
                            selectedFacilities.insert(fac.id)
                        }
                    } label: {
                        Text(fac.long)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                isOn ? Color.accentColor : Color.secondary.opacity(0.15),
                                in: Capsule()
                            )
                            .foregroundStyle(isOn ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Result Sections

    @ViewBuilder
    private var airportResults: some View {
        if filteredAirports.isEmpty {
            emptyState(message: "No airports found")
        } else {
            ForEach(visibleAirports) { airport in
                Button {
                    dismiss()
                    onAirportSelected(airport.icao)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(airport.icao)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                if airport.isActive {
                                    Circle()
                                        .fill(.green)
                                        .frame(width: 7, height: 7)
                                }
                            }
                            if let name = airport.callsign {
                                Text(name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                            .imageScale(.small)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var aircraftResults: some View {
        if filteredPilots.isEmpty {
            emptyState(message: "No aircraft found")
        } else {
            ForEach(visiblePilots) { pilot in
                Button {
                    dismiss()
                    onPilotSelected(pilot.cid)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pilot.callsign)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            if let fp = pilot.flight_plan {
                                Text("\(fp.departure) → \(fp.arrival)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(pilot.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(pilot.altitude) ft")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\(pilot.groundspeed) kt")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                            .imageScale(.small)
                            .padding(.leading, 4)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var atcResults: some View {
        if filteredControllers.isEmpty {
            emptyState(message: "No active ATC found")
        } else {
            ForEach(visibleControllers) { controller in
                Button {
                    dismiss()
                    onControllerSelected(controller)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(controller.callsign)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(controller.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(controller.frequency)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Text(controller.onlineDuration)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                            .imageScale(.small)
                            .padding(.leading, 4)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private var placeholder: String {
        switch category {
        case .airport:  return "ICAO or airport name"
        case .aircraft: return "Callsign, route or pilot name"
        case .atc:      return "Callsign, name or frequency"
        }
    }

    private func emptyState(message: String) -> some View {
        ContentUnavailableView(
            query.isEmpty ? "No Data" : "No Results",
            systemImage: query.isEmpty ? "wifi.slash" : "magnifyingglass",
            description: Text(query.isEmpty ? "Data not yet loaded" : message)
        )
        .listRowSeparator(.hidden)
    }
}
