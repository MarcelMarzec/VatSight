//
//  RadarViewModel.swift
//  VatSight
//

import Foundation
import Combine
import CoreLocation
import UIKit

final class RadarViewModel: ObservableObject {
    
    @Published var general: General?
    @Published var pilots: [Pilot] = []
    @Published var prefiles: [Prefiles] = []
    @Published var controllers: [Controllers] = []
    @Published var atis: [ATIS] = []
    @Published var sectors: [VatglassesSector] = []
    @Published var airports: [VatglassesAirport] = []
    @Published var selectedCID: Int?
    @Published var isShowingPilotSheet = false
    @Published var selectedAirportICAO: String?
    @Published var isShowingAirportSheet = false
    @Published var controllersAtSelectedAirport: [Controllers] = []
    @Published var selectedSectorId: String?
    @Published var isShowingSectorSheet = false
    @Published var showInactiveSectors = false
    @Published var showAirports = false
    @Published var showPilotsLayer = true
    @Published var showSectorsLayer = true
    @Published var showAirportLayer = true
    @Published var isLoadingData = true
    @Published var pendingCameraFlyTo: CLLocationCoordinate2D? = nil
    @Published var selectedAltitudeFt: Double = 0
    @Published var altitudeFilterEnabled = false
    @Published var mergeSectors = false
    private var mergeSectorsStateBeforeAltitudeFilter: Bool? = nil

    // MARK: - Merge cache
    private var mergedSectorsOwnershipSignature: Int = -1
    private var cachedMergedSectors: [VatglassesSector] = []

    @Published var lastFetchFailed = false
    @Published var lastSuccessfulFetch: Date? = nil

    // MARK: - Debug overrides
    @Published var debugControllers: [Controllers] = []
    @Published var vatglassesDiagnostics = VatglassesDiagnostics()

    var activeFlightPlanICAOs: Set<String> = []
    
    private let vatsimService = VatsimService()
    private let vatglassesService = VatglassesService()
    private var timer: Timer?
    private var prefsManager: PreferencesManager?
    
    private var vatsimFetchDone = false
    private var sectorFetchDone = false
    
    private var refreshInterval: TimeInterval {
        prefsManager?.getRefreshIntervalInSeconds() ?? 15
    }
    
    func setPreferencesManager(_ manager: PreferencesManager) {
        self.prefsManager = manager
        self.showInactiveSectors = manager.userPrefs.showInactiveSectors
        self.showAirports = manager.userPrefs.showAirports
        self.showPilotsLayer = manager.userPrefs.showPilotsLayer
        self.showSectorsLayer = manager.userPrefs.showSectorsLayer
        self.showAirportLayer = manager.userPrefs.showAirportLayer
        self.altitudeFilterEnabled = manager.userPrefs.altitudeFilterEnabled
        self.mergeSectors = manager.userPrefs.mergeSectors
        // Only honour a custom slug when developer mode is actually on.
        let slug = manager.userPrefs.developerModeEnabled ? manager.userPrefs.vatglassesCustomRepoSlug : ""
        self.vatglassesService.customRepoSlug = slug
    }
    
    func startAutoRefresh() {
        guard timer == nil else { return }
        
        let hasData = !pilots.isEmpty || !sectors.isEmpty
        if !hasData {
            isLoadingData = true
            vatsimFetchDone = false
            sectorFetchDone = false
            loadVatsimData()
            loadSectorData()
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.loadVatsimData()
        }
    }
    
    func restartAutoRefresh() {
        let wasRunning = timer != nil
        stopAutoRefresh()
        if wasRunning { startAutoRefresh() }
    }
    
