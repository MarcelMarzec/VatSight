//
//  SearchView.swift
//  VatSight
//
//  Created by Marcel Marzec on 12/08/2026.
//

import SwiftUI

/// Sort orders available for the airport list.
private enum AirportSortOrder: String, CaseIterable {
    case totalPilotsHigh   = "Total Pilots: High → Low"
    case controllersHigh   = "Controllers: High → Low"
    case departuresHigh    = "Departures: High → Low"
    case arrivalsHigh      = "Arrivals: High → Low"
    case onGroundHigh      = "On Ground: High → Low"

    var systemImage: String {
        switch self {
        case .totalPilotsHigh:  return "paperplane"
        case .controllersHigh:  return "antenna.radiowaves.left.and.right"
        case .departuresHigh:   return "airplane.departure"
        case .arrivalsHigh:     return "airplane.arrival"
        case .onGroundHigh:     return "airplane.landed"
        }
    }
}

/// The three searchable categories.
private enum SearchCategory: String, CaseIterable {
    case airport  = "Airport"
    case pilot    = "Pilots"
    case atc      = "ATC"

    var icon: String {
        switch self {
        case .airport: return "airplane.ticket"
        case .pilot:   return "paperplane"
        case .atc:     return "antenna.radiowaves.left.and.right"
        }
    }
}

private let pageSize = 30

struct SearchView: View {

    // Injected data
    let airports:    [VatglassesAirport]
    let pilots:      [Pilot]
    let controllers: [Controllers]
    let prefiles:    [Prefiles]

    // Callbacks — each handler navigates to the map tab from the caller side
    var onAirportSelected:    (String) -> Void
    var onPilotSelected:      (Int) -> Void
    var onControllerSelected: (Controllers) -> Void

    @Environment(PreferencesManager.self) private var prefsManager

    @State private var query:              String = ""
    @State private var category: SearchCategory = .atc
    @State private var visibleCount:       Int = pageSize
    /// Facility IDs explicitly included (first tap — accent). Empty means no include filter.
    @State private var selectedFacilities: Set<Int> = []
    /// Facility IDs explicitly excluded (second tap — red). Overrides selectedFacilities.
    /// ID 0 (Observer) is excluded by default.
    @State private var excludedFacilities: Set<Int> = [0]
    /// When true, inactive airports are included in the airport list.
    @State private var showInactiveAirports: Bool = false
    /// Current sort order for the airport list.
    @State private var airportSort: AirportSortOrder = .totalPilotsHigh

    // MARK: - Cached pre-computations

    /// Pilots sorted once alphabetically by callsign. Avoids re-sorting on every computed access.
    private var sortedPilots: [Pilot] {
        pilots.sorted { $0.callsign < $1.callsign }
    }

    /// Single-pass lookup table: traffic counts + controller count per uppercase ICAO.
    /// Built once per render so sort comparisons are O(1) dictionary lookups.
    /// Counting logic mirrors AirportDetailsView / AirportTraffic so numbers match.
    private var airportStats: [String: AirportCounts] {
        var result: [String: AirportCounts] = [:]
        // Live pilots → airborne deps/arrs and on-ground counts.
        // On-ground pilots contribute to onGround at BOTH their dep and arr airports
        // (matching totalOnGround = groundDepartures + groundArrivals in AirportTraffic).
        for pilot in pilots {
            guard let fp = pilot.flight_plan else { continue }
            let dep   = fp.departure.uppercased()
            let arr   = fp.arrival.uppercased()
            let onGnd = pilot.groundspeed < 40
            if !dep.isEmpty {
                var c = result[dep] ?? AirportCounts()
                if onGnd { c.onGround += 1 } else { c.departures += 1 }
                result[dep] = c
            }
            if !arr.isEmpty {
                var c = result[arr] ?? AirportCounts()
                if onGnd { c.onGround += 1 } else { c.arrivals += 1 }
                result[arr] = c
            }
        }
        // Prefiles → count toward departures and arrivals (no live position, never on ground)
        for prefile in prefiles {
            guard let fp = prefile.flight_plan else { continue }
            let dep = fp.departure.uppercased()
            let arr = fp.arrival.uppercased()
            if !dep.isEmpty {
                var c = result[dep] ?? AirportCounts()
                c.departures += 1
                result[dep] = c
            }
            if !arr.isEmpty {
                var c = result[arr] ?? AirportCounts()
                c.arrivals += 1
                result[arr] = c
            }
        }
        // Controllers → use the pre-matched data on each airport.
        // groundServiceIndicators holds space-separated letters (T/G/D/A) for each active
        // ground service; activeController represents an approach/departure controller.
        // This mirrors the matching logic in VatglassesMatchingService and avoids
        // falsely attributing sector/enroute controllers (e.g. EGTT_CTR) to airports.
        for airport in airports {
            let icao = airport.icao.uppercased()
            let groundCount = airport.groundServiceIndicators
                .split(separator: " ")
                .filter { !$0.isEmpty }
                .count
            let approachCount = airport.activeController != nil ? 1 : 0
            if groundCount + approachCount > 0 {
                var c = result[icao] ?? AirportCounts()
                c.controllers = groundCount + approachCount
                result[icao] = c
            }
        }
        return result
    }

