//
//  RadarViewRepresentable.swift
//  VatSight
//

import SwiftUI
import MapboxMaps
import CoreLocation

struct RadarViewRepresentable: UIViewRepresentable {

    @ObservedObject var viewModel: RadarViewModel

    let prefsManager: PreferencesManager

    func makeCoordinator() -> Coordinator {

        Coordinator(
            viewModel: viewModel,
            prefsManager: prefsManager
        )
    }

    // MARK: - Create MapView

    func makeUIView(
        context: Context
    ) -> MapView {

        let cameraOptions = CameraOptions(
            center: CLLocationCoordinate2D(
                latitude: prefsManager.userPrefs.lastLatitude,
                longitude: prefsManager.userPrefs.lastLongitude
            ),
            zoom: prefsManager.userPrefs.lastZoom
        )

        let initOptions = MapInitOptions(
            cameraOptions: cameraOptions,
            styleURI: StyleURI(
                rawValue: "mapbox://styles/marcelm005/cmovo48xo002201s30ohu1t9r"
            )!
        )

        let mapView = MapView(
            frame: .zero,
            mapInitOptions: initOptions
        )
        
        mapView.gestures.options.pitchEnabled = false

        context.coordinator.mapView = mapView
        context.coordinator.configureOrnaments(for: mapView)

        // STYLE LOADED

        // Layer order from bottom to top: sectors → airports → routes → pilots → sector labels
        mapView.mapboxMap.onMapLoaded.observeNext { [weak coordinator = context.coordinator] _ in
            coordinator?.installSectorStyleIfNeeded()
            coordinator?.installAirportStyleIfNeeded()
            coordinator?.installRouteStyleIfNeeded()
            coordinator?.installPilotStyleIfNeeded()
            coordinator?.ensureLabelsOnTop()
        }
        .store(in: &context.coordinator.cancelables)

        // CAMERA CHANGES

        mapView.mapboxMap.onCameraChanged.observe { [weak coordinator = context.coordinator] event in
            guard let coordinator else {
                return
            }

            let camera = event.cameraState

            coordinator.prefsManager.userPrefs.lastZoom = camera.zoom
            coordinator.prefsManager.userPrefs.lastLatitude = camera.center.latitude
            coordinator.prefsManager.userPrefs.lastLongitude = camera.center.longitude
        }
        .store(in: &context.coordinator.cancelables)

        context.coordinator.installTapInteractions()
        return mapView
    }

    // MARK: - Update UIView

    func updateUIView(
        _ mapView: MapView,
        context: Context
    ) {
        let friendCIDs = prefsManager.allFriendCIDs
        let friendControlledICAOs = viewModel.friendControlledAirportICAOs(friendCIDs: friendCIDs)

        context.coordinator.updatePilots(
            viewModel.pilots,
            selectedCID: viewModel.selectedCID,
            friendCIDs: friendCIDs
        )
        
        context.coordinator.updateSectors(
            viewModel.sectorsToDisplay,
            controllers: viewModel.effectiveControllers,
            airports: viewModel.airportsToDisplay,
            selectedControllerCID: viewModel.selectedSectorControllerCID,
            friendCIDs: friendCIDs
        )
        
        context.coordinator.updateAirports(
            viewModel.airportsToDisplay,
            filledICAOs: viewModel.filledAirportICAOs,
            selectedICAO: viewModel.selectedAirportICAO,
            friendControlledICAOs: friendControlledICAOs
        )

        context.coordinator.updateRoutes(
            pilot: viewModel.selectedPilot,
            airportCoordinates: viewModel.airportCoordinates,
            selectedAirportICAO: viewModel.selectedAirportICAO,
            airportTraffic: viewModel.selectedAirportTraffic
        )

        if let coordinate = viewModel.pendingCameraFlyTo {
            context.coordinator.flyTo(coordinate: coordinate)
            DispatchQueue.main.async { viewModel.pendingCameraFlyTo = nil }
        }

    }

    // MARK: - Coordinator

    final class Coordinator {
        weak var mapView: MapView?
        var cancelables = Set<AnyCancelable>()
        let viewModel: RadarViewModel
        let prefsManager: PreferencesManager
        private let pilotStyleManager = RadarStyleManager()
        private let sectorStyleManager = SectorStyleManager()
        private let airportStyleManager = AirportStyleManager()
        private let routeStyleManager = FlightRouteStyleManager()
        private var didInstallPilotStyle = false
        private var didInstallSectorStyle = false
        private var didInstallAirportStyle = false
        private var didInstallRouteStyle = false

