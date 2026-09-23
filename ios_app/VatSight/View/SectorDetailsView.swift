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
            VStack(spacing: 0) {
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
            } // VStack
        }
    }

    private func sectorInfoSection(isActive: Bool) -> some View {
        Section {
            LabeledContent("Sector ID", value: sector.id)
            if let groupName = sector.properties?.groupName {
                LabeledContent("FIR / Group", value: groupName)
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
            if sector.ownerRefs.isEmpty {
                Text("No ownership data available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(visibleRefs, id: \.offset) { index, ref in
                    let position = allPositions[ref]
                    let isOwner = ref == sector.activeOwnerRef
                    // A ref is online if it is the active owner of any sector in the dataset
                    let isOnline = activeOwnerRefs.contains(ref)
                    let isTappable = !isOwner && isOnline
                    let badgeColor: Color = isOwner ? .green : (isOnline ? .primary : .secondary)

                    HStack(spacing: 12) {
                        if isOwner {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.caption2)
                                .foregroundColor(.green)
                                .frame(width: 16)
                        } else if index > 0 {
                            Image(systemName: "chevron.up")
                                .font(.caption2)
                                .foregroundColor(isOnline ? .primary : .secondary)
                                .frame(width: 16)
                        } else {
                            Spacer().frame(width: 16)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(ref)
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
                        if isTappable {
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard isTappable, let targetSector = allSectors.first(where: { $0.activeOwnerRef == ref }) else { return }
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
            }
        } header: {
            Text("Ownership Hierarchy")
        } footer: {
            if let controller {
                HStack {
                    Spacer()
                    Text("Last updated \(controller.last_updatedFormatted) UTC")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func altitudeBandLabel(min: Int, max: Int) -> String {
        // Vatglasses stores altitudes as FL numbers (e.g. 70 = FL070 = 7,000 ft).
        // Below FL100 (value < 100) display in feet; FL100 and above display as FL.
        let minStr: String
        if min == 0 {
            minStr = "SFC"
        } else if min < 100 {
            minStr = "\(min * 100)ft"
        } else {
            minStr = "FL\(min)"
        }
        let maxStr = max < 100 ? "\(max * 100)ft" : "FL\(max)"
        return "\(minStr) – \(maxStr)"
    }

    // MARK: - Sections (Active)

    private var inactiveHeaderSection: some View {
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sector.properties?.name ?? sector.ownerRefs.first.flatMap { allPositions[$0]?.callsign } ?? sector.id)
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
        .frame(maxWidth: .infinity, alignment: .leading)
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
                if let ownerRef = sector.activeOwnerRef, let callsign = allPositions[ownerRef]?.callsign {
                    Text(callsign)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                if sector.activeOwnerRef.flatMap({ allPositions[$0]?.callsign }) != nil, sector.properties?.groupName != nil, !sector.isBasicDataOnly {
                    Text("|").font(.subheadline)
                        .foregroundColor(.secondary)
                }
                if let groupName = sector.properties?.groupName {
                    if sector.isBasicDataOnly {
                        Text(groupName)
                            .font(.caption.bold())
                            .foregroundStyle(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.yellow)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else {
                        Text(groupName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            atisText(controller: controller)
        }
        .padding()
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
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
                    VStack(alignment: .leading) {
                        HStack {
                            Text(controller.name).font(.headline).foregroundColor(.primary)
                            if isTracked {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        Text(String(controller.cid)).font(.subheadline).foregroundColor(.secondary)
                        if prefsManager.shouldShowSwipeToTrackHint && !isTracked {
                            Text("Swipe right to track")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .swipeActions(edge: .leading) {
                Button {
                    if isTracked {
                        prefsManager.removeTrackedCID(controller.cid)
                    } else {
                        prefsManager.addTrackedCID(controller.cid)
                        prefsManager.incrementSwipeToTrackHint()
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Label(isTracked ? "Untrack" : "Track", systemImage: isTracked ? "star.slash" : "star")
                }
                .tint(isTracked ? .orange : .green)
            }
            LabeledContent("Rating", value: ratingLabel(for: controller))
            LabeledContent("Facility", value: facilityLabel(for: controller))
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
                    VStack(alignment: .leading) {
                        Text(co.callsign).font(.headline).foregroundColor(.primary)
                        Text(co.name).font(.subheadline).foregroundColor(.secondary)
                        Text(String(co.cid)).font(.caption).foregroundColor(.secondary)
                        if prefsManager.shouldShowSwipeToTrackHint && !isCoTracked {
                            Text("Swipe right to track")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    if isCoTracked {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
            .swipeActions(edge: .leading) {
                Button {
                    if isCoTracked {
                        prefsManager.removeTrackedCID(co.cid)
                    } else {
                        prefsManager.addTrackedCID(co.cid)
                        prefsManager.incrementSwipeToTrackHint()
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Label(isCoTracked ? "Untrack" : "Track", systemImage: isCoTracked ? "star.slash" : "star")
                }
                .tint(isCoTracked ? .orange : .green)
            }
            LabeledContent("Frequency", value: co.frequency)
        } header: {
            Text("Co-Controller")
        }
    }

    private func callsignRow(controller: Controllers) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(controller.callsign)
                    .font(.title2.bold())
                Text(controller.name)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
            Text(atisAttributedString(from: atis))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func atisAttributedString(from lines: [String]) -> AttributedString {
        let fullText = lines.joined(separator: "\n")
        var result = AttributedString(fullText)

        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let nsString = fullText as NSString
        let matches = detector?.matches(in: fullText, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []

        for match in matches {
            guard let url = match.url,
                  let range = Range(match.range, in: fullText),
                  let attrRange = Range(range, in: result) else { continue }
            result[attrRange].link = url
            result[attrRange].foregroundColor = .blue
            result[attrRange].underlineStyle = .single
        }

        return result
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
    // swipeToTrackHintCount defaults to 0, so hint text is visible

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
