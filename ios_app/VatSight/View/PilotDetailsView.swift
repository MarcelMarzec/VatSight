//
//  PilotDetailsView.swift
//  VatSight
//
//  Created by Marcel Marzec on 12/05/2026.
//

import SwiftUI
import SwiftData

struct PilotDetailsView: View {
    @Binding var selectedPilot: Pilot
    @Binding var isShowingSheet: Bool
    
    var body: some View {
        VStack {
            HStack {
                HStack {
                    Text("\(selectedPilot.callsign)")
                        .font(.title)
                    Text("\(String(selectedPilot.id)) \(selectedPilot.name)")
                        .padding(3)
                        .font(.subheadline)
                        .background(Color.secondary)
                        .foregroundColor(.white)
                        .cornerRadius(3)
                }
                Spacer()
            }.padding()
            
            if selectedPilot.flight_plan != nil {
                Text("Flight Plan").frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Text(selectedPilot.flight_plan?.departure ?? "N/A")
                        .font(.title2)
                    LabelledDivider(label: selectedPilot.flight_plan?.enroute_time ?? "")
                    Text(selectedPilot.flight_plan?.arrival ?? "N/A")
                        .font(.title2)
                }
            } else {
                HStack {
                    Text("Flight Plan not filed.")
                    Spacer()
                }
            }
            Spacer()
        }.padding()
    }
}

struct LabelledDivider: View {

    let label: String
    let horizontalPadding: CGFloat
    let color: Color

    init(label: String, horizontalPadding: CGFloat = 20, color: Color = .gray) {
        self.label = label
        self.horizontalPadding = horizontalPadding
        self.color = color
    }

    var body: some View {
        HStack {
            ZStack {
                line
                Text(label).foregroundColor(color).offset(x: 0, y: 10)
                Text("Enroute Time").foregroundColor(color).offset(x: 0, y: -12)
            }
        }
    }

    var line: some View {
        VStack { Divider().background(color) }.padding(horizontalPadding)
    }
}

#Preview {
    PilotDetailsView(selectedPilot: .constant(Pilot(cid: 1234567, name: "Kennedy Steve KJFK", callsign: "DAL1", server: "USA-EAST", pilot_rating: 0, military_rating: 0, latitude: 40.64222, longitude: -73.76981, altitude: 12, groundspeed: 0, transponder: "3456", heading: 44, qnh_i_hg: 29.92, qnh_mb: 1013, logon_time: "1970-01-01T00:00:00.000000Z", last_updated: "1970-01-01T00:00:00.000000Z", flight_plan: fp(flight_rules: "I", aircraft: "B764/H-SDE3FGHIM3RWXY/LB1", aircraft_faa: "B764/L", aircraft_short: "B764", departure: "KJFK", arrival: "EGLL", alternate: "EGBB", deptime: "0000", enroute_time: "0615", fuel_time: "0745", remarks: "/V/", route: "GREKI DCT JUDDS DCT MARTN DCT BAREE DCT NEEKO NATX LIMRI NATX XETBO DCT EVRIN DCT INFEC DCT JETZI DCT OGLUN DCT OCTIZ P2 SIRIC SIRI1H", revision_id: 1, assigned_transponder: "3456")) ), isShowingSheet: .constant(false))
}