    /// Convenience accessor used by result rows.
    private func stats(for icao: String) -> AirportCounts {
        airportStats[icao.uppercased()] ?? AirportCounts()
    }

    // MARK: - Facility chip data

    /// Distinct facilities present in the live controller list, sorted by ID descending.
    private var availableFacilities: [Facilities] {
        var seen  = Set<Int>()
        var result: [Facilities] = []
        for ctrl in controllers {
            guard let fac = ctrl.facilityInfo, !seen.contains(fac.id) else { continue }
            seen.insert(fac.id)
            result.append(fac)
        }
        return result.sorted { $0.id > $1.id }
    }

    /// Number of controllers for a given facility ID (unfiltered by query or chips).
    private func controllerCount(for facilityId: Int) -> Int {
        controllers.filter { $0.facility == facilityId }.count
    }

    // MARK: - Filtered results (full)

    private var filteredAirports: [VatglassesAirport] {
        let base = showInactiveAirports ? airports : airports.filter { $0.isActive }
        let textFiltered: [VatglassesAirport]
        if query.isEmpty {
            textFiltered = base
        } else {
            let q = query.uppercased()
            textFiltered = base.filter {
                $0.icao.uppercased().contains(q) ||
                ($0.callsign?.uppercased().contains(q) ?? false)
            }
        }
        // Capture the lookup table once so the sort closure is pure O(1) per comparison
        let stats = airportStats
        return textFiltered.sorted { a, b in
            let sa = stats[a.icao.uppercased()] ?? AirportCounts()
            let sb = stats[b.icao.uppercased()] ?? AirportCounts()
            let va: Int
            let vb: Int
            switch airportSort {
            case .totalPilotsHigh:  va = sa.total;       vb = sb.total
            case .controllersHigh:  va = sa.controllers; vb = sb.controllers
            case .departuresHigh:   va = sa.departures;  vb = sb.departures
            case .arrivalsHigh:     va = sa.arrivals;    vb = sb.arrivals
            case .onGroundHigh:     va = sa.onGround;    vb = sb.onGround
            }
            return va != vb ? va > vb : a.icao < b.icao
        }
    }

    private var filteredPilots: [Pilot] {
        guard !query.isEmpty else { return sortedPilots }
        let q = query.uppercased()
        return sortedPilots.filter {
            $0.callsign.uppercased().contains(q) ||
            ($0.flight_plan?.departure.uppercased().contains(q) ?? false) ||
            ($0.flight_plan?.arrival.uppercased().contains(q) ?? false) ||
            $0.name.uppercased().contains(q)
        }
    }

    private var filteredControllers: [Controllers] {
        // Start with text search then sort alphabetically by callsign
        let base: [Controllers]
        if query.isEmpty {
            base = controllers
        } else {
            let q = query.uppercased()
            base = controllers.filter {
                $0.callsign.uppercased().contains(q) ||
                $0.name.uppercased().contains(q) ||
                $0.frequency.contains(q)
            }
        }
        let textFiltered = base.sorted { $0.callsign < $1.callsign }
        // Exclude filter takes priority
        let afterExclude = excludedFacilities.isEmpty
            ? textFiltered
            : textFiltered.filter { !excludedFacilities.contains($0.facility) }
        // Include filter (empty = no restriction)
        guard !selectedFacilities.isEmpty else { return afterExclude }
        return afterExclude.filter { selectedFacilities.contains($0.facility) }
    }

    // MARK: - Airport stats

    private struct AirportCounts {
        var departures:  Int = 0
        var arrivals:    Int = 0
        var onGround:    Int = 0
        var controllers: Int = 0
        var total: Int { departures + arrivals + onGround }
    }

    // MARK: - Visible slices

    private var visibleAirports:    [VatglassesAirport] { Array(filteredAirports.prefix(visibleCount)) }
    private var visiblePilots:      [Pilot]             { Array(filteredPilots.prefix(visibleCount)) }
    private var visibleControllers: [Controllers]       { Array(filteredControllers.prefix(visibleCount)) }

    private var totalCount: Int {
        switch category {
        case .airport:  return filteredAirports.count
        case .pilot: return filteredPilots.count
        case .atc:      return filteredControllers.count
        }
    }

    private var hasMore: Bool { visibleCount < totalCount }

