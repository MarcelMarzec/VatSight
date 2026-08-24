//
//  AirportDetailsTrafficView.swift
//  VatSight
//

import SwiftUI

struct AirportDetailsTrafficView: View {
    let airport: VatglassesAirport
    let traffic: AirportTraffic
    /// Called when the user taps the back button.
    var onBack: (() -> Void)? = nil
    /// Called when the user taps a pilot row; passes the pilot's CID and coordinate.
    var onPilotSelected: ((Int, Double, Double) -> Void)? = nil

    enum TrafficTab: String, CaseIterable {
        case departures = "Departures"
        case onGround   = "On Ground"
        case arrivals   = "Arrivals"
    }

    @State private var selectedTab: TrafficTab = .departures

    // MARK: - Derived lists

    private var departures: [PilotOrPrefile] {
        traffic.airborneDepartures.map { .pilot($0) } +
        traffic.groundDepartures.map { .pilot($0) } +
        traffic.prefileDepartures.map { .prefile($0) }
    }

    private var arrivals: [PilotOrPrefile] {
        traffic.airborneArrivals.map { .pilot($0) } +
        traffic.groundArrivals.map { .pilot($0) } +
        traffic.prefileArrivals.map { .prefile($0) }
    }

    private var onGround: [PilotOrPrefile] {
        traffic.groundDepartures.map { .pilot($0) } +
        traffic.groundArrivals.map { .pilot($0) }
    }

    private var currentList: [PilotOrPrefile] {
        switch selectedTab {
        case .departures: return departures
        case .onGround:   return onGround
        case .arrivals:   return arrivals
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    onBack?()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.subheadline)
                }
                .foregroundColor(.white)

                Spacer()

