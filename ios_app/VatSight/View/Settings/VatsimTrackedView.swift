//
//  VatsimTrackedView.swift
//  VatSight
//

import SwiftUI
import SwiftData

struct VatsimTrackedView: View {
    @Environment(PreferencesManager.self) private var prefsManager
    @EnvironmentObject private var radarViewModel: RadarViewModel

    @State private var yourCIDInputText = ""
    @State private var newTrackedCIDText = ""
    @FocusState private var focusedField: Field?

    private enum Field { case yourCID, newTracked }

    /// The saved CID expressed as the same string the text field would show.
    private var savedCIDText: String {
        let cid = prefsManager.userPrefs.vatsimCID
        return cid > 0 ? String(cid) : ""
    }

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("Your Vatsim CID", text: $yourCIDInputText)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .yourCID)
                    Spacer()
                    Button("Save") {
                        if let cid = Int(yourCIDInputText), cid > 0 {
                            prefsManager.updateCID(cid)
                        } else if yourCIDInputText.isEmpty {
                            prefsManager.updateCID(0)
                        }
                        focusedField = nil
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                    .disabled(yourCIDInputText == savedCIDText)
                }
            } header: {
                Text("Your CID")
            } footer: {
                Text("Your CID is shown highlighted on the map.")
            }

            Section("Add CID") {
                HStack {
                    TextField("Vatsim CID", text: $newTrackedCIDText)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .newTracked)
                    Spacer()
                    Button("Add") {
                        if let cid = Int(newTrackedCIDText), cid > 0 {
                            prefsManager.addTrackedCID(cid)
                            newTrackedCIDText = ""
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                        focusedField = nil
                    }
                    .disabled(Int(newTrackedCIDText) == nil || newTrackedCIDText.isEmpty)
                }
            }

            Section("Tracked CIDs") {
                if prefsManager.userPrefs.trackedCIDs.isEmpty {
                    Text("No tracked CIDs.")
                        .foregroundStyle(.secondary)
                }

                ForEach(prefsManager.userPrefs.trackedCIDs, id: \.self) { cid in
                    let pilot = radarViewModel.pilots.first { $0.cid == cid }
                    let controller = radarViewModel.controllers.first { $0.cid == cid }
                    let isOnline = pilot != nil || controller != nil
                    TrackedCIDRow(cid: cid, pilot: pilot, controller: controller)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard isOnline else { return }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            prefsManager.pendingNavigateToCID = cid
                        }
                }
                .onDelete { offsets in
                    offsets.forEach { prefsManager.removeTrackedCID(prefsManager.userPrefs.trackedCIDs[$0]) }
                }
            }
        }
        .navigationTitle("Track Vatsim CIDs")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let cid = prefsManager.userPrefs.vatsimCID
            yourCIDInputText = cid > 0 ? String(cid) : ""
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
    }
}

// MARK: - Tracked CID Row

private struct TrackedCIDRow: View {
    let cid: Int
    let pilot: Pilot?
    let controller: Controllers?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: statusSymbol)
                .foregroundStyle(statusColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(String(cid))
                        .font(.headline)
                    if let name = onlineName {
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(name)
                            .foregroundStyle(.secondary)
                    }
                }

                if let detail = sessionDetail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }

    private var statusSymbol: String {
        if pilot != nil { return "airplane" }
        if controller != nil { return "antenna.radiowaves.left.and.right" }
        return "wifi.slash"
    }

    private var statusColor: Color {
        if pilot != nil { return .green }
        if controller != nil { return .green }
        return .secondary
    }

    private var onlineName: String? {
        pilot?.name ?? controller?.name
    }

    private var sessionDetail: String? {
        if let p = pilot {
            var parts: [String] = [p.callsign]
            if let fp = p.flight_plan {
                parts.append("\(fp.departure) → \(fp.arrival)")
            }
            parts.append(p.onlineDuration)
            return parts.joined(separator: "  ·  ")
        }
        if let c = controller {
            return "\(c.callsign)  ·  \(c.frequency)  ·  \(c.onlineDuration)"
        }
        return "Offline"
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserPreferencesModel.self, configurations: config)
    let manager = PreferencesManager(context: ModelContext(container))
    manager.updateCID(1234567)
    manager.addTrackedCID(9876543)   // pilot
    manager.addTrackedCID(1111111)   // controller
    manager.addTrackedCID(5555555)   // offline

    let mockPilot = Pilot(
        cid: 9876543, name: "John Smith", callsign: "BAW442",
        server: "UK", pilot_rating: 0, military_rating: 0,
        latitude: 51.5, longitude: -0.5, altitude: 35000,
        groundspeed: 480, transponder: "1234", heading: 90,
        qnh_i_hg: 29.92, qnh_mb: 1013,
        logon_time: Date().addingTimeInterval(-7320),
        last_updated: Date(),
        flight_plan: FlightPlan(
            flight_rules: "I", aircraft: "B788", aircraft_faa: "B788/L",
            aircraft_short: "B788", departure: "EGLL", arrival: "KJFK",
            alternate: "KBOS", deptime: "0900", enroute_time: "0730",
            fuel_time: "0900", remarks: "/V/", route: "WOTAN DCT NATX",
            revision_id: 1, assigned_transponder: "1234"
        )
    )

    let mockController = Controllers(
        cid: 1111111, name: "Anna Kowalski", callsign: "EGTT_CTR",
        frequency: "135.050", facility: 6, rating: 5,
        server: "UK", visual_range: 600, text_atis: nil,
        logon_time: Date().addingTimeInterval(-3600),
        last_updated: Date()
    )

    let vm = RadarViewModel()
    vm.pilots = [mockPilot]
    vm.controllers = [mockController]

    return NavigationStack {
        VatsimTrackedView()
    }
    .environment(manager)
    .environmentObject(vm)
}
