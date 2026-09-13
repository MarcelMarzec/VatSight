//
//  SectorDetailsView.swift
//  VatSight

import SwiftUI
import SwiftData

struct SectorDetailsView: View {
    let sector: VatglassesSector
    let controller: Controllers?
    let allPositions: [String: VatglassesPosition]
    let allSectors: [VatglassesSector]
    @Binding var headerHeight: CGFloat
    /// Called when the user taps an online (non-owner) position in the hierarchy.
    var onSectorSelected: ((String) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(PreferencesManager.self) private var prefsManager

    @State private var showAllOwners: Bool

    init(sector: VatglassesSector, controller: Controllers?, allPositions: [String: VatglassesPosition], allSectors: [VatglassesSector], headerHeight: Binding<CGFloat>, onSectorSelected: ((String) -> Void)? = nil) {
        self.sector = sector
        self.controller = controller
        self.allPositions = allPositions
        self.allSectors = allSectors
        self._headerHeight = headerHeight
        self.onSectorSelected = onSectorSelected
        // Show all hierarchy entries immediately when the sector is inactive
        self._showAllOwners = State(initialValue: controller == nil)
    }

    private var isTracked: Bool {
        guard let cid = controller?.cid else { return false }
        return prefsManager.userPrefs.trackedCIDs.contains(cid)
    }

    var body: some View {
        NavigationStack {
            if let controller {
                headerSection(controller: controller)
            } else {
                inactiveHeaderSection
            }
            List {
                if let controller {
                    controllerDetailsSection(controller: controller)
                    ForEach(sector.activeCoControllers) { co in
                        coControllerSection(co)
                    }
                }
                sectorInfoSection(isActive: controller != nil)
                ownershipHierarchySection(controller: controller)
            }
            .scrollDisabled(false)
            .textSelection(.enabled)
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func sectorInfoSection(isActive: Bool) -> some View {
        Section {
            LabeledContent("Sector ID", value: sector.id)
            if let groupName = sector.properties?.groupName {
                LabeledContent("FIR / Group", value: groupName)
            }
            if isActive {
                LabeledContent("Frequency", value: sector.frequency)
            }
            if let min = sector.properties?.min, let max = sector.properties?.max {
                LabeledContent("Altitude Band", value: altitudeBandLabel(min: min, max: max))
            }
        } header: {
            Text("Sector Info")
        }
    }

    private func ownershipHierarchySection(controller: Controllers?) -> some View {
        // Pre-build a set of all ownerRefs that are actively controlling any sector
        let activeOwnerRefs = Set(allSectors.compactMap { $0.activeOwnerRef })
        let hiddenCount = sector.ownerRefs.filter { !activeOwnerRefs.contains($0) }.count
        let visibleRefs = showAllOwners
            ? Array(sector.ownerRefs.enumerated())
            : Array(sector.ownerRefs.enumerated().filter { activeOwnerRefs.contains($0.element) })

        return Section {
            ForEach(visibleRefs, id: \.offset) { index, ref in
                let position = allPositions[ref]
                let isOwner = ref == sector.activeOwnerRef
                // A ref is online if it is the active owner of any sector in the dataset
                let isOnline = activeOwnerRefs.contains(ref)
                let badgeColor: Color = isOwner ? .green : (isOnline ? .primary : .secondary)

                HStack(spacing: 12) {
                    if isOwner {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.caption2)
                            .foregroundColor(.green)
                            .frame(width: 16)
                    } else if index > 0 {
                        Image(systemName: "arrow.up")
                            .font(.caption2)
                            .foregroundColor(isOnline ? .primary : .secondary)
                            .frame(width: 16)
                    } else {
                        Spacer().frame(width: 16)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(ref.uppercased())
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundColor(isOwner ? .green : (isOnline ? .primary : .secondary))
                            if let type = position?.type {
                                Text(type)
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background((isOnline ? badgeColor : Color.secondary).opacity(0.15))
                                    .foregroundColor(isOnline ? badgeColor : .secondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                        if let callsign = position?.callsign {
                            Text(callsign)
                                .font(.subheadline)
                                .foregroundColor(isOnline ? .primary : .secondary)
                        }
                    }
                    Spacer()
                    if let freq = position?.frequency {
                        Text(freq)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundColor(isOnline ? .primary : .secondary)
                    }
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !isOwner, isOnline, let targetSector = allSectors.first(where: { $0.activeOwnerRef == ref }) else { return }
                    onSectorSelected?(targetSector.id)
                }
            }
            if hiddenCount > 0 {
                Button {
                    withAnimation {
                        showAllOwners.toggle()
                    }
                } label: {
                    HStack {
                        Spacer().frame(width: 16)
                        Image(systemName: showAllOwners ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(showAllOwners ? "Show less" : "\(hiddenCount) offline position\(hiddenCount == 1 ? "" : "s")")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Ownership Hierarchy")
        } footer: {
            if let controller {
                HStack {
                    Spacer()
                    VStack {
                        Text("Last Updated")
                            .font(.subheadline)
                        Text(controller.last_updatedFormatted)
                            .font(.subheadline)
                    }
                    Spacer()
                }
            }
        }
    }

    private func altitudeBandLabel(min: Int, max: Int) -> String {
        let minStr: String
        if min == 0 {
            minStr = "SFC"
        } else if min < 10_000 {
            minStr = "\(min) ft"
        } else {
            minStr = "FL\(min / 100)"
        }
        let maxStr = max < 10_000 ? "\(max) ft" : "FL\(max / 100)"
        return "\(minStr) – \(maxStr)"
    }

    // MARK: - Sections (Active)

    private var inactiveHeaderSection: some View {
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sector.properties?.name ?? sector.id)
                        .font(.title2.bold())
                    if let groupName = sector.properties?.groupName {
                        Text(groupName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.title)
                }
                .foregroundColor(.primary)
            }
        }
        .padding()
        .padding(.bottom, 16)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { newHeight in
            guard newHeight > 0 else { return }
            headerHeight = newHeight + 20
        }
    }

    private func headerSection(controller: Controllers) -> some View {
        VStack(alignment: .leading) {
            callsignRow(controller: controller)
            Text(controller.frequency)
                .font(.title2).padding(.top, 8)
            HStack {
                if let name = sector.properties?.name {
                    Text(name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                if sector.properties?.name != nil, sector.properties?.groupName != nil {
                    Text("|").font(.subheadline)
                        .foregroundColor(.secondary)
                }
                if let groupName = sector.properties?.groupName {
                    Text(groupName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            if sector.isBasicDataOnly {
                Text("Basic Data Only")
                    .font(.caption.bold())
                    .foregroundColor(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(red: 1.0, green: 0.71, blue: 0.0))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            atisText(controller: controller)
        }
        .padding()
        .padding(.bottom, 16)
        .textSelection(.enabled)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { newHeight in
            guard newHeight > 0 else { return }
            // Add drag indicator height (~20pt)
            headerHeight = newHeight + 20
        }
    }

    private func controllerDetailsSection(controller: Controllers) -> some View {
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
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
            LabeledContent("Rating", value: ratingLabel(for: controller))
            LabeledContent("Facility", value: facilityLabel(for: controller))
            LabeledContent("Server", value: controller.server)
        } header: {
            Text("Controller Details")
        }
    }

    // MARK: - Helpers

    private func coControllerSection(_ co: Controllers) -> some View {
        let isCoTracked = prefsManager.userPrefs.trackedCIDs.contains(co.cid)
        return Section {
            LabeledContent {
                VStack(alignment: .trailing) {
                    Text(co.logon_timeFormatted)
                    Text(co.onlineDuration)
                }
            } label: {
                HStack {
                    Button {
                        if isCoTracked {
                            prefsManager.removeTrackedCID(co.cid)
                        } else {
                            prefsManager.addTrackedCID(co.cid)
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: isCoTracked ? "star.fill" : "star")
                            .font(.title2)
                    }
                    .foregroundColor(isCoTracked ? .green : .primary)
                    VStack(alignment: .leading) {
                        Text(co.callsign).font(.headline).foregroundColor(.primary)
                        Text(co.name).font(.subheadline).foregroundColor(.secondary)
                        Text(String(co.cid)).font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            LabeledContent("Frequency", value: co.frequency)
        } header: {
            Text("Also Online")
        }
    }

    private func callsignRow(controller: Controllers) -> some View {
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
            .foregroundColor(.primary)
        }
    }

    @ViewBuilder
    private func atisText(controller: Controllers) -> some View {
        if let atis = controller.text_atis, !atis.isEmpty {
            Text(atis.joined(separator: "\n"))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func ratingLabel(for controller: Controllers) -> String {
        if let info = controller.ratingInfo {
            return info.short + " | " + info.long
        }
        return String(controller.rating)
    }

    private func facilityLabel(for controller: Controllers) -> String {
        if let info = controller.facilityInfo {
            return info.short + " | " + info.long
        }
        return String(controller.facility)
    }
}

// MARK: - Previews

private let previewPositions: [String: VatglassesPosition] = [
    "eg/EGLL_TWR": VatglassesPosition(callsign: "Heathrow Tower", frequency: "118.500", type: "TWR", facilityPrefixes: ["EGLL"], colors: nil),
    "eg/EGLL_APP": VatglassesPosition(callsign: "Heathrow Approach", frequency: "119.725", type: "APP", facilityPrefixes: ["EGLL"], colors: nil),
    "eg/EGTT_W_CTR": VatglassesPosition(callsign: "London Control", frequency: "133.455", type: "CTR", facilityPrefixes: ["EG"], colors: ["#4A90D9"]),
    "eg/EGPX_CTR": VatglassesPosition(callsign: "Scottish Control", frequency: "135.850", type: "CTR", facilityPrefixes: ["EG"], colors: nil),
    "eg/EGGX_CTR": VatglassesPosition(callsign: "Shanwick Radio", frequency: "131.800", type: "FSS", facilityPrefixes: ["EG"], colors: nil)
]

private let previewOwnerRefs = [
    "eg/EGLL_TWR", "eg/EGLL_APP", "eg/EGTT_W_CTR", "eg/EGPX_CTR", "eg/EGGX_CTR"
]

#Preview("Active Sector") {
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
        callsign: "EGTT_W_CTR",
        frequency: "133.455",
        facility: 6,
        rating: 5,
        server: "UK-1",
        visual_range: 300,
        text_atis: [
            "London Control West online",
            "Covering EGLL TMA and below"
        ],
        logon_time: Date(),
        last_updated: Date()
    )
    let sector = VatglassesSector(
        id: "eg/TC Biggin",
        ownerRefs: previewOwnerRefs,
        frequency: "133.455",
        geometry: SectorGeometry(type: "Polygon", coordinates: [[[[-0.4, 51.3], [0.1, 51.5], [0.3, 51.2], [-0.4, 51.3]]]]),
        properties: SectorProperties(min: 0, max: 7000, name: "TC Biggin", groupName: "London", color: nil),
        isActive: true,
        activeOwnerColorHex: "#4A90D9",
        activeOwnerRef: "eg/EGTT_W_CTR",
        activeController: controller
    )
    // Stub sector to mark EGLL_APP as online in a different sector
    let approachSector = VatglassesSector(
        id: "eg/EGLL_APP_S",
        ownerRefs: ["eg/EGLL_APP"],
        frequency: "119.725",
        geometry: SectorGeometry(type: "Polygon", coordinates: [[[[-0.4, 51.3], [0.1, 51.5], [0.3, 51.2], [-0.4, 51.3]]]]),
        properties: nil,
        isActive: true,
        activeOwnerColorHex: nil,
        activeOwnerRef: "eg/EGLL_APP",
        activeController: nil
    )
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserPreferencesModel.self, configurations: config)
    let manager = PreferencesManager(context: ModelContext(container))

    SectorDetailsView(sector: sector, controller: controller, allPositions: previewPositions, allSectors: [sector, approachSector], headerHeight: .constant(0))
        .environment(manager)
}

#Preview("Inactive Sector") {
    let sector = VatglassesSector(
        id: "eg/TC Biggin",
        ownerRefs: previewOwnerRefs,
        frequency: "133.455",
        geometry: SectorGeometry(type: "Polygon", coordinates: [[[[-0.4, 51.3], [0.1, 51.5], [0.3, 51.2], [-0.4, 51.3]]]]),
        properties: SectorProperties(min: 0, max: 7000, name: "TC Biggin", groupName: "London", color: nil),
        isActive: false
    )
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserPreferencesModel.self, configurations: config)
    let manager = PreferencesManager(context: ModelContext(container))

    SectorDetailsView(sector: sector, controller: nil, allPositions: previewPositions, allSectors: [], headerHeight: .constant(0))
        .environment(manager)
}
