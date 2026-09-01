//
//  PilotDetailsView.swift
//  VatSight
//

import SwiftUI
import SwiftData

struct PilotDetailsView: View {
    let pilot: Pilot
    var airportName: ((String) -> String?)? = nil
    var onAirportSelected: ((String) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(PreferencesManager.self) private var prefsManager

    private var isTracked: Bool {
        prefsManager.userPrefs.trackedCIDs.contains(pilot.cid)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    VStack(alignment: .leading) {
                        HStack(alignment: .center, spacing: 12) {
                            HStack(alignment: .center, spacing: 12) {
                                Text(pilot.callsign)
                                    .font(.largeTitle.bold())
                                
                                Divider()
                                    .frame(height: 28)
                                
                                Text(pilot.flight_plan?.aircraft_short ?? "")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.title)
                            }
                            .foregroundColor(.primary)
                        }
                        Button {
                            if isTracked {
                                prefsManager.removeTrackedCID(pilot.cid)
                            } else {
                                prefsManager.addTrackedCID(pilot.cid)
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Text(verbatim: "\(pilot.name) (\(pilot.cid))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Image(systemName: isTracked ? "star.fill" : "star")
                                .font(.subheadline)
                                .foregroundColor(isTracked ? .green : .primary)
                            
                        }
                        
                    }
                    
                    MetricContainer(metrics: [
                        ("Altitude", "\(pilot.altitude) ft", false),
                        ("Speed", "\(pilot.groundspeed) kt", false),
                        ("Heading", "\(pilot.heading)°", false),
                        ("Transponder", pilot.transponder, pilot.isEmergency)
                    ])
                    
                    if let fp = pilot.flight_plan {
                        sectionTitle(fp.flight_rules == "V" ? "VFR Flight Plan" : fp.flight_rules == "I" ? "IFR Flight Plan" : "Flight Plan")
                        
                        HStack {
                            ICAOChip(
                                type: "Departure",
                                typeImage: "airplane.departure",
                                icao: fp.departure,
                                name: airportName?(fp.departure),
                                onTap: onAirportSelected.map { action in
                                    { action(fp.departure); dismiss() }
                                }
                            )
                            Spacer()
                            ICAOChip(
                                type: "Arrival",
                                typeImage: "airplane.arrival",
                                icao: fp.arrival,
                                name: airportName?(fp.arrival),
                                onTap: onAirportSelected.map { action in
                                    { action(fp.arrival); dismiss() }
                                }
                            )
                            Spacer()
                            ICAOChip(
                                type: "Alternate",
                                typeImage: "airplane.cloud",
                                icao: fp.alternate,
                                name: airportName?(fp.alternate),
                                onTap: onAirportSelected.map { action in
                                    { action(fp.alternate); dismiss() }
                                }
                            )
                        }
                        
                        MetricContainer(metrics: [
                            ("Logon Time", pilot.logon_timeFormatted, false),
                            ("Dep Time", fp.deptimeFormatted, false),
                            ("Enroute Time", fp.enroute_timeFormatted, false),
                            ("Fuel Time", fp.fuel_timeFormatted, false)
                        ])
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Aircraft Type")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(fp.aircraft)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Route")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(fp.route)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Remarks")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(fp.remarks)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        Text("Flight plan not filed.")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    VStack(spacing: 4) {
                        Text("Last Updated")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(pilot.last_updatedFormatted)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer(minLength: 24)
                }
                .padding()
            }
            .textSelection(.enabled)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .frame(maxWidth: .infinity, alignment: .leading)
            .font(.headline)
    }
}

private struct MetricContainer: View {
    let metrics: [(String, String, Bool)]
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(metrics.enumerated()), id: \.offset) { index, metric in
                if index > 0 {
                    Divider()
                        .padding(.vertical, 8)
                }
                VStack(spacing: 4) {
                    Text(metric.0)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(metric.1)
                        .foregroundStyle(metric.2 ? .red : .primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
            }
        }
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct ICAOChip: View {
    let type: String
    let typeImage: String
    let icao: String
    let name: String?
    let onTap: (() -> Void)?
    
    var body: some View {
        VStack {
            HStack {
                Image(systemName: typeImage).imageScale(.small).foregroundColor(.secondary)
                Text(type).font(.caption).foregroundColor(.secondary)
            }
            VStack {
                Text(icao)
                if let name {
                    Text(name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 100)
                }
            }
        }
        .onTapGesture {
            if onTap != nil {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            onTap?()
        }
        .opacity(onTap != nil ? 1 : 1)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserPreferencesModel.self, configurations: config)
    let manager = PreferencesManager(context: ModelContext(container))

    PilotDetailsView(
        pilot: Pilot(cid: 1234567, name: "Kennedy Steve KJFK", callsign: "DAL1", server: "USA-EAST", pilot_rating: 0, military_rating: 0, latitude: 40.64222, longitude: -73.76981, altitude: 12, groundspeed: 0, transponder: "1000", heading: 44, qnh_i_hg: 29.92, qnh_mb: 1013, logon_time: Date.now, last_updated: Date.now, flight_plan: FlightPlan(flight_rules: "I", aircraft: "B764/H-SDE3FGHIM3RWXY/LB1", aircraft_faa: "B764/L", aircraft_short: "B764", departure: "KJFK", arrival: "EGLL", alternate: "EGBB", deptime: "0000", enroute_time: "0615", fuel_time: "0745", remarks: "/V/", route: "GREKI DCT JUDDS DCT MARTN DCT BAREE DCT NEEKO NATX LIMRI NATX XETBO DCT EVRIN DCT INFEC DCT JETZI DCT OGLUN DCT OCTIZ P2 SIRIC SIRI1H", revision_id: 1, assigned_transponder: "3456")),
        airportName: { icao in
            ["KJFK": "New York", "EGLL": "Heathrow", "EGBB": "Birmingham Intl"][icao]
        }
    )
    .environment(manager)
}
