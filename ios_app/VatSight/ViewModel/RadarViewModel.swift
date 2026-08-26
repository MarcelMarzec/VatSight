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
    /// Cached result of the last controller lookup for the selected airport.
    /// Updated when an airport is selected or when live data refreshes.
    @Published var controllersAtSelectedAirport: [Controllers] = []
    @Published var selectedSectorId: String?
    @Published var isShowingSectorSheet = false
    @Published var showInactiveSectors = false
    @Published var showAirports = false
    @Published var isLoadingData = true
    /// Set to a coordinate to request the map camera to fly there; cleared by the Representable after consuming.
    @Published var pendingCameraFlyTo: CLLocationCoordinate2D? = nil
    /// Currently selected altitude filter in feet (0 = GND). Sectors whose [min*100, max*100] range
    /// does not contain this value are hidden. Only active when `altitudeFilterEnabled` is true.
    @Published var selectedAltitudeFt: Double = 0
    /// When false, altitude filtering is bypassed and all sectors within the inactive-sectors toggle pass through.
    @Published var altitudeFilterEnabled = false

    // MARK: - Error / staleness state
    /// Set to true when the most recent VATSIM fetch failed.
    @Published var lastFetchFailed = false
    /// Timestamp of the last successful VATSIM data fetch.
    @Published var lastSuccessfulFetch: Date? = nil

    // MARK: - Debug overrides
    /// When non-empty, these controllers are injected on top of the live data for testing.
    @Published var debugControllers: [Controllers] = []

    /// ICAOs from active pilot flight plans, used to determine airport visibility.
    var activeFlightPlanICAOs: Set<String> = []
    
    private let vatsimService = VatsimService()
    private let vatglassesService = VatglassesService()
    private var timer: Timer?
    private var prefsManager: PreferencesManager?
    
    /// Tracks whether each of the two initial fetches has completed (success or failure).
    private var vatsimFetchDone = false
    private var sectorFetchDone = false
    
    private var refreshInterval: TimeInterval {
        prefsManager?.getRefreshIntervalInSeconds() ?? 15
    }
    
    func setPreferencesManager(_ manager: PreferencesManager) {
        self.prefsManager = manager
        self.showInactiveSectors = manager.userPrefs.showInactiveSectors
        self.showAirports = manager.userPrefs.showAirports
        self.altitudeFilterEnabled = manager.userPrefs.altitudeFilterEnabled
    }
    
    func startAutoRefresh() {
        guard timer == nil else { return }
        
        // Only show the loading indicator on first launch (no data yet)
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
                    self?.updateSectorActiveStatus()
                    self?.objectWillChange.send()
                    self?.sectorFetchDone = true
                    self?.dismissLoadingIfReady()
                }
            case .failure:
                // Fall back to cached data if available
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

    /// All known vatglasses positions keyed by their scoped ID (e.g. "epww/AH"), sorted by key.
    /// The key is needed to build a matchable VATSIM callsign and to distinguish positions
    /// that share the same human-readable name (e.g. two "EPWW Radar" entries).
    var allVatglassesPositions: [(key: String, position: VatglassesPosition)] {
        vatglassesService.getCachedPositions()
            .map { (key: $0.key, position: $0.value) }
            .sorted { $0.key < $1.key }
    }

    /// Live controllers merged with any active debug overrides — ready for map rendering.
    var effectiveControllers: [Controllers] {
        mergedWithDebugControllers(controllers)
    }

    /// Resolves a human-readable position label for a VATSIM callsign using the vatglasses
    /// callsigns definitions (e.g. "EGLL_TWR" → "Tower", "EPWA_P_DEL" → "Planner").
    /// Returns nil when no matching definition exists.
    func resolvePositionLabel(for callsign: String) -> String? {
        vatglassesService.resolvePositionLabel(for: callsign)
    }
    
    /// Dismisses the loading screen once both initial fetches have completed,
    /// regardless of whether they succeeded or failed.
    private func dismissLoadingIfReady() {
        if vatsimFetchDone && sectorFetchDone {
            isLoadingData = false
        }
    }

    /// Returns true if data is more than 2× the refresh interval old (i.e. at least one refresh was missed).
    var isDataStale: Bool {
        guard let last = lastSuccessfulFetch else { return false }
        return Date().timeIntervalSince(last) > (refreshInterval * 2)
    }

    /// When altitude filtering is on and a pilot is selected, keeps `selectedAltitudeFt`
    /// in sync with that pilot's latest reported altitude after each data refresh.
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
            sectors = vatglassesService.getActiveSectors(controllers: mergedControllers)
        }
    }

    /// Returns live controllers merged with any active debug overrides (debug entries take precedence by CID).
    private func mergedWithDebugControllers(_ live: [Controllers]) -> [Controllers] {
        guard !debugControllers.isEmpty else { return live }
        let debugCIDs = Set(debugControllers.map { $0.cid })
        return live.filter { !debugCIDs.contains($0.cid) } + debugControllers
    }

    /// Adds or removes a debug controller by its unique position key.
    /// The key is embedded in the controller name so we can match it back on toggle-off.
    func toggleDebugController(_ controller: Controllers) {
        if let idx = debugControllers.firstIndex(where: { $0.name == controller.name }) {
            debugControllers.remove(at: idx)
        } else {
            debugControllers.append(controller)
        }
        updateSectorActiveStatus()
        objectWillChange.send()
    }

    /// Returns true if a debug controller with the given position key is currently active.
    func isDebugControllerActive(positionKey: String) -> Bool {
        debugControllers.contains { $0.name == positionKey }
    }
    
    var selectedPilot: Pilot? {
        pilots.first { $0.cid == selectedCID }
    }
    
    var selectedAirport: VatglassesAirport? {
        airports.first { $0.icao == selectedAirportICAO }
    }
    
    /// Recomputes `controllersAtSelectedAirport` for the given airport.
    /// Call this whenever the selected airport or the live controller data changes.
    private func updateControllersAtSelectedAirport() {
        guard let icao = selectedAirportICAO else {
            controllersAtSelectedAirport = []
            return
        }

        let mergedControllers = mergedWithDebugControllers(controllers)
        // Direct controllers: try both the full ICAO and the shortened 3-letter variant
        let prefixes = vatglassesService.callsignPrefixes(for: icao)
        let directControllers = mergedControllers.filter { ctrl in
            let upper = ctrl.callsign.uppercased()
            guard !upper.hasSuffix("_ATIS") else { return false }
            return prefixes.contains { upper.hasPrefix($0 + "_") }
        }

        // Topdown controllers covering the airport via the ownership chain
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
        sectors.first { $0.id == selectedSectorId }
    }
    
    /// The CID of the controller owning the selected sector.
    /// Used to highlight all sectors that the same controller is responsible for.
    var selectedSectorControllerCID: Int? {
        selectedSector?.activeController?.cid
    }
    
    /// Sort order for controller positions (higher value = displayed first): CTR > APP > TWR > ATIS > GND > DEL
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
    
    /// Selects a pilot from a map tap (no camera fly-to).
    /// If tracking is already active, transfers it to the new pilot.
    func selectPilot(cid: Int) {
        openPilotSheet(cid: cid, flyTo: nil, enableTracking: false)
    }

    /// Selects a pilot, pans the camera, and opens the pilot sheet.
    func selectPilotAndFly(cid: Int, coordinate: CLLocationCoordinate2D, enableTracking: Bool = false) {
        openPilotSheet(cid: cid, flyTo: coordinate, enableTracking: enableTracking)
    }

    /// Shared implementation for all pilot selection paths.
    ///
    /// - If another sheet is open it is dismissed first; the pilot sheet stays open when
    ///   switching between pilots so the content updates without a flicker.
    /// - Tracking transfers automatically when it was already active, or when explicitly requested.
    /// - The altitude filter snaps to the selected aircraft's current altitude.
    private func openPilotSheet(cid: Int, flyTo coordinate: CLLocationCoordinate2D?, enableTracking: Bool) {
        // Dismiss non-pilot sheets.
        isShowingAirportSheet = false
        selectedAirportICAO = nil
        controllersAtSelectedAirport = []
        isShowingSectorSheet = false
        selectedSectorId = nil

        // Snap altitude filter to the selected aircraft's current altitude.
        if altitudeFilterEnabled, let pilot = pilots.first(where: { $0.cid == cid }) {
            selectedAltitudeFt = Double(pilot.altitude)
        }

        // Update selection — the sheet observes selectedPilot live, so it updates in-place
        // without needing a dismiss/re-present cycle.
        selectedCID = cid
        isShowingPilotSheet = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        if let coordinate {
            pendingCameraFlyTo = coordinate
        }
    }

    /// Dismisses all sheets, selects the airport, pans the camera, and opens the airport sheet.
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

    /// Returns the human-readable name for an airport ICAO, or nil if unknown.
    func airportName(for icao: String) -> String? {
        airports.first { $0.icao.uppercased() == icao.uppercased() }?.callsign
    }
    
    func dismissPilotSheet() {
        isShowingPilotSheet = false
        selectedCID = nil
    }

    /// Called by the sheet's onDismiss handler (user swipe-dismiss).
    /// Clears selection.
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
    
    func dismissSectorSheet() {
        isShowingSectorSheet = false
        selectedSectorId = nil
    }
    
    func toggleSectors() {
        showInactiveSectors.toggle()
        prefsManager?.updateShowInactiveSectors(showInactiveSectors)
    }

    func toggleAirports() {
        showAirports.toggle()
        prefsManager?.updateShowAirports(showAirports)
    }

    func toggleAltitudeFilter() {
        altitudeFilterEnabled.toggle()
        prefsManager?.updateAltitudeFilterEnabled(altitudeFilterEnabled)
    }

    /// The upper bound for the altitude slider, capped at FL600 (60 000 ft).
    var maxSectorAltitudeFt: Double { 60_000 }

    /// Sectors filtered by the inactive-sectors toggle and, when `altitudeFilterEnabled`, the selected altitude.
    /// A sector is included when `selectedAltitudeFt` falls within its [min*100, max*100] range.
    /// Sectors with no altitude properties are always shown.
    var sectorsToDisplay: [VatglassesSector] {
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

    /// Airports filtered by the show-all-airports toggle.
    /// When off, only airports with an active controller or appearing in a flight plan are shown.
    var airportsToDisplay: [VatglassesAirport] {
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
