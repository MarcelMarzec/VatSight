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
    @Published var allPositions: [String: VatglassesPosition] = [:]
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
    @Published var pendingNavigateToCID: Int? = nil
    @Published var pendingNavigateToSectorId: String? = nil
    @Published var pendingNavigateToSectorCoordinate: CLLocationCoordinate2D? = nil
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
    let vatglassesService = VatglassesService()
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
                    self?.allPositions = data.allPositions
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
                        self?.allPositions = self?.vatglassesService.getCachedPositions() ?? [:]
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

    func mergedWithDebugControllers(_ live: [Controllers]) -> [Controllers] {
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
    

    
    var selectedSector: VatglassesSector? {
        sectors.first(where: { $0.id == selectedSectorId })
            ?? mergedSectorsToDisplay.first { $0.id == selectedSectorId }
    }

    var selectedSectorControllerCID: Int? {
        selectedSector?.activeController?.cid
    }
    
    func positionOrder(_ callsign: String) -> Int {
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

}
