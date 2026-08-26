//
//  AirportDetailsView.swift
//  VatSight
//

import SwiftUI
import SwiftData

struct AirportDetailsView: View {
    let airport: VatglassesAirport
    let controllers: [Controllers]
    let atis: [ATIS]
    let traffic: AirportTraffic?
    /// Resolves a vatglasses-defined human label for a VATSIM callsign, or returns nil to use fallback.
    var labelResolver: ((String) -> String?)? = nil
    /// Called when the user selects a pilot from the traffic detail view.
    var onPilotSelected: ((Int, Double, Double) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var metar: String? = nil
    @State private var metarLoading = true
    @State private var showingTraffic = false

    var body: some View {
        if showingTraffic, let traffic {
            // MARK: Traffic view
            AirportDetailsTrafficView(
                airport: airport,
                traffic: traffic,
                onBack: { withAnimation { showingTraffic = false } },
                onPilotSelected: { cid, lat, lon in
                    dismiss()
                    onPilotSelected?(cid, lat, lon)
                }
            )
            .transition(.move(edge: .trailing))
        } else {
            // MARK: Main view
            mainContent
                .transition(.move(edge: .leading))
        }
    }

    // MARK: - Main content

    @ViewBuilder
    private var mainContent: some View {
        VStack {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(airport.icao)
                            .font(.title.bold())
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.title)
                        }
                        .foregroundColor(.primary)
                    }
                    if let name = airport.callsign {
                        Text(name)
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            if let traffic {
                Section {
                    HStack {
                        trafficMetric(
                            "Departures",
                            count: traffic.totalDepartures,
                            systemImage: "airplane.departure"
                        )
                        Spacer()
                        trafficMetric(
                            "On Ground",
                            count: traffic.totalOnGround,
                            systemImage: "airplane.landed"
                        )
                        Spacer()
                        trafficMetric(
                            "Arrivals",
                            count: traffic.totalArrivals,
                            systemImage: "airplane.arrival"
                        )
                    }
                    .padding(.vertical, 4)

                    let totalPrefiles = traffic.prefileDepartures.count + traffic.prefileArrivals.count
                    HStack {
                        Text("Includes \(totalPrefiles) prefiled flight plan\(totalPrefiles == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("More Details >") {
                            withAnimation { showingTraffic = true }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                }
            }
        }
        .padding()
        .textSelection(.enabled)

        List {
            // Controllers section
            Section("Online Controllers") {
                if controllers.isEmpty {
                    Text("No controllers online at this airport.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(controllers) { controller in
                        ControllerRow(controller: controller, airportICAO: airport.icao, labelResolver: labelResolver)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                }

            // ATIS section
            let atisStations = atis.filter {
                $0.callsign.uppercased().hasPrefix(airport.icao.uppercased() + "_")
                && $0.callsign.uppercased().contains("ATIS")
            }
            if !atisStations.isEmpty {
                    ForEach(atisStations) { station in
                        VStack(alignment: .leading) {
                            Text(atisPositionLabel(for: station.callsign)).font(.subheadline).foregroundColor(.secondary)
                            HStack {
                                Text(station.callsign)
                                    .font(.headline)
                                Spacer()
                                if let code = station.atis_code {
                                    Text("Info \(code)")
                                        .font(.headline)
                                }
                                Spacer()
                                Text(station.frequency)
                                    .font(.headline)
                            }
                            Text("\(station.name) (\(String(station.cid)))")
                                .font(.subheadline)
                                .foregroundStyle(Color.secondary)
                            if let lines = station.text_atis {
                                Text(lines.joined(separator: "\n"))
                                    .font(.default)
                                    .foregroundStyle(.primary)
                                    .padding(.top, 1)
                            }
                        }
                    }
                }
            }

            // METAR section
            Section("METAR") {
                if metarLoading {
                    Text("Loading...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if let metar {
                    Text(metar)
                        .font(.subheadline.monospaced())
                } else {
                    Text("No METAR available.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .textSelection(.enabled)
        .task {
            await fetchMetar()
        }
    }

    // MARK: - Helpers

    private func atisPositionLabel(for callsign: String) -> String {
        let upper = callsign.uppercased()
        let icao = airport.icao.uppercased()
        if upper.hasPrefix(icao + "_D_") { return "Departure Information" }
        if upper.hasPrefix(icao + "_A_") { return "Arrival Information" }
        return "Airport Information"
    }

    private func fetchMetar() async {
        guard let url = URL(string: "https://metar.vatsim.net/\(airport.icao)") else {
            metarLoading = false
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            metar = text?.isEmpty == false ? text : nil
        } catch {
            metar = nil
        }
        metarLoading = false
    }

    @ViewBuilder
    private func trafficMetric(
        _ title: String,
        count: Int,
        systemImage: String
    ) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("\(count)")
                .font(.title2.bold())
        }
    }
}

private struct ControllerRow: View {
    let controller: Controllers
    let airportICAO: String
    var labelResolver: ((String) -> String?)? = nil

    @Environment(PreferencesManager.self) private var prefsManager

    private var isTracked: Bool {
        prefsManager.userPrefs.trackedCIDs.contains(controller.cid)
    }

    var positionLabel: String {
        if let resolved = labelResolver?(controller.callsign) { return resolved }
        let upper = controller.callsign.uppercased()
        if upper.hasSuffix("_DEL") { return "Delivery" }
        if upper.hasSuffix("_GND") { return "Ground" }
        if upper.hasSuffix("_TWR") { return "Tower" }
        if upper.hasSuffix("_APP") { return "Approach" }
        if upper.hasSuffix("_DEP") { return "Departure" }
        if upper.hasSuffix("_CTR") { return "Centre" }
        return "Controller"
    }

    var isTopdown: Bool {
        !controller.callsign.uppercased().hasPrefix(airportICAO.uppercased() + "_")
    }

    var body: some View {
            VStack(alignment: .leading) {
                    Text(positionLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                HStack {
                    Text(controller.callsign)
                        .font(.headline)
                    Spacer()
                    Text(controller.frequency)
                        .font(.headline)
                }
                
                HStack(spacing: 4) {
                        Text(controller.name + " (\(String(controller.cid)))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    
                        Button {
                            if isTracked {
                                prefsManager.removeTrackedCID(controller.cid)
                            } else {
                                prefsManager.addTrackedCID(controller.cid)
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Image(systemName: isTracked ? "star.fill" : "star")
                                .font(.subheadline)
                        }
                        .foregroundColor(isTracked ? .green : .secondary)
                    }
                
                if let atis = controller.text_atis, !atis.isEmpty {
                    Text(atis.joined(separator: "\n"))
                        .font(.default)
                        .foregroundColor(.primary)
                        .padding(.top, 1)
                }
            }
        }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserPreferencesModel.self, configurations: config)
    let manager = PreferencesManager(context: ModelContext(container))

    AirportDetailsView(
        airport: VatglassesAirport(
            icao: "EGLL",
            latitude: 51.4775,
            longitude: -0.4614,
            callsign: "London Heathrow",
            ownerRefs: ["LON_CTR"],
            runways: ["09L", "09R", "27L", "27R"]
        ),
        controllers: [
            Controllers(
                cid: 1234567,
                name: "John Smith",
                callsign: "EGLL_TWR",
                frequency: "118.500",
                facility: 4,
                rating: 5,
                server: "UK",
                visual_range: 50,
                text_atis: [
                    "Heathrow Tower - DLC EGLL",
                    "Feedback to xxxx.xxx.xxxx",
                    "Some other Random Stuff..."
                ],
                logon_time: Date(),
                last_updated: Date()
            )
        ],
        atis: [
            ATIS(
                cid: 9876543,
                name: "Hans Zimmer",
                callsign: "EGLL_ATIS",
                frequency: "113.750",
                facility: 1,
                rating: 1,
                server: "UK",
                visual_range: 0,
                atis_code: "F",
                text_atis: [
                    "LONDON HEATHROW ATIS INFORMATION FOXTROT",
                    "0950Z. WIND 270/10KT. VISIBILITY 9999.",
                    "FEW018. TEMPERATURE 16 DEW POINT 10.",
                    "QNH 1013. EXPECT ILS APPROACH RUNWAY 27L.",
                    "ACKNOWLEDGE INFORMATION FOXTROT ON FIRST CONTACT."
                ],
                logon_time: Date().addingTimeInterval(-3600),
                last_updated: Date()
            )
        ],
        traffic: AirportTraffic(
            airborneDepartures: [
                Pilot(
                    cid: 1111111, name: "Preview Pilot 1", callsign: "BAW123",
                    server: "UK", pilot_rating: 1, military_rating: 0,
                    latitude: 51.5, longitude: -0.3, altitude: 15000,
                    groundspeed: 350, transponder: "1234", heading: 270,
                    qnh_i_hg: 29.92, qnh_mb: 1013,
                    logon_time: Date().addingTimeInterval(-5400),
                    last_updated: Date(),
                    flight_plan: FlightPlan(
                        flight_rules: "I", aircraft: "B738", aircraft_faa: "B738",
                        aircraft_short: "B738", departure: "EGLL", arrival: "EDDF",
                        alternate: "EDDM", deptime: "0900", enroute_time: "0130",
                        fuel_time: "0230", remarks: "", route: "WOTAN L9 KONAN",
                        revision_id: 1, assigned_transponder: "1234"
                    )
                )
            ],
            airborneArrivals: [],
            groundDepartures: [],
            groundArrivals: [],
            prefileDepartures: [],
            prefileArrivals: []
        )
    )
    .environment(manager)
}