        // Last-seen values — used to skip redundant Mapbox source updates.
        private var lastPilots: [Pilot] = []
        private var lastSelectedCID: Int? = nil
        private var lastFriendCIDs: Set<Int> = []
        private var lastSectors: [VatglassesSector] = []
        private var lastActiveSectorCount: Int = -1
        private var lastOwnershipSignature: Int = 0
        private var lastSelectedControllerCID: Int? = nil
        private var lastAirports: [VatglassesAirport] = []
        private var lastFilledICAOs: Set<String> = []
        private var lastSelectedAirportICAO: String? = nil
        private var lastFriendControlledICAOs: Set<String> = []
        private var lastRoutePilotCID: Int? = nil
        private var lastRouteAirportICAO: String? = nil
        /// Incremented each time pilots data is pushed to the map; used to trigger
        /// route redraws when aircraft positions change while the same selection is active.
        private var pilotsVersion: Int = 0
        private var lastRoutePilotsVersion: Int = -1
        // MARK: - Init

        init(
            viewModel: RadarViewModel,
            prefsManager: PreferencesManager
        ) {
            self.viewModel = viewModel
            self.prefsManager = prefsManager
        }

        // MARK: - Install Style

        func installPilotStyleIfNeeded() {

            guard let mapView else {
                return
            }

            guard !didInstallPilotStyle else {
                return
            }

            do {
                try pilotStyleManager.configurePilots(on: mapView)
                didInstallPilotStyle = true
                pilotStyleManager.updatePilots(
                    on: mapView,
                    pilots: viewModel.pilots,
                    selectedCID: viewModel.selectedCID,
                    friendCIDs: prefsManager.allFriendCIDs
                )
            } catch {
                print("Failed to configure pilot style:", error)
            }
        }
        
        func installSectorStyleIfNeeded() {
            guard let mapView else {
                return
            }
            
            guard !didInstallSectorStyle else {
                return
            }
            
            do {
                try sectorStyleManager.configureSectors(on: mapView)
                didInstallSectorStyle = true
                sectorStyleManager.updateSectors(
                    on: mapView,
                    sectors: viewModel.sectorsToDisplay,
                    controllers: viewModel.effectiveControllers,
                    airports: viewModel.airportsToDisplay,
                    friendCIDs: prefsManager.allFriendCIDs
                )
            } catch {
                print("Failed to configure sector style:", error)
            }
        }
        
        func installAirportStyleIfNeeded() {
            guard let mapView else {
                return
            }
            
            guard !didInstallAirportStyle else {
                return
            }
            
            do {
                try airportStyleManager.configureAirports(on: mapView)
                didInstallAirportStyle = true
                let friendCIDs = prefsManager.allFriendCIDs
                airportStyleManager.updateAirports(
                    on: mapView,
                    airports: viewModel.airportsToDisplay,
                    filledICAOs: viewModel.filledAirportICAOs,
                    friendControlledICAOs: viewModel.friendControlledAirportICAOs(friendCIDs: friendCIDs)
                )
            } catch {
                print("Failed to configure airport style:", error)
            }
        }
        
        func installRouteStyleIfNeeded() {
            guard let mapView else { return }
            guard !didInstallRouteStyle else { return }

            do {
                try routeStyleManager.configureRoutes(on: mapView)
                didInstallRouteStyle = true
                updateRoutes(
                    pilot: viewModel.selectedPilot,
                    airportCoordinates: viewModel.airportCoordinates,
                    selectedAirportICAO: viewModel.selectedAirportICAO,
                    airportTraffic: viewModel.selectedAirportTraffic
                )
            } catch {
                print("Failed to configure route style:", error)
            }
        }

        func ensureLabelsOnTop() {
            guard let mapView else { return }
            if didInstallSectorStyle {
                sectorStyleManager.ensureSectorLabelIsOnTop(on: mapView)
            }
            if didInstallAirportStyle {
                airportStyleManager.ensureAirportLabelIsOnTop(on: mapView)
            }
        }

        // MARK: - Camera

        func flyTo(coordinate: CLLocationCoordinate2D) {
            guard let mapView else { return }
            let camera = CameraOptions(center: coordinate, zoom: max(mapView.mapboxMap.cameraState.zoom, 7))
            mapView.camera.ease(to: camera, duration: 0.6)
        }

        // MARK: - Configure Ornaments
        