    func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
    }
    
    func loadVatsimData() {
        vatsimService.fetchAllData { [weak self] result in
            switch result {
            case .success(let response):
                DispatchQueue.main.async {
                    VatsimRatingsRegistry.shared.populate(from: response)
                    self?.general = response.general
                    self?.pilots = response.pilots
                    self?.prefiles = response.prefiles
                    self?.controllers = response.controllers
                    self?.atis = response.atis
                    self?.updateSectorActiveStatus()
                    self?.syncAltitudeFilterToSelectedPilot()
                    self?.lastFetchFailed = false
                    self?.lastSuccessfulFetch = Date()
                    self?.vatsimFetchDone = true
                    self?.dismissLoadingIfReady()
                }
            case .failure:
                DispatchQueue.main.async {
                    self?.lastFetchFailed = true
                    self?.vatsimFetchDone = true
                    self?.dismissLoadingIfReady()
                }
            }
        }
    }
    
    func loadSectorData() {
        vatglassesService.fetchSectorData { [weak self] result in
            switch result {
            case .success(let data):
                DispatchQueue.main.async {
                    self?.sectors = data.sectors
                    self?.airports = data.airports
                    if let service = self?.vatglassesService {
                        self?.vatglassesDiagnostics = VatglassesDiagnostics(
                            parseErrors: service.parseErrors,
                            unmatchedControllers: [],
                            invalidAirports: Self.detectInvalidAirports(data.airports),
                            lastUpdated: Date()
                        )
                    }
                    self?.updateSectorActiveStatus()
                    self?.objectWillChange.send()
                    self?.sectorFetchDone = true
                    self?.dismissLoadingIfReady()
                }
            case .failure:
                DispatchQueue.main.async {
                    let cachedSectors = self?.vatglassesService.getCachedSectors() ?? []
                    let cachedAirports = self?.vatglassesService.getCachedAirports() ?? []
                    if !cachedSectors.isEmpty {
                        self?.sectors = cachedSectors
                        self?.airports = cachedAirports
                        self?.updateSectorActiveStatus()
                    }
                    self?.sectorFetchDone = true
                    self?.dismissLoadingIfReady()
                }
            }
        }
    }
    
    func clearVatglassesCache() {
        vatglassesService.clearCache()
    }

    var vatglassesActiveRepoSlug: String { vatglassesService.customRepoSlug }
    var isUsingCustomVatglassesRepo: Bool { !vatglassesService.customRepoSlug.isEmpty }

    func applyVatglassesCustomRepo(_ slug: String) {
        vatglassesService.customRepoSlug = slug
        clearVatglassesCache()
        sectors = []
        loadSectorData()
    }

    var allVatglassesPositions: [(key: String, position: VatglassesPosition)] {
        vatglassesService.getCachedPositions()
            .map { (key: $0.key, position: $0.value) }
            .sorted { $0.key < $1.key }
    }

    var effectiveControllers: [Controllers] {
        mergedWithDebugControllers(controllers)
    }

    func resolvePositionLabel(for callsign: String) -> String? {
        vatglassesService.resolvePositionLabel(for: callsign)
    }
    
    private func dismissLoadingIfReady() {
        if vatsimFetchDone && sectorFetchDone {
            isLoadingData = false
        }
    }

    var isDataStale: Bool {
        guard let last = lastSuccessfulFetch else { return false }
        return Date().timeIntervalSince(last) > (refreshInterval * 2)
    }

    private func syncAltitudeFilterToSelectedPilot() {
        guard altitudeFilterEnabled, let cid = selectedCID,
              let pilot = pilots.first(where: { $0.cid == cid }) else { return }
        selectedAltitudeFt = Double(pilot.altitude)
    }
    
    private func updateSectorActiveStatus() {
        var icaos = Set<String>()
        for pilot in pilots {
            if let fp = pilot.flight_plan {
                if !fp.departure.isEmpty { icaos.insert(fp.departure) }
                if !fp.arrival.isEmpty { icaos.insert(fp.arrival) }
            }
        }
        activeFlightPlanICAOs = icaos

        let mergedControllers = mergedWithDebugControllers(controllers)
        airports = vatglassesService.getActiveAirports(controllers: mergedControllers, atis: atis)
        updateControllersAtSelectedAirport()

        if !sectors.isEmpty {
            sectors = vatglassesService.getActiveSectors(controllers: mergedControllers, airports: airports)
            vatglassesDiagnostics = VatglassesDiagnostics(
                parseErrors: vatglassesService.parseErrors,
                unmatchedControllers: vatglassesService.unmatchedControllers,
                invalidAirports: Self.detectInvalidAirports(airports),
                syntheticSectors: vatglassesService.syntheticSectors,
                lastUpdated: Date()
            )
        }
    }

    private static func detectInvalidAirports(_ airports: [VatglassesAirport]) -> [InvalidAirport] {
        airports.compactMap { a in
            guard abs(a.latitude) > 90 || abs(a.longitude) > 180 else { return nil }
            return InvalidAirport(icao: a.icao, name: a.callsign ?? "", latitude: a.latitude, longitude: a.longitude)
        }
    }

    private func mergedWithDebugControllers(_ live: [Controllers]) -> [Controllers] {
        guard !debugControllers.isEmpty else { return live }
        let debugCIDs = Set(debugControllers.map { $0.cid })
        return live.filter { !debugCIDs.contains($0.cid) } + debugControllers
    }

    func toggleDebugController(_ controller: Controllers) {
        if let idx = debugControllers.firstIndex(where: { $0.name == controller.name }) {
            debugControllers.remove(at: idx)
        } else {
            debugControllers.append(controller)
        }
        updateSectorActiveStatus()
        objectWillChange.send()
    }

    func isDebugControllerActive(positionKey: String) -> Bool {
        debugControllers.contains { $0.name == positionKey }
    }
    
    var selectedPilot: Pilot? {
        pilots.first { $0.cid == selectedCID }
    }
    
    var selectedAirport: VatglassesAirport? {
        airports.first { $0.icao == selectedAirportICAO }
    }
    
    private func updateControllersAtSelectedAirport() {
        guard let icao = selectedAirportICAO else {
            controllersAtSelectedAirport = []
            return
        }

        let mergedControllers = mergedWithDebugControllers(controllers)
        let prefixes = vatglassesService.callsignPrefixes(for: icao)
        let directControllers = mergedControllers.filter { ctrl in
            let upper = ctrl.callsign.uppercased()
            guard !upper.hasSuffix("_ATIS") else { return false }
            return prefixes.contains { upper.hasPrefix($0 + "_") }
        }

        var topdownControllers: [Controllers] = []
        if let airport = selectedAirport {
            let allTopdown = vatglassesService.getTopdownControllers(for: airport, controllers: mergedControllers)
            let directCIDs = Set(directControllers.map { $0.cid })
            topdownControllers = allTopdown.filter { !directCIDs.contains($0.cid) }
        }

        controllersAtSelectedAirport = (directControllers + topdownControllers)
            .sorted { positionOrder($0.callsign) > positionOrder($1.callsign) }
    }
    
    var selectedSector: VatglassesSector? {
        sectors.first(where: { $0.id == selectedSectorId })
            ?? mergedSectorsToDisplay.first { $0.id == selectedSectorId }
    }

    var selectedSectorControllerCID: Int? {
        selectedSector?.activeController?.cid
    }
    
    private func positionOrder(_ callsign: String) -> Int {
        let upper = callsign.uppercased()
        if upper.hasSuffix("_DEL") { return 0 }
        if upper.hasSuffix("_GND") { return 1 }
        if upper.hasSuffix("_TWR") { return 2 }
        if upper.hasSuffix("_ATIS") { return 3 }
        if upper.hasSuffix("_APP") || upper.hasSuffix("_DEP") { return 4 }
        if upper.hasSuffix("_CTR") { return 5 }
        return 6
    }
    
    var activeSectors: [VatglassesSector] {
        sectors.filter { $0.isActive }
    }
    
    func selectPilot(cid: Int) {
        openPilotSheet(cid: cid, flyTo: nil, enableTracking: false)
    }

    func selectPilotAndFly(cid: Int, coordinate: CLLocationCoordinate2D, enableTracking: Bool = false) {
        openPilotSheet(cid: cid, flyTo: coordinate, enableTracking: enableTracking)
    }

    private func openPilotSheet(cid: Int, flyTo coordinate: CLLocationCoordinate2D?, enableTracking: Bool) {
        isShowingAirportSheet = false
        selectedAirportICAO = nil
        controllersAtSelectedAirport = []
        isShowingSectorSheet = false
        selectedSectorId = nil

        if altitudeFilterEnabled, let pilot = pilots.first(where: { $0.cid == cid }) {
            selectedAltitudeFt = Double(pilot.altitude)
        }

        selectedCID = cid
        isShowingPilotSheet = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        if let coordinate {
            pendingCameraFlyTo = coordinate
        }
    }

    func selectAirportAndFly(icao: String) {
        isShowingPilotSheet = false
        selectedCID = nil
        isShowingSectorSheet = false
        selectedSectorId = nil
        isShowingAirportSheet = false
        selectedAirportICAO = icao
        updateControllersAtSelectedAirport()
        if let airport = airports.first(where: { $0.icao == icao }) {
            pendingCameraFlyTo = CLLocationCoordinate2D(latitude: airport.latitude, longitude: airport.longitude)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.isShowingAirportSheet = true
        }
    }

    func airportName(for icao: String) -> String? {
        airports.first { $0.icao.uppercased() == icao.uppercased() }?.callsign
    }
    
    func dismissPilotSheet() {
        isShowingPilotSheet = false
        selectedCID = nil
    }

    func onPilotSheetDismissed() {
        selectedCID = nil
    }
    
    func selectAirport(icao: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if isShowingPilotSheet || isShowingSectorSheet {
            isShowingPilotSheet = false
            selectedCID = nil
            isShowingSectorSheet = false
            selectedSectorId = nil
            selectedAirportICAO = icao
            updateControllersAtSelectedAirport()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.isShowingAirportSheet = true
            }
        } else {
            selectedAirportICAO = icao
            updateControllersAtSelectedAirport()
            isShowingAirportSheet = true
        }
    }

    func dismissAirportSheet() {
        isShowingAirportSheet = false
        selectedAirportICAO = nil
        controllersAtSelectedAirport = []
    }
    
    func selectSector(id: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if isShowingPilotSheet || isShowingAirportSheet {
            isShowingPilotSheet = false
            selectedCID = nil
            isShowingAirportSheet = false
            selectedAirportICAO = nil
            selectedSectorId = id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.isShowingSectorSheet = true
            }
        } else {
            selectedSectorId = id
            isShowingSectorSheet = true
        }
    }

    /// Selects a sector by ID, flies the camera to the given coordinate, and opens the sector sheet.
    func selectSectorAndFly(id: String, coordinate: CLLocationCoordinate2D) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        isShowingPilotSheet = false
        selectedCID = nil
        isShowingAirportSheet = false
        selectedAirportICAO = nil
        pendingCameraFlyTo = coordinate
        if isShowingSectorSheet {
            // Sheet already open — update selection in place.
            selectedSectorId = id
        } else {
            selectedSectorId = id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.isShowingSectorSheet = true
            }
        }
    }
    
    func dismissSectorSheet() {
        isShowingSectorSheet = false
        selectedSectorId = nil
    }
    
    func toggleSectors() {
        showInactiveSectors.toggle()
        prefsManager?.updateShowInactiveSectors(showInactiveSectors)
        if showInactiveSectors && !showSectorsLayer {
            showSectorsLayer = true
            prefsManager?.updateShowSectorsLayer(true)
        }
    }

    func toggleAirports() {
        showAirports.toggle()
        prefsManager?.updateShowAirports(showAirports)
        if showAirports && !showAirportLayer {
            showAirportLayer = true
            prefsManager?.updateShowAirportLayer(true)
        }
    }

    func togglePilots() {
        showPilotsLayer.toggle()
        prefsManager?.updateShowPilotsLayer(showPilotsLayer)
    }

    func toggleAirportLayer() {
        showAirportLayer.toggle()
        prefsManager?.updateShowAirportLayer(showAirportLayer)
    }

    func toggleShowSectors() {
        showSectorsLayer.toggle()
        prefsManager?.updateShowSectorsLayer(showSectorsLayer)
    }

    func toggleAltitudeFilter() {
        let turningOn = !altitudeFilterEnabled
        if turningOn {
            mergeSectorsStateBeforeAltitudeFilter = mergeSectors
            if mergeSectors {
                mergeSectors = false
                prefsManager?.updateMergeSectors(false)
            }
        } else {
            if let remembered = mergeSectorsStateBeforeAltitudeFilter {
                mergeSectors = remembered
                prefsManager?.updateMergeSectors(remembered)
                mergeSectorsStateBeforeAltitudeFilter = nil
            }
        }
        altitudeFilterEnabled = turningOn
        prefsManager?.updateAltitudeFilterEnabled(altitudeFilterEnabled)
    }

    func toggleMergeSectors() {
        let turningOn = !mergeSectors
        if turningOn && altitudeFilterEnabled {
            altitudeFilterEnabled = false
            prefsManager?.updateAltitudeFilterEnabled(false)
        }
        mergeSectors = turningOn
        prefsManager?.updateMergeSectors(mergeSectors)
    }

    /// The upper bound for the altitude slider, capped at FL600 (60 000 ft).
    var maxSectorAltitudeFt: Double { 60_000 }

    /// Pilots to render on the map — empty when the pilots layer is toggled off.
    var pilotsToDisplay: [Pilot] {
        showPilotsLayer ? pilots : []
    }

    /// Sectors filtered by the inactive-sectors toggle and, when `altitudeFilterEnabled`, the selected altitude.
    /// A sector is included when `selectedAltitudeFt` falls within its [min*100, max*100] range.
    /// Sectors with no altitude properties are always shown.
    /// When `showSectors` is off, only inactive sector outlines are returned (so boundaries remain visible).
    var sectorsToDisplay: [VatglassesSector] {
        if !showSectorsLayer {
            // Active sectors hidden — only show inactive outlines if that toggle is also on.
            return showInactiveSectors ? sectors.filter { !$0.isActive } : []
        }
        if mergeSectors {
            // In merge mode, merged sectors are always active-only (the union only runs on
            // active sectors). Inactive sectors are shown unmerged alongside if the toggle
            // is on — append them from the regular (unmerged) list.
            if showInactiveSectors {
                let inactive = sectors.filter { !$0.isActive }
                return mergedSectorsToDisplay + inactive
            }
            return mergedSectorsToDisplay
        }
        let base = showInactiveSectors ? sectors : sectors.filter { $0.isActive }
        guard altitudeFilterEnabled else { return base }
        return base.filter { sector in
            guard let props = sector.properties,
                  let minFL = props.min,
                  let maxFL = props.max else { return true }
            let minFt = Double(minFL) * 100
            let maxFt = Double(maxFL) * 100
            return selectedAltitudeFt >= minFt && selectedAltitudeFt <= maxFt
        }
    }

    /// Returns merged sectors (one dissolved polygon per active controller via GEOSwift union).
    /// Only active sectors with a matched controller are included — inactive sectors are hidden.
    /// The result is cached and only recomputed when the active ownership assignment changes.
    var mergedSectorsToDisplay: [VatglassesSector] {
        // Signature over active sectors + their controller assignments.
        // Changes only when controllers log on/off or ownership transfers.
        let activeSectors = sectors.filter { $0.isActive }
        let signature = activeSectors.reduce(into: 0) { hash, sector in
            hash ^= sector.id.hashValue
            hash ^= (sector.activeController?.cid ?? -1).hashValue
        }
        if signature != mergedSectorsOwnershipSignature {
            mergedSectorsOwnershipSignature = signature
            cachedMergedSectors = SectorGeoJSON.mergedByController(from: sectors)
        }
        return cachedMergedSectors
    }

    /// Airports filtered by the show-all-airports and show-airport-layer toggles.
    /// When `showAirportLayer` is off, no airports are displayed at all.
    /// When `showAirports` is off, only airports with an active controller or in a flight plan are shown.
    var airportsToDisplay: [VatglassesAirport] {
        guard showAirportLayer else { return [] }
        if showAirports {
            return airports
        }
        return airports.filter { airport in
            airport.isActive || activeFlightPlanICAOs.contains(airport.icao)
        }
    }
    
    /// Airport ICAOs that should render as filled circles: those with an active controller or in a flight plan.
    var filledAirportICAOs: Set<String> {
        var filled = Set<String>()
        for airport in airports where airport.isActive || activeFlightPlanICAOs.contains(airport.icao) {
            filled.insert(airport.icao)
        }
        return filled
    }

    /// All known airport coordinates keyed by ICAO, used for route line rendering.
    var airportCoordinates: [String: CLLocationCoordinate2D] {
        Dictionary(
            airports.map { ($0.icao, CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    // MARK: - Friend CID Helpers

    /// Returns the set of airport ICAOs where a tracked CID is the active controller.
    func friendControlledAirportICAOs(friendCIDs: Set<Int>) -> Set<String> {
        guard !friendCIDs.isEmpty else { return [] }
        var result = Set<String>()
        for airport in airports {
            if let controller = airport.activeController, friendCIDs.contains(controller.cid) {
                result.insert(airport.icao)
            }
        }
        return result
    }

    /// Traffic data for the currently selected airport, derived from live pilots and prefiles.
    var selectedAirportTraffic: AirportTraffic? {
        guard let icao = selectedAirportICAO else { return nil }
        let upperICAO = icao.uppercased()
        let groundSpeedThreshold = 40

        var airborneDep: [Pilot] = []
        var airborneArr: [Pilot] = []
        var groundDep: [Pilot] = []
        var groundArr: [Pilot] = []

        for pilot in pilots {
            guard let fp = pilot.flight_plan else { continue }
            let isDeparture = fp.departure.uppercased() == upperICAO
            let isArrival   = fp.arrival.uppercased()   == upperICAO
            guard isDeparture || isArrival else { continue }

            let isOnGround = pilot.groundspeed < groundSpeedThreshold

            if isDeparture {
                if isOnGround { groundDep.append(pilot) }
                else { airborneDep.append(pilot) }
            }
            if isArrival {
                if isOnGround { groundArr.append(pilot) }
                else { airborneArr.append(pilot) }
            }
        }

        let prefileDep = prefiles.filter { $0.flight_plan?.departure.uppercased() == upperICAO }
        let prefileArr = prefiles.filter { $0.flight_plan?.arrival.uppercased()   == upperICAO }

        return AirportTraffic(
            airborneDepartures: airborneDep,
            airborneArrivals:   airborneArr,
            groundDepartures:   groundDep,
            groundArrivals:     groundArr,
            prefileDepartures:  prefileDep,
            prefileArrivals:    prefileArr
        )
    }
}

// MARK: - AirportTraffic

struct AirportTraffic {
    /// Airborne pilots with this airport as departure (groundspeed >= 40 kt)
    let airborneDepartures: [Pilot]
    /// Airborne pilots with this airport as arrival (groundspeed >= 40 kt)
    let airborneArrivals: [Pilot]
    /// On-ground pilots with this airport as departure (groundspeed < 40 kt)
    let groundDepartures: [Pilot]
    /// On-ground pilots with this airport as arrival (groundspeed < 40 kt)
    let groundArrivals: [Pilot]
    /// Prefiled plans departing from this airport (no live position)
    let prefileDepartures: [Prefiles]
    /// Prefiled plans arriving at this airport (no live position)
    let prefileArrivals: [Prefiles]

    var totalDepartures: Int {
        airborneDepartures.count + groundDepartures.count + prefileDepartures.count
    }
    var totalArrivals: Int {
        airborneArrivals.count + groundArrivals.count + prefileArrivals.count
    }
    var totalOnGround: Int {
        groundDepartures.count + groundArrivals.count
    }
    /// All airborne pilots (departures + arrivals) — used to draw airport-to-pilot lines.
    var allAirbornePilots: [Pilot] {
        airborneDepartures + airborneArrivals
    }
}
