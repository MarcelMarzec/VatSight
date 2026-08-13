//
//  SectorDetailsView.swift
//  VatSight
//

import SwiftUI

struct SectorDetailsView: View {
    let sector: VatglassesSector
    let controller: Controllers

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                headerSection
                controllerDetailsSection
            }
        }
    }

    // MARK: - Sections

    var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                callsignRow
                Text(controller.frequency)
                    .font(.title2)
                atisText
            }
        }
    }

    private var controllerDetailsSection: some View {
        Section {
            LabeledContent {
                VStack(alignment: .trailing) {
                    Text(controller.logon_timeFormatted)
                    Text(controller.onlineDuration)
                }
            } label: {
                Text(controller.name)
                Text(String(controller.cid))
            }
            LabeledContent("Rating", value: ratingLabel)
            LabeledContent("Facility", value: facilityLabel)
            LabeledContent("Server", value: controller.server)
        } header: {
            Text("Controller Details")
        } footer: {
            HStack {
                Spacer()
                VStack {
                    Text("Last Updated")
                    Text(controller.last_updatedFormatted)
                }
                Spacer()
            }
        }
    }

    // MARK: - Helpers

    var callsignRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(controller.callsign)
                    .font(.title2.bold())
                HStack {
                    Text(sector.properties?.name ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("|")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(sector.properties?.groupName ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.title)
            }
            .foregroundColor(.white)
        }
    }

    @ViewBuilder
    private var atisText: some View {
        if let atis = controller.text_atis, !atis.isEmpty {
            Text(atis.joined(separator: "\n"))
        }
    }

    private var ratingLabel: String {
        if let info = controller.ratingInfo {
            return info.short + " | " + info.long
        }
        return String(controller.rating)
    }

    private var facilityLabel: String {
        if let info = controller.facilityInfo {
            return info.short + " | " + info.long
        }
        return String(controller.facility)
    }
}

#Preview {
    let _ = {
        VatsimRatings.shared.controllerRatings = [
            5: ControllerRatings(id: 5, short: "C1", long: "Controller 1")
        ]
        VatsimRatings.shared.facilities = [
            6: Facilities(id: 6, short: "CTR", long: "Centre")
        ]
    }()

    let controller = Controllers(
        cid: 1234567,
        name: "John Smith",
        callsign: "EDYY_E_CTR",
        frequency: "134.420",
        facility: 6,
        rating: 5,
        server: "EU-1",
        visual_range: 500,
        text_atis: [
            "Maastricht UAC East online",
            "Online until 23:00z"
        ],
        logon_time: Date(),
        last_updated: Date()
    )
    let sector = VatglassesSector(
        id: "ed/Solling Low",
        ownerRefs: ["ed/EDYY"],
        frequency: "134.420",
        geometry: SectorGeometry(type: "Polygon", coordinates: [[[[10.0, 51.0], [10.5, 51.5], [11.0, 51.0], [10.0, 51.0]]]]),
        properties: SectorProperties(min: 0, max: 24500, name: "Solling Low", groupName: "Maastricht", color: nil),
        isActive: true,
        activeOwnerColorHex: "#0040FF",
        activeOwnerRef: "ed/EDYY",
        activeController: controller
    )
    SectorDetailsView(sector: sector, controller: controller)
}
