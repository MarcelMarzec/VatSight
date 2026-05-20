//
//  PilotDetailsView.swift
//  VatSight
//

import SwiftUI

struct PilotDetailsView: View {
    let pilot: Pilot
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(pilot.callsign)
                                    .font(.largeTitle.bold())
                                
                                Spacer()
                                
                                Button {
                                    dismiss()
                                }label: {
                                    Image(systemName: "xmark")
                                        .font(.title2)
                                }.foregroundColor(.white)
                            }
                            
                            Text(verbatim: "\(pilot.cid) | \(pilot.name)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }

                    HStack {
                        metric("Altitude", "\(pilot.altitude) ft")
                        Spacer()
                        metric("Speed", "\(pilot.groundspeed) kt")
                        Spacer()
                        metric("Heading", "\(pilot.heading)°")
                        Spacer()
                        metric("Transponder", pilot.transponder, highlightEmergency: pilot.isEmergency)
                    }

                    if let fp = pilot.flight_plan {
                        sectionTitle("Flight Plan")

                        HStack {
                            Text(fp.departure)
                                .font(.title3.bold())
                            LabelledDivider(label: fp.enroute_time)
                            Text(fp.arrival)
                                .font(.title3.bold())
                        }

                        HStack {
                            Spacer()
                            metric("Dep Time", fp.deptime)
                            Spacer()
                            metric("Fuel Time", fp.fuel_time)
                            Spacer()
                            metric("Logon Time", pilot.logon_time)
                            Spacer()
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
                        Text(pilot.last_updated)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 24)
                }
                .padding()
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .frame(maxWidth: .infinity, alignment: .leading)
            .font(.headline)
    }

    private func metric(_ title: String, _ value: String, highlightEmergency: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .foregroundStyle(highlightEmergency ? .red : .primary)
        }
    }
}

struct LabelledDivider: View {

    let label: String
    let horizontalPadding: CGFloat
    let color: Color

    init(label: String, horizontalPadding: CGFloat = 8, color: Color = .gray) {
        self.label = label
        self.horizontalPadding = horizontalPadding
        self.color = color
    }

    var body: some View {
        HStack {
            ZStack {
                line
                Text(label)
                    .foregroundColor(color)
                    .offset(x: 0, y: 10)
                Text("Enroute Time")
                    .foregroundColor(color)
                    .offset(x: 0, y: -12)
            }
        }
    }

    var line: some View {
        VStack { Divider().background(color) }
            .padding(horizontalPadding)
    }
}

#Preview {
    PilotDetailsView(pilot: Pilot(cid: 1234567, name: "Kennedy Steve KJFK", callsign: "DAL1", server: "USA-EAST", pilot_rating: 0, military_rating: 0, latitude: 40.64222, longitude: -73.76981, altitude: 12, groundspeed: 0, transponder: "1000", heading: 44, qnh_i_hg: 29.92, qnh_mb: 1013, logon_time: "1970-01-01T00:00:00.000000Z", last_updated: "1970-01-01T00:00:00.000000Z", flight_plan: fp(flight_rules: "I", aircraft: "B764/H-SDE3FGHIM3RWXY/LB1", aircraft_faa: "B764/L", aircraft_short: "B764", departure: "KJFK", arrival: "EGLL", alternate: "EGBB", deptime: "0000", enroute_time: "0615", fuel_time: "0745", remarks: "/V/", route: "GREKI DCT JUDDS DCT MARTN DCT BAREE DCT NEEKO NATX LIMRI NATX XETBO DCT EVRIN DCT INFEC DCT JETZI DCT OGLUN DCT OCTIZ P2 SIRIC SIRI1H", revision_id: 1, assigned_transponder: "3456")))
}
