//
//  DebugView.swift
//  VatSight
//
//  Debug panel for injecting simulated ATC positions during development.
//

import SwiftUI

private let positionTypeOrder = ["DEL", "GND", "TWR", "APP", "CTR", "FSS"]

struct DebugView: View {

    @ObservedObject var viewModel: RadarViewModel

    @State private var searchText = ""
    @State private var selectedTypes: Set<String> = []

    // Deduplicated list of all known position types across the loaded data
    private var availableTypes: [String] {
        let types = Set(viewModel.allVatglassesPositions.map { $0.position.type })
        return positionTypeOrder.filter { types.contains($0) } + types.subtracting(positionTypeOrder).sorted()
    }

    private var filteredPositions: [(key: String, position: VatglassesPosition)] {
        viewModel.allVatglassesPositions.filter { item in
            let matchesType = selectedTypes.isEmpty || selectedTypes.contains(item.position.type)
            let matchesSearch = searchText.isEmpty ||
                item.position.callsign.localizedCaseInsensitiveContains(searchText) ||
                item.key.localizedCaseInsensitiveContains(searchText) ||
                item.position.facilityPrefixes.contains { $0.localizedCaseInsensitiveContains(searchText) }
            return matchesType && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.allVatglassesPositions.isEmpty {
                    ContentUnavailableView(
                        "No Position Data",
                        systemImage: "antenna.radiowaves.left.and.right.slash",
                        description: Text("Vatglasses data hasn't loaded yet. Wait for the radar to finish loading.")
                    )
                } else {
                    positionList
                }
            }
            .navigationTitle("Debug Panel")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Name, ID or prefix")
        }
    }

    @ViewBuilder
    private var positionList: some View {
        List {
            // Type filter chips
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(availableTypes, id: \.self) { type in
                            let isOn = selectedTypes.contains(type)
                            Button {
                                if isOn { selectedTypes.remove(type) }
                                else { selectedTypes.insert(type) }
                            } label: {
                                Text(type)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(isOn ? typeColor(type) : Color.secondary.opacity(0.15), in: .capsule)
                                    .foregroundStyle(isOn ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                            .animation(.easeInOut(duration: 0.15), value: isOn)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listRowInsets(.init(top: 4, leading: 12, bottom: 4, trailing: 12))
            .listRowBackground(Color.clear)

            // Active injections summary
            if !viewModel.debugControllers.isEmpty {
                Section("Active (\(viewModel.debugControllers.count))") {
                    ForEach(viewModel.debugControllers) { controller in
                        HStack {
                            typeTag(controller.callsign.components(separatedBy: "_").last ?? "")
                            VStack(alignment: .leading, spacing: 1) {
                                Text(controller.callsign)
                                    .font(.system(.subheadline, design: .monospaced))
                                Text("\(controller.frequency) MHz · \(controller.name)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                viewModel.toggleDebugController(controller)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // Positions list
            Section(
                header: Text("\(filteredPositions.count) position\(filteredPositions.count == 1 ? "" : "s")")
            ) {
                ForEach(filteredPositions, id: \.key) { item in
                    PositionRow(positionKey: item.key, pos: item.position, viewModel: viewModel)
                }
            }
        }
        .listStyle(.insetGrouped)
        .animation(.easeInOut(duration: 0.2), value: viewModel.debugControllers.count)
    }

    private func typeColor(_ type: String) -> Color {
        switch type {
        case "DEL": return .purple
        case "GND": return .brown
        case "TWR": return .green
        case "APP": return .blue
        case "CTR": return .orange
        case "FSS": return .red
        default: return .gray
        }
    }

    @ViewBuilder
    private func typeTag(_ type: String) -> some View {
        Text(type)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(typeColor(type).opacity(0.2), in: .rect(cornerRadius: 4))
            .foregroundStyle(typeColor(type))
            .frame(minWidth: 30)
    }
}

// MARK: - Position Row

private struct PositionRow: View {

    let positionKey: String   // e.g. "epww/AH"
    let pos: VatglassesPosition
    @ObservedObject var viewModel: RadarViewModel

    /// The VATSIM callsign that the matching engine will see.
    /// Built as `facilityPrefix_type` (e.g. "EPWW_CTR") because that is what
    /// `matchesCallsignPattern` checks — pos.callsign is the human display name ("EPWW Radar").
    private var vatsimCallsign: String {
        guard let prefix = pos.facilityPrefixes.first, !prefix.isEmpty else {
            return "\(positionKey.components(separatedBy: "/").last ?? positionKey)_\(pos.type)"
        }
        return "\(prefix)_\(pos.type)"
    }

    /// Short identifier extracted from the scoped key (e.g. "epww/AH" → "AH").
    private var positionId: String {
        positionKey.components(separatedBy: "/").last ?? positionKey
    }

    private func typeColor(_ type: String) -> Color {
        switch type {
        case "DEL": return .purple
        case "GND": return .brown
        case "TWR": return .green
        case "APP": return .blue
        case "CTR": return .orange
        case "FSS": return .red
        default: return .gray
        }
    }

    private func makeController() -> Controllers {
        Controllers(
            cid: 9_000_000 + abs(positionKey.hashValue % 999_000),
            // Store the position key in `name` so toggleDebugController can match by key
            name: positionKey,
            callsign: vatsimCallsign,
            frequency: pos.frequency,
            facility: facilityCode(for: pos.type),
            rating: 3,
            server: "DEBUG",
            visual_range: defaultVisualRange(for: pos.type),
            text_atis: nil,
            logon_time: Date(),
            last_updated: Date()
        )
    }

    private func facilityCode(for type: String) -> Int {
        switch type {
        case "DEL": return 1
        case "GND": return 2
        case "TWR": return 3
        case "APP": return 4
        case "CTR": return 6
        case "FSS": return 7
        default: return 0
        }
    }

    private func defaultVisualRange(for type: String) -> Int {
        switch type {
        case "DEL": return 10
        case "GND": return 15
        case "TWR": return 50
        case "APP": return 100
        case "CTR": return 300
        case "FSS": return 1500
        default: return 50
        }
    }

    var body: some View {
        let isActive = viewModel.isDebugControllerActive(positionKey: positionKey)
        Button {
            viewModel.toggleDebugController(makeController())
        } label: {
            HStack(spacing: 10) {
                // Type badge
                Text(pos.type)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(typeColor(pos.type).opacity(0.2), in: .rect(cornerRadius: 4))
                    .foregroundStyle(typeColor(pos.type))
                    .frame(minWidth: 30)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        // Human name (e.g. "EPWW Radar")
                        Text(pos.callsign)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        // Position ID badge (e.g. "AH") to distinguish duplicates
                        Text(positionId)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.15), in: .rect(cornerRadius: 3))
                            .foregroundStyle(.secondary)
                    }
                    // VATSIM callsign + frequency
                    Text("\(vatsimCallsign) · \(pos.frequency) MHz")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isActive ? .green : Color.secondary.opacity(0.4))
            }
        }
        .buttonStyle(.plain)
    }
}