    // MARK: - List content

    @ViewBuilder
    private var listContent: some View {
        // Category picker — always visible at the top of the list
        Picker("Category", selection: $category) {
            Text("ATC (\(controllers.count))").tag(SearchCategory.atc)
            Text("Pilots (\(pilots.count))").tag(SearchCategory.pilot)
            Text("Airports (\(airports.count))").tag(SearchCategory.airport)
        }
        .pickerStyle(.segmented)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)

        // Filter chips inline, only when relevant
        if category == .atc && !availableFacilities.isEmpty {
            Section {
                facilityChips
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        } else if category == .airport {
            Section {
                airportFilterChips
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }

        // Results
        switch category {
        case .pilot:
            aircraftResults
        case .atc:
            atcResults
        case .airport:
            airportResults
        }

        // Infinite-scroll sentinel
        if hasMore {
            Color.clear
                .frame(height: 1)
                .listRowSeparator(.hidden)
                .onAppear { visibleCount += pageSize }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                listContent
            }
            .listStyle(.plain)
            .navigationTitle("Search")
            .searchable(text: $query, placement: .toolbar, prompt: placeholder)
            .searchToolbarBehavior(.minimize)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.characters)
            .toolbar {
                if category == .airport {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            ForEach(AirportSortOrder.allCases, id: \.self) { order in
                                Button {
                                    airportSort = order
                                    visibleCount = pageSize
                                } label: {
                                    Label(
                                        order.rawValue,
                                        systemImage: airportSort == order
                                            ? "checkmark"
                                            : order.systemImage
                                    )
                                }
                            }
                        } label: {
                            Label("Sort", systemImage: airportSort == .totalPilotsHigh
                                  ? "arrow.up.arrow.down"
                                  : "arrow.up.arrow.down.circle.fill")
                        }
                    }
                }
            }
            .onChange(of: query)    { _, _ in visibleCount = pageSize }
            .onChange(of: category) { _, _ in
                visibleCount = pageSize
                selectedFacilities = []
                excludedFacilities = [0]
                showInactiveAirports = false
                airportSort = .totalPilotsHigh
            }
            .onAppear {
                category             = SearchCategory(rawValue: prefsManager.userPrefs.searchCategoryRaw) ?? .atc
                selectedFacilities   = Set(prefsManager.userPrefs.searchSelectedFacilities)
                excludedFacilities   = Set(prefsManager.userPrefs.searchExcludedFacilities)
                showInactiveAirports = prefsManager.userPrefs.searchShowInactiveAirports
            }
            .onChange(of: category)             { _, new in prefsManager.updateSearchCategory(new.rawValue) }
            .onChange(of: selectedFacilities)   { _, new in prefsManager.updateSearchSelectedFacilities(new) }
            .onChange(of: excludedFacilities)   { _, new in prefsManager.updateSearchExcludedFacilities(new) }
            .onChange(of: showInactiveAirports) { _, new in prefsManager.updateSearchShowInactiveAirports(new) }
        }
    }

    // MARK: - Facility Filter Chips

    private var facilityChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableFacilities) { fac in
                    let isIncluded = selectedFacilities.contains(fac.id)
                    let isExcluded = excludedFacilities.contains(fac.id)
                    let chipColor: Color = isExcluded ? .red : isIncluded ? .accentColor : Color.secondary.opacity(0.15)
                    let textColor: Color = (isIncluded || isExcluded) ? .white : .primary
                    Button {
                        visibleCount = pageSize
                        if isExcluded {
                            // Third tap — reset to neutral
                            excludedFacilities.remove(fac.id)
                        } else if isIncluded {
                            // Second tap — move to excluded
                            selectedFacilities.remove(fac.id)
                            excludedFacilities.insert(fac.id)
                        } else {
                            // First tap — include
                            selectedFacilities.insert(fac.id)
                        }
                    } label: {
                        Text("\(fac.long) (\(controllerCount(for: fac.id)))")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(chipColor, in: Capsule())
                            .foregroundStyle(textColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Airport Filter Chips

    private var airportFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    visibleCount = pageSize
                    showInactiveAirports.toggle()
                } label: {
                    Text("Show uncontrolled (\(airports.filter { !$0.isActive }.count))")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            showInactiveAirports ? Color.accentColor : Color.secondary.opacity(0.15),
                            in: Capsule()
                        )
                        .foregroundStyle(showInactiveAirports ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
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
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onAirportSelected(airport.icao)
                } label: {
                    HStack(spacing: 8) {
                        // ICAO + name
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(airport.icao)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                            }
                            if let name = airport.callsign {
                                Text(name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        
                        // Ground service indicator pills — match the map badge style
                        if !airport.groundServiceIndicators.isEmpty {
                            groundServiceBadges(airport.groundServiceIndicators)
                                .padding(.leading, 4)
                        }
                        // Traffic counts (pre-computed once across all pilots)
                        let counts = stats(for: airport.icao)
                        HStack(spacing: 10) {
                            trafficStat("airplane.departure", count: counts.departures)
                            trafficStat("airplane.arrival",   count: counts.arrivals)
                            trafficStat("airplane.landed",    count: counts.onGround)
                        }
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                            .imageScale(.small)
                        
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// A compact icon + count pair used in the airport row.
    @ViewBuilder
    private func trafficStat(_ systemImage: String, count: Int) -> some View {
        VStack(spacing: 1) {
            Image(systemName: systemImage)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Text("\(count)")
                .font(.system(size: 10, weight: .semibold).monospacedDigit())
                .foregroundStyle(count > 0 ? .primary : .tertiary)
        }
    }

    /// Renders coloured letter pills matching the map indicator style.
    @ViewBuilder
    private func groundServiceBadges(_ indicators: String) -> some View {
        let letterColors: [String: Color] = [
            "T": Color(red: 0.20, green: 0.60, blue: 1.00), // blue   — Tower
            "G": Color(red: 0.20, green: 0.78, blue: 0.35), // green  — Ground
            "D": Color(red: 1.00, green: 0.58, blue: 0.00), // orange — Delivery
            "A": Color(red: 0.69, green: 0.32, blue: 0.87)  // purple — ATIS
        ]
        let letters = indicators.split(separator: " ").map(String.init)
        HStack(spacing: 2) {
            ForEach(letters, id: \.self) { letter in
                Text(letter)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        letterColors[letter] ?? .accentColor,
                        in: RoundedRectangle(cornerRadius: 3)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(.black.opacity(0.4), lineWidth: 0.5)
                    )
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
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
        case .pilot: return "Callsign, route or pilot name"
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
// MARK: - Preview

#Preview {
    SearchView(
        airports: previewAirports(),
        pilots: previewPilots(),
        controllers: [],
        prefiles: [],
        onAirportSelected:    { _ in },
        onPilotSelected:      { _ in },
        onControllerSelected: { _ in }
    )
}

private func previewAirports() -> [VatglassesAirport] {
    var egll = VatglassesAirport(icao: "EGLL", latitude: 51.477, longitude: -0.461, callsign: "Heathrow", ownerRefs: [])
    egll.isActive = true
    egll.groundServiceIndicators = "T G D A"

    var egkk = VatglassesAirport(icao: "EGKK", latitude: 51.148, longitude: -0.190, callsign: "Gatwick", ownerRefs: [])
    egkk.isActive = true
    egkk.groundServiceIndicators = "T G"

    var eham = VatglassesAirport(icao: "EHAM", latitude: 52.308, longitude: 4.764, callsign: "Schiphol", ownerRefs: [])
    eham.isActive = true
    eham.groundServiceIndicators = "T"

    var egcc = VatglassesAirport(icao: "EGCC", latitude: 53.353, longitude: -2.275, callsign: "Manchester", ownerRefs: [])
    egcc.isActive = false

    return [egll, egkk, eham, egcc]
}

private func previewPilots() -> [Pilot] {
    func make(cid: Int, callsign: String, dep: String, arr: String, gs: Int) -> Pilot {
        Pilot(
            cid: cid, name: "Pilot \(cid)", callsign: callsign,
            server: "UK", pilot_rating: 1, military_rating: 0,
            latitude: 51.5, longitude: -0.3, altitude: gs > 40 ? 18000 : 0,
            groundspeed: gs, transponder: "1234", heading: 270,
            qnh_i_hg: 29.92, qnh_mb: 1013,
            logon_time: Date().addingTimeInterval(-3600), last_updated: Date(),
            flight_plan: FlightPlan(
                flight_rules: "I", aircraft: "B738", aircraft_faa: "B738",
                aircraft_short: "B738", departure: dep, arrival: arr,
                alternate: "", deptime: "1000", enroute_time: "0130",
                fuel_time: "0230", remarks: "", route: "",
                revision_id: 1, assigned_transponder: "1234"
            )
        )
    }
    return [
        make(cid: 1, callsign: "BAW1", dep: "EGLL", arr: "EDDF", gs: 450),
        make(cid: 2, callsign: "BAW2", dep: "EGLL", arr: "LFPG", gs: 380),
        make(cid: 3, callsign: "EZY1", dep: "EHAM", arr: "EGLL", gs: 420),
        make(cid: 4, callsign: "EZY2", dep: "EGKK", arr: "EGLL", gs: 10),
        make(cid: 5, callsign: "RYR1", dep: "EGLL", arr: "EGKK", gs: 5),
    ]
}