        func configureOrnaments(for mapView: MapView) {
            mapView.ornaments.options.scaleBar.visibility = .hidden
            mapView.ornaments.options.compass.position = .topLeading
            mapView.ornaments.options.compass.margins = CGPoint(x: 8, y: 8)
            mapView.ornaments.options.attributionButton.position = .bottomLeading
            mapView.ornaments.options.attributionButton.margins = CGPoint(x: 85, y: 6)
            mapView.ornaments.options.logo.position = .bottomLeading
        }

        // MARK: - Update GeoJSON Source

        func updatePilots(
            _ pilots: [Pilot],
            selectedCID: Int?,
            friendCIDs: Set<Int> = []
        ) {
            guard let mapView, didInstallPilotStyle else { return }
            guard pilots.count != lastPilots.count || selectedCID != lastSelectedCID || friendCIDs != lastFriendCIDs else { return }
            lastPilots = pilots
            lastSelectedCID = selectedCID
            lastFriendCIDs = friendCIDs
            pilotsVersion += 1

            pilotStyleManager.updatePilots(
                on: mapView,
                pilots: pilots,
                selectedCID: selectedCID,
                friendCIDs: friendCIDs
            )
        }
        
        func updateSectors(
            _ sectors: [VatglassesSector],
            controllers: [Controllers],
            airports: [VatglassesAirport] = [],
            selectedControllerCID: Int? = nil,
            friendCIDs: Set<Int> = []
        ) {
            guard let mapView, didInstallSectorStyle else { return }
            let activeSectorCount = sectors.filter { $0.isActive }.count
            // Hash the active owner assignment per sector so that ownership transfers
            // (same count, different controllers) are also detected.
            let ownershipSignature = sectors.reduce(into: 0) { hash, sector in
                hash ^= sector.id.hashValue
                hash ^= (sector.activeController?.cid ?? -1).hashValue
            }
            guard sectors.count != lastSectors.count
                    || activeSectorCount != lastActiveSectorCount
                    || ownershipSignature != lastOwnershipSignature
                    || selectedControllerCID != lastSelectedControllerCID
                    || friendCIDs != lastFriendCIDs else { return }
            lastSectors = sectors
            lastActiveSectorCount = activeSectorCount
            lastOwnershipSignature = ownershipSignature
            lastSelectedControllerCID = selectedControllerCID

            sectorStyleManager.updateSectors(
                on: mapView,
                sectors: sectors,
                controllers: controllers,
                airports: airports,
                selectedControllerCID: selectedControllerCID,
                friendCIDs: friendCIDs
            )
        }
        
        func updateAirports(
            _ airports: [VatglassesAirport],
            filledICAOs: Set<String>,
            selectedICAO: String? = nil,
            friendControlledICAOs: Set<String> = []
        ) {
            guard let mapView else { return }
            guard airports.count != lastAirports.count
                    || filledICAOs != lastFilledICAOs
                    || selectedICAO != lastSelectedAirportICAO
                    || friendControlledICAOs != lastFriendControlledICAOs else { return }
            lastAirports = airports
            lastFilledICAOs = filledICAOs
            lastSelectedAirportICAO = selectedICAO
            lastFriendControlledICAOs = friendControlledICAOs
            airportStyleManager.updateAirports(
                on: mapView,
                airports: airports,
                filledICAOs: filledICAOs,
                selectedICAO: selectedICAO,
                friendControlledICAOs: friendControlledICAOs
            )
        }

        func updateRoutes(
            pilot: Pilot?,
            airportCoordinates: [String: CLLocationCoordinate2D],
            selectedAirportICAO: String?,
            airportTraffic: AirportTraffic?
        ) {
            guard let mapView else { return }
            let incomingPilotCID = pilot?.cid
            guard incomingPilotCID != lastRoutePilotCID
                    || selectedAirportICAO != lastRouteAirportICAO
                    || pilotsVersion != lastRoutePilotsVersion else { return }
            lastRoutePilotCID = incomingPilotCID
            lastRouteAirportICAO = selectedAirportICAO
            lastRoutePilotsVersion = pilotsVersion

            if let pilot {
                // A pilot is selected — draw pilot-to-airport lines
                routeStyleManager.updateRoutes(
                    on: mapView,
                    pilot: pilot,
                    airportCoordinates: airportCoordinates
                )
            } else if let icao = selectedAirportICAO,
                      let traffic = airportTraffic,
                      let airportCoord = airportCoordinates[icao] {
                // An airport is selected — draw colour-coded airport-to-pilot lines
                routeStyleManager.updateAirportRoutes(
                    on: mapView,
                    airportCoordinate: airportCoord,
                    airborneDepartures: traffic.airborneDepartures,
                    airborneArrivals: traffic.airborneArrivals
                )
            } else {
                // Nothing selected — clear all lines
                routeStyleManager.updateRoutes(
                    on: mapView,
                    pilot: nil,
                    airportCoordinates: airportCoordinates
                )
            }
        }