                VStack(spacing: 2) {
                    Text(airport.icao)
                        .font(.title3.bold())
                    if let name = airport.callsign {
                        Text(name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
                // Balance the back button
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.subheadline)
                .hidden()
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 8)

            // Traffic tab picker
            HStack(spacing: 8) {
                ForEach(TrafficTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: tabIcon(tab))
                                .font(.system(size: 15))
                            Text(tabLabel(tab))
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedTab == tab ? Color.white.opacity(0.2) : Color.white.opacity(0.07))
                        .foregroundStyle(selectedTab == tab ? Color.primary : Color.secondary)
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            // List
            if currentList.isEmpty {
                Spacer()
                Text("No \(selectedTab.rawValue.lowercased()) at \(airport.icao).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List(currentList) { item in
                    TrafficRow(item: item)
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if case .pilot(let pilot) = item {
                                onPilotSelected?(pilot.cid, pilot.latitude, pilot.longitude)
                            }
                        }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    // MARK: - Helpers

    private func tabIcon(_ tab: TrafficTab) -> String {
        switch tab {
        case .departures: return "airplane.departure"
        case .onGround:   return "airplane.landed"
        case .arrivals:   return "airplane.arrival"
        }
    }

    private func tabLabel(_ tab: TrafficTab) -> String {
        switch tab {
        case .departures: return "Departures (\(departures.count))"
        case .onGround:   return "On Ground (\(onGround.count))"
        case .arrivals:   return "Arrivals (\(arrivals.count))"
        }
    }
}

// MARK: - PilotOrPrefile

/// Unified wrapper so both Pilot and Prefiles can share a single list.
enum PilotOrPrefile: Identifiable {
    case pilot(Pilot)
    case prefile(Prefiles)

    var id: String {
        switch self {
        case .pilot(let p):   return "pilot-\(p.cid)"
        case .prefile(let p): return "prefile-\(p.cid)"
        }
    }
}

// MARK: - TrafficRow

private struct TrafficRow: View {
    let item: PilotOrPrefile

    var body: some View {
        switch item {
        case .pilot(let pilot):
            pilotRow(pilot)
        case .prefile(let prefile):
            prefileRow(prefile)
        }
    }

    @ViewBuilder
    private func pilotRow(_ pilot: Pilot) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(pilot.callsign)
                        .font(.subheadline.bold())
                    if let fp = pilot.flight_plan {
                        Text(fp.aircraft_short)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                if let fp = pilot.flight_plan {
                    Text("\(fp.departure) → \(fp.arrival)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(pilot.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if pilot.groundspeed > 0 {
                    Text("\(pilot.groundspeed) kt")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                Text("FL\(pilot.altitude / 100)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .imageScale(.small)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func prefileRow(_ prefile: Prefiles) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(prefile.callsign)
                        .font(.subheadline.bold())
                    if let fp = prefile.flight_plan {
                        Text(fp.aircraft_short)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text("Prefiled")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(Capsule())
                }
                if let fp = prefile.flight_plan {
                    Text("\(fp.departure) → \(fp.arrival)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(prefile.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        // Prefiles have no live position; don't highlight as tappable
        .foregroundStyle(.primary.opacity(0.7))
    }
}

// MARK: - Preview

#Preview {
    AirportDetailsTrafficView(
        airport: VatglassesAirport(
            icao: "EGLL",
            latitude: 51.4775,
            longitude: -0.4614,
            callsign: "London Heathrow",
            ownerRefs: ["LON_CTR"],
            runways: ["09L", "09R", "27L", "27R"]
        ),
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
            airborneArrivals: [
                Pilot(
                    cid: 2222222, name: "Preview Pilot 2", callsign: "EZY456",
                    server: "UK", pilot_rating: 0, military_rating: 0,
                    latitude: 51.3, longitude: -0.8, altitude: 8000,
                    groundspeed: 220, transponder: "5678", heading: 90,
                    qnh_i_hg: 29.92, qnh_mb: 1013,
                    logon_time: Date().addingTimeInterval(-2700),
                    last_updated: Date(),
                    flight_plan: FlightPlan(
                        flight_rules: "I", aircraft: "A320", aircraft_faa: "A320",
                        aircraft_short: "A320", departure: "LEMD", arrival: "EGLL",
                        alternate: "EGKK", deptime: "0730", enroute_time: "0210",
                        fuel_time: "0315", remarks: "", route: "UN857 BRAIN",
                        revision_id: 1, assigned_transponder: "5678"
                    )
                )
            ],
            groundDepartures: [
                Pilot(
                    cid: 4444444, name: "Preview Pilot 4", callsign: "IBE301",
                    server: "UK", pilot_rating: 0, military_rating: 0,
                    latitude: 51.4775, longitude: -0.4614, altitude: 80,
                    groundspeed: 5, transponder: "3456", heading: 270,
                    qnh_i_hg: 29.92, qnh_mb: 1013,
                    logon_time: Date().addingTimeInterval(-1200),
                    last_updated: Date(),
                    flight_plan: FlightPlan(
                        flight_rules: "I", aircraft: "A321", aircraft_faa: "A321",
                        aircraft_short: "A321", departure: "EGLL", arrival: "LEMD",
                        alternate: "LEBB", deptime: "1015", enroute_time: "0215",
                        fuel_time: "0330", remarks: "", route: "WOBUN M604 HARDY",
                        revision_id: 1, assigned_transponder: "3456"
                    )
                )
            ],
            groundArrivals: [
                Pilot(
                    cid: 5555555, name: "Preview Pilot 5", callsign: "KLM642",
                    server: "UK", pilot_rating: 0, military_rating: 0,
                    latitude: 51.4775, longitude: -0.4614, altitude: 60,
                    groundspeed: 12, transponder: "7890", heading: 90,
                    qnh_i_hg: 29.92, qnh_mb: 1013,
                    logon_time: Date().addingTimeInterval(-9000),
                    last_updated: Date(),
                    flight_plan: FlightPlan(
                        flight_rules: "I", aircraft: "B789", aircraft_faa: "B789",
                        aircraft_short: "B789", departure: "EHAM", arrival: "EGLL",
                        alternate: "EGKK", deptime: "0800", enroute_time: "0045",
                        fuel_time: "0130", remarks: "", route: "REDFA L612 BRAIN",
                        revision_id: 1, assigned_transponder: "7890"
                    )
                )
            ],
            prefileDepartures: [
                Prefiles(
                    cid: 6666666, name: "Preview Prefile 1", callsign: "TOM001",
                    flight_plan: FlightPlan(
                        flight_rules: "I", aircraft: "B738", aircraft_faa: "B738",
                        aircraft_short: "B738", departure: "EGLL", arrival: "LEMG",
                        alternate: "LEMD", deptime: "1100", enroute_time: "0245",
                        fuel_time: "0400", remarks: "", route: "WOBUN UN857 GERLY",
                        revision_id: 1, assigned_transponder: "2000"
                    ),
                    last_updated: Date()
                )
            ],
            prefileArrivals: [
                Prefiles(
                    cid: 7777777, name: "Preview Prefile 2", callsign: "RYR5TG",
                    flight_plan: FlightPlan(
                        flight_rules: "I", aircraft: "B738", aircraft_faa: "B738",
                        aircraft_short: "B738", departure: "EIDW", arrival: "EGLL",
                        alternate: "EGKK", deptime: "1030", enroute_time: "0110",
                        fuel_time: "0200", remarks: "", route: "LIPGO L15 BRAIN",
                        revision_id: 1, assigned_transponder: "2000"
                    ),
                    last_updated: Date()
                )
            ]
        )
    )
}
