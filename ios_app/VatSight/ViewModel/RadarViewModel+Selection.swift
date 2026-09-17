//
//  RadarViewModel+Selection.swift
//  VatSight
//

import Foundation
import CoreLocation
import UIKit

// MARK: - Selection and Sheet Navigation
extension RadarViewModel {

    func selectPilot(cid: Int) {
        openPilotSheet(cid: cid, flyTo: nil, enableTracking: false)
    }

    func selectPilotAndFly(cid: Int, coordinate: CLLocationCoordinate2D, enableTracking: Bool = false) {
        openPilotSheet(cid: cid, flyTo: coordinate, enableTracking: enableTracking)
    }

    func openPilotSheet(cid: Int, flyTo coordinate: CLLocationCoordinate2D?, enableTracking: Bool) {
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

    func updateControllersAtSelectedAirport() {
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
}