        // MARK: - Tap Interaction

        func installTapInteractions() {

            guard let mapView else {
                return
            }

            let pilotInteraction = TapInteraction(
                .layer(RadarStyleManager.pilotIconLayerId)
            ) { [weak self] feature, context in

                guard let self else {
                    return false
                }

                let properties = feature.properties
                guard
                    let jsonValue = properties["cid"] ?? nil,
                    case let .number(cidNumber) = jsonValue
                else {
                    return false
                }

                self.viewModel.selectPilot(
                    cid: Int(cidNumber)
                )

                return true
            }

            mapView.mapboxMap.addInteraction(
                pilotInteraction
            )

            let labelInteraction = TapInteraction(
                .layer(RadarStyleManager.pilotLabelLayerId)
            ) { [weak self] feature, context in

                guard let self else {
                    return false
                }

                let properties = feature.properties
                guard
                    let jsonValue = properties["cid"] ?? nil,
                    case let .number(cidNumber) = jsonValue
                else {
                    return false
                }

                self.viewModel.selectPilot(
                    cid: Int(cidNumber)
                )

                return true
            }

            mapView.mapboxMap.addInteraction(
                labelInteraction
            )

            let pilotGroundIconInteraction = TapInteraction(
                .layer(RadarStyleManager.pilotGroundIconLayerId)
            ) { [weak self] feature, context in
                guard let self else { return false }
                guard
                    let jsonValue = feature.properties["cid"] ?? nil,
                    case let .number(cidNumber) = jsonValue
                else { return false }
                self.viewModel.selectPilot(cid: Int(cidNumber))
                return true
            }
            mapView.mapboxMap.addInteraction(pilotGroundIconInteraction)

            let pilotGroundLabelInteraction = TapInteraction(
                .layer(RadarStyleManager.pilotGroundLabelLayerId)
            ) { [weak self] feature, context in
                guard let self else { return false }
                guard
                    let jsonValue = feature.properties["cid"] ?? nil,
                    case let .number(cidNumber) = jsonValue
                else { return false }
                self.viewModel.selectPilot(cid: Int(cidNumber))
                return true
            }
            mapView.mapboxMap.addInteraction(pilotGroundLabelInteraction)

            // Airport circle tap
            let airportCircleInteraction = TapInteraction(
                .layer(AirportStyleManager.airportLayerId)
            ) { [weak self] feature, context in
                guard let self else { return false }
                guard
                    let jsonValue = feature.properties["icao"] ?? nil,
                    case let .string(icao) = jsonValue
                else { return false }
                DispatchQueue.main.async { self.viewModel.selectAirport(icao: icao) }
                return true
            }
            mapView.mapboxMap.addInteraction(airportCircleInteraction)

            // Airport label tap
            let airportLabelInteraction = TapInteraction(
                .layer(AirportStyleManager.airportLabelLayerId)
            ) { [weak self] feature, context in
                guard let self else { return false }
                guard
                    let jsonValue = feature.properties["icao"] ?? nil,
                    case let .string(icao) = jsonValue
                else { return false }
                DispatchQueue.main.async { self.viewModel.selectAirport(icao: icao) }
                return true
            }
            mapView.mapboxMap.addInteraction(airportLabelInteraction)

            // Sector label tap
            let sectorLabelInteraction = TapInteraction(
                .layer(SectorStyleManager.sectorLabelLayerId)
            ) { [weak self] feature, context in
                guard let self else { return false }
                guard
                    let jsonValue = feature.properties["id"] ?? nil,
                    case let .string(sectorId) = jsonValue
                else { return false }
                DispatchQueue.main.async { self.viewModel.selectSector(id: sectorId) }
                return true
            }
            mapView.mapboxMap.addInteraction(sectorLabelInteraction)

            let mapTapInteraction = TapInteraction { [weak self] context in
                guard let self else { return false }
                self.viewModel.dismissPilotSheet()
                self.viewModel.dismissAirportSheet()
                self.viewModel.dismissSectorSheet()
                return true
            }
            mapView.mapboxMap.addInteraction(mapTapInteraction)
        }
    }
}



