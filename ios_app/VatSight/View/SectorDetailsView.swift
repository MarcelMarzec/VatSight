//
//  SectorDetailsView.swift
//  VatSight
//

import SwiftUI
import SwiftData

struct SectorDetailsView: View {
    let sector: VatglassesSector
    let controller: Controllers
    @Binding var headerHeight: CGFloat

    @Environment(\.dismiss) private var dismiss
    @Environment(PreferencesManager.self) private var prefsManager

    private var isTracked: Bool {
        prefsManager.userPrefs.trackedCIDs.contains(controller.cid)
    }

    var body: some View {
        NavigationStack {
            headerSection
            List {
                controllerDetailsSection
            }
            .scrollDisabled(true)
            .textSelection(.enabled)
        }
    }

    // MARK: - Sections

    var headerSection: some View {
        VStack(alignment: .leading) {
            callsignRow
            Text(controller.frequency)
                .font(.title2).padding(.top, 8)
            HStack {
                Text(sector.properties?.name ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("|").font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(sector.properties?.groupName ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            atisText
        }
        .padding()
        .textSelection(.enabled)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { newHeight in
            guard newHeight > 0 else { return }
            // Add drag indicator height (~20pt)
            headerHeight = newHeight + 20
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
                HStack {
                    Button {
                        if isTracked {
                            prefsManager.removeTrackedCID(controller.cid)
                        } else {
                            prefsManager.addTrackedCID(controller.cid)
                        }
                    } label: {
                        Image(systemName: isTracked ? "star.fill" : "star")
                            .font(.title2)
                    }
                    .foregroundColor(isTracked ? .green : .primary)
                    VStack(alignment: .leading) {
                        Text(controller.name).font(.headline).foregroundColor(.primary)
                        Text(String(controller.cid)).font(.subheadline).foregroundColor(.secondary)
                    }
                }
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
                    Text(controller.name).font(.subheadline).foregroundColor(.secondary)
                    Text("(\(String(controller.cid)))").font(.subheadline).foregroundColor(.secondary)
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
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
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
        VatsimRatingsRegistry.shared.controllerRatings = [
            5: ControllerRatings(id: 5, short: "C1", long: "Controller 1")
        ]
        VatsimRatingsRegistry.shared.facilities = [
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
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserPreferencesModel.self, configurations: config)
    let manager = PreferencesManager(context: ModelContext(container))

    SectorDetailsView(sector: sector, controller: controller, headerHeight: .constant(0))
        .environment(manager)
}
