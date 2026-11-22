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

    @Environment(\.colorScheme) private var systemColorScheme

    private var isDark: Bool {
        switch prefsManager.userPrefs.appTheme {
        case .system: return systemColorScheme == .dark
        case .dark:   return true
        case .light:  return false
        }
    }

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

        let resolvedURLStr = prefsManager.userPrefs.mapStyle.resolvedURLString(isDark: isDark) ?? MapStyle.dark.rawValue
        let initOptions = MapInitOptions(
            cameraOptions: cameraOptions,
            styleURI: StyleURI(rawValue: resolvedURLStr)!
        )

        let mapView = MapView(
            frame: .zero,
            mapInitOptions: initOptions
        )
        
        mapView.gestures.options.pitchEnabled = false

        context.coordinator.mapView = mapView
        context.coordinator.configureOrnaments(for: mapView)

        mapView.mapboxMap.onMapLoaded.observeNext { [weak coordinator = context.coordinator] _ in
            coordinator?.installSectorStyleIfNeeded()
            coordinator?.installAirportStyleIfNeeded()
            coordinator?.installRouteStyleIfNeeded()
            coordinator?.installPilotStyleIfNeeded()
            coordinator?.ensureLabelsOnTop()
        }
        .store(in: &context.coordinator.cancelables)

        mapView.mapboxMap.onCameraChanged.observe { [weak coordinator = context.coordinator] event in
            guard let coordinator else { return }
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
        let resolvedIsDark = isDark
        context.coordinator.currentIsDark = resolvedIsDark

        let newThemeRaw = prefsManager.userPrefs.appTheme.rawValue
        guard let resolvedURLStr = prefsManager.userPrefs.mapStyle.resolvedURLString(isDark: resolvedIsDark),
              let resolvedStyleURI = StyleURI(rawValue: resolvedURLStr) else { return }
        let resolvedStyleString = resolvedURLStr

        if context.coordinator.lastResolvedStyleURIString != resolvedStyleString {
            context.coordinator.lastMapStyleRaw = prefsManager.userPrefs.mapStyle.rawValue
            context.coordinator.lastAppThemeRaw = newThemeRaw
            context.coordinator.lastResolvedStyleURIString = resolvedStyleString
            context.coordinator.didInstallPilotStyle = false
            context.coordinator.didInstallSectorStyle = false
            context.coordinator.didInstallAirportStyle = false
            context.coordinator.didInstallRouteStyle = false
            mapView.mapboxMap.loadStyle(resolvedStyleURI) { [weak coordinator = context.coordinator] _ in
                coordinator?.installSectorStyleIfNeeded()
                coordinator?.installAirportStyleIfNeeded()
                coordinator?.installRouteStyleIfNeeded()
                coordinator?.installPilotStyleIfNeeded()
                coordinator?.ensureLabelsOnTop()
            }
        } else if context.coordinator.lastAppThemeRaw != newThemeRaw {
            context.coordinator.lastAppThemeRaw = newThemeRaw
            context.coordinator.applyTheme(on: mapView, isDark: resolvedIsDark)
        }

        let newPlaneMultiplier = prefsManager.userPrefs.planeIconMultiplier
        if context.coordinator.lastPlaneIconMultiplier != newPlaneMultiplier {
            context.coordinator.lastPlaneIconMultiplier = newPlaneMultiplier
            context.coordinator.applyPlaneIconSize(on: mapView, multiplier: newPlaneMultiplier)
        }

        let newAirportMultiplier = prefsManager.userPrefs.airportIconMultiplier
        if context.coordinator.lastAirportIconMultiplier != newAirportMultiplier {
            context.coordinator.lastAirportIconMultiplier = newAirportMultiplier
            context.coordinator.applyAirportIconSize(on: mapView, multiplier: newAirportMultiplier)
        }

        let friendCIDs = prefsManager.allFriendCIDs
        let friendControlledICAOs = viewModel.friendControlledAirportICAOs(friendCIDs: friendCIDs)

        let myCID = prefsManager.myCID

        let fadeICAO = context.coordinator.appliedFadeICAO

        context.coordinator.updatePilots(
            viewModel.pilotsToDisplay,
            revision: viewModel.pilotsRevision,
            selectedCID: viewModel.selectedCID,
            friendCIDs: friendCIDs,
            myCID: myCID,
            dimAirportICAO: fadeICAO
        )
        
        context.coordinator.updateSectors(
            viewModel.sectorsToDisplay,
            controllers: viewModel.effectiveControllers,
            airports: viewModel.airportsToDisplay,
            selectedControllerCID: viewModel.selectedSectorControllerCID,
            friendCIDs: friendCIDs,
            myCID: myCID
        )
        
        context.coordinator.updateAirports(
            viewModel.airportsToDisplay,
            filledICAOs: viewModel.filledAirportICAOs,
            selectedICAO: viewModel.selectedAirportICAO,
            friendControlledICAOs: friendControlledICAOs,
            highlights: viewModel.airportHighlights,
            connectedICAOs: viewModel.airportConnections(for: fadeICAO),
            activitySignature: viewModel.airportActivitySignature
        )

        context.coordinator.updateBookedSectors(
            viewModel.bookedSectorsToDisplay,
            approximateBookingIDs: viewModel.approximateBookingIDs,
            airports: viewModel.airportsToDisplay,
            timeDisplay: prefsManager.userPrefs.eventTimeDisplay
        )

        context.coordinator.updateRoutes(
            pilot: viewModel.selectedPilot,
            airportCoordinates: viewModel.airportCoordinates,
            selectedAirportICAO: viewModel.selectedAirportICAO,
            airportTraffic: viewModel.selectedAirportTraffic
        )

        // Fade airports and aircraft not connected to the selected airport (animated).
        context.coordinator.updateFadeTarget(viewModel.selectedAirportICAO)

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
        private let bookedSectorStyleManager = BookedSectorStyleManager()
        private var didInstallBookedSectorStyle = false
        private var lastBookedSectorSignature: [String] = []
        private var lastBookedTimeDisplay: EventTimeDisplay?
        private var lastAirportHighlights: [String: AirportHighlight] = [:]
        private var lastConnectedICAOs: Set<String>? = nil
        private var lastPilotDimICAO: String? = nil

        // MARK: Fade state
        /// The airport the map's faded/unfaded split currently reflects. Lags the selection
        /// while a fade-out runs, so features never jump between faded and unfaded mid-fade.
        fileprivate private(set) var appliedFadeICAO: String? = nil
        private var fadeTargetICAO: String? = nil
        private var fadeProgress: Double = 0
        private let fadeAnimator = MapFadeAnimator()
        fileprivate var didInstallPilotStyle = false
        fileprivate var didInstallSectorStyle = false
        fileprivate var didInstallAirportStyle = false
        fileprivate var didInstallRouteStyle = false
        fileprivate var lastMapStyleRaw: String = ""
        fileprivate var lastAppThemeRaw: String = ""
        fileprivate var lastPlaneIconMultiplier: Double = -1
        fileprivate var lastAirportIconMultiplier: Double = -1
        fileprivate var lastResolvedStyleURIString: String = ""
        fileprivate var currentIsDark: Bool = true

        private var lastPilotCount: Int = -1
        private var lastPilotsRevision: Int = -1
        private var lastSelectedCID: Int? = nil
        // Pilots and sectors track friends/self separately: sharing them meant whichever
        // updated first consumed the change and the other never redrew.
        private var lastPilotFriendCIDs: Set<Int> = []
        private var lastPilotMyCID: Int = 0
        private var lastSectorFriendCIDs: Set<Int> = []
        private var lastSectorMyCID: Int = 0
        private var lastSectorCount: Int = -1
        private var lastActiveSectorCount: Int = -1
        private var lastOwnershipSignature: Int = 0
        private var lastSelectedControllerCID: Int? = nil
        private var lastAirportCount: Int = -1
        private var lastAirportActivitySignature: Int = 0
        private var lastFilledICAOs: Set<String> = []
        private var lastSelectedAirportICAO: String? = nil
        private var lastFriendControlledICAOs: Set<String> = []
        private var lastRoutePilotCID: Int? = nil
        private var lastRouteAirportICAO: String? = nil
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
            guard let mapView, !didInstallPilotStyle else { return }
            let isDark = currentIsDark
            let planeIconMultiplier = prefsManager.userPrefs.planeIconMultiplier
            do {
                try pilotStyleManager.configurePilots(on: mapView, isDark: isDark, planeIconMultiplier: planeIconMultiplier)
                didInstallPilotStyle = true
                pilotStyleManager.applyDimProgress(fadeProgress, on: mapView)
                pilotStyleManager.updatePilots(
                    on: mapView,
                    pilots: viewModel.pilotsToDisplay,
                    selectedCID: viewModel.selectedCID,
                    friendCIDs: prefsManager.allFriendCIDs,
                    myCID: prefsManager.myCID,
                    dimAirportICAO: appliedFadeICAO
                )
            } catch { }
        }
        
        func installSectorStyleIfNeeded() {
            guard let mapView, !didInstallSectorStyle else { return }
            let isDark = currentIsDark
            do {
                try sectorStyleManager.configureSectors(on: mapView, isDark: isDark)
                didInstallSectorStyle = true
                installBookedSectorStyle(on: mapView, isDark: isDark)
                sectorStyleManager.updateSectors(
                    on: mapView,
                    sectors: viewModel.sectorsToDisplay,
                    controllers: viewModel.effectiveControllers,
                    airports: viewModel.airportsToDisplay,
                    friendCIDs: prefsManager.allFriendCIDs,
                    myCID: prefsManager.myCID
                )
            } catch { }
        }
        
        /// Booked-sector layers sit directly above the live sector layers and below airports.
        private func installBookedSectorStyle(on mapView: MapView, isDark: Bool) {
            bookedSectorStyleManager.removeLayers(from: mapView)
            do {
                try bookedSectorStyleManager.configure(on: mapView, isDark: isDark)
                didInstallBookedSectorStyle = true
                lastBookedSectorSignature = []
                lastBookedTimeDisplay = nil
                updateBookedSectors(
                    viewModel.bookedSectorsToDisplay,
                    approximateBookingIDs: viewModel.approximateBookingIDs,
                    airports: viewModel.airportsToDisplay,
                    timeDisplay: prefsManager.userPrefs.eventTimeDisplay
                )
            } catch {
                didInstallBookedSectorStyle = false
            }
        }

        func updateBookedSectors(
            _ bookedSectors: [BookedSector],
            approximateBookingIDs: Set<Int>,
            airports: [VatglassesAirport],
            timeDisplay: EventTimeDisplay
        ) {
            guard let mapView, didInstallBookedSectorStyle else { return }
            let signature = bookedSectors.map {
                "\($0.sector.id)#\($0.booking.id)\(approximateBookingIDs.contains($0.booking.id) ? "~" : "")"
            }
            guard signature != lastBookedSectorSignature || timeDisplay != lastBookedTimeDisplay else { return }
            lastBookedSectorSignature = signature
            lastBookedTimeDisplay = timeDisplay
            bookedSectorStyleManager.update(
                on: mapView,
                bookedSectors: bookedSectors,
                approximateBookingIDs: approximateBookingIDs,
                airports: airports,
                timeDisplay: timeDisplay
            )
        }

        func installAirportStyleIfNeeded() {
            guard let mapView, !didInstallAirportStyle else { return }
            let isDark = currentIsDark
            let airportIconMultiplier = prefsManager.userPrefs.airportIconMultiplier
            do {
                try airportStyleManager.configureAirports(on: mapView, isDark: isDark, airportIconMultiplier: airportIconMultiplier)
                didInstallAirportStyle = true
                let friendCIDs = prefsManager.allFriendCIDs
                airportStyleManager.updateAirports(
                    on: mapView,
                    airports: viewModel.airportsToDisplay,
                    filledICAOs: viewModel.filledAirportICAOs,
                    friendControlledICAOs: viewModel.friendControlledAirportICAOs(friendCIDs: friendCIDs),
                    highlights: viewModel.airportHighlights,
                    connectedICAOs: viewModel.airportConnections(for: appliedFadeICAO)
                )
                airportStyleManager.applyDimProgress(fadeProgress, on: mapView)
                lastAirportHighlights = viewModel.airportHighlights
            } catch { }
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
            } catch { }
        }

        func applyTheme(on mapView: MapView, isDark: Bool) {
            if didInstallPilotStyle {
                pilotStyleManager.applyTheme(on: mapView, isDark: isDark)
            }
            if didInstallAirportStyle {
                airportStyleManager.applyTheme(on: mapView, isDark: isDark)
            }
            if didInstallSectorStyle {
                sectorStyleManager.applyTheme(on: mapView, isDark: isDark)
            }
            if didInstallBookedSectorStyle {
                bookedSectorStyleManager.applyTheme(on: mapView, isDark: isDark)
            }
        }

        func applyPlaneIconSize(on mapView: MapView, multiplier: Double) {
            if didInstallPilotStyle {
                pilotStyleManager.applyPlaneIconSize(on: mapView, multiplier: multiplier)
            }
        }

        func applyAirportIconSize(on mapView: MapView, multiplier: Double) {
            if didInstallAirportStyle {
                airportStyleManager.applyAirportIconSize(on: mapView, multiplier: multiplier)
            }
        }

        /// Layer order bottom→top: sector fill/outline → airports → aircraft → airport labels → sector dot → sector pill.
        func ensureLabelsOnTop() {
            guard let mapView else { return }

            let orderedIds: [String] = [
                BookedSectorStyleManager.labelLayerId,
                AirportStyleManager.airportHaloLayerId,
                AirportStyleManager.airportEventRingLayerId,
                AirportStyleManager.airportLayerId,
                RadarStyleManager.pilotGroundIconLayerId,
                RadarStyleManager.pilotIconLayerId,
                RadarStyleManager.pilotGroundLabelLayerId,
                RadarStyleManager.pilotLabelLayerId,
                AirportStyleManager.airportLabelLayerId,
                SectorStyleManager.sectorDotLayerId,
                SectorStyleManager.sectorLabelLayerId,
            ]

            for layerId in orderedIds {
                guard mapView.mapboxMap.layerExists(withId: layerId) else { continue }
                do {
                    switch layerId {
                    case AirportStyleManager.airportLayerId,
                         AirportStyleManager.airportHaloLayerId,
                         AirportStyleManager.airportEventRingLayerId:
                        let l = try mapView.mapboxMap.layer(withId: layerId, type: CircleLayer.self)
                        try mapView.mapboxMap.removeLayer(withId: layerId)
                        try mapView.mapboxMap.addLayer(l, layerPosition: nil)
                    default:
                        let l = try mapView.mapboxMap.layer(withId: layerId, type: SymbolLayer.self)
                        try mapView.mapboxMap.removeLayer(withId: layerId)
                        try mapView.mapboxMap.addLayer(l, layerPosition: nil)
                    }
                } catch { }
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
            revision: Int,
            selectedCID: Int?,
            friendCIDs: Set<Int> = [],
            myCID: Int = 0,
            dimAirportICAO: String? = nil
        ) {
            guard let mapView, didInstallPilotStyle else { return }
            guard pilots.count != lastPilotCount
                    || revision != lastPilotsRevision
                    || selectedCID != lastSelectedCID
                    || friendCIDs != lastPilotFriendCIDs
                    || myCID != lastPilotMyCID
                    || dimAirportICAO != lastPilotDimICAO else { return }
            lastPilotDimICAO = dimAirportICAO
            lastPilotCount = pilots.count
            lastPilotsRevision = revision
            lastSelectedCID = selectedCID
            lastPilotFriendCIDs = friendCIDs
            lastPilotMyCID = myCID
            pilotsVersion += 1

            pilotStyleManager.updatePilots(
                on: mapView,
                pilots: pilots,
                selectedCID: selectedCID,
                friendCIDs: friendCIDs,
                myCID: myCID,
                dimAirportICAO: dimAirportICAO
            )
        }

        // MARK: - Fading

        /// Moves the faded split towards `target` (the selected airport, or nil):
        /// nothing faded → fade in; faded → fade out, then swap to the new airport and fade in.
        func updateFadeTarget(_ target: String?) {
            let target = target?.uppercased()
            guard target != fadeTargetICAO else { return }
            fadeTargetICAO = target
            runFadeTransition()
        }

        private func runFadeTransition() {
            let target = fadeTargetICAO
            if appliedFadeICAO == target {
                animateFade(to: target == nil ? 0 : 1)
                return
            }
            if appliedFadeICAO == nil || fadeProgress == 0 {
                // Nothing visibly faded yet: switch the split now, then fade in.
                appliedFadeICAO = target
                pushFadeSplit()
                if target != nil { animateFade(to: 1) }
                return
            }
            animateFade(to: 0) { [weak self] in
                guard let self else { return }
                self.appliedFadeICAO = self.fadeTargetICAO
                self.pushFadeSplit()
                if self.fadeTargetICAO != nil { self.animateFade(to: 1) }
            }
        }

        private func animateFade(to value: Double, completion: (() -> Void)? = nil) {
            fadeAnimator.animate(
                from: fadeProgress,
                to: value,
                duration: 0.3,
                update: { [weak self] progress in self?.setFadeProgress(progress) },
                completion: completion
            )
        }

        private func setFadeProgress(_ progress: Double) {
            fadeProgress = progress
            guard let mapView else { return }
            if didInstallAirportStyle { airportStyleManager.applyDimProgress(progress, on: mapView) }
            if didInstallPilotStyle { pilotStyleManager.applyDimProgress(progress, on: mapView) }
        }

        /// Rebuilds the airport and aircraft sources with the current faded/unfaded split.
        private func pushFadeSplit() {
            let friendCIDs = prefsManager.allFriendCIDs
            updatePilots(
                viewModel.pilotsToDisplay,
                revision: viewModel.pilotsRevision,
                selectedCID: viewModel.selectedCID,
                friendCIDs: friendCIDs,
                myCID: prefsManager.myCID,
                dimAirportICAO: appliedFadeICAO
            )
            updateAirports(
                viewModel.airportsToDisplay,
                filledICAOs: viewModel.filledAirportICAOs,
                selectedICAO: viewModel.selectedAirportICAO,
                friendControlledICAOs: viewModel.friendControlledAirportICAOs(friendCIDs: friendCIDs),
                highlights: viewModel.airportHighlights,
                connectedICAOs: viewModel.airportConnections(for: appliedFadeICAO),
                activitySignature: viewModel.airportActivitySignature
            )
        }
        
        func updateSectors(
            _ sectors: [VatglassesSector],
            controllers: [Controllers],
            airports: [VatglassesAirport] = [],
            selectedControllerCID: Int? = nil,
            friendCIDs: Set<Int> = [],
            myCID: Int = 0
        ) {
            guard let mapView, didInstallSectorStyle else { return }
            let activeSectorCount = sectors.filter { $0.isActive }.count
            // Ordered hash of everything the sector layers draw. (The previous XOR fold cancelled
            // out whenever one controller owned an even number of sectors.)
            var hasher = Hasher()
            for sector in sectors {
                hasher.combine(sector.id)
                hasher.combine(sector.activeController?.cid)
                hasher.combine(sector.activeController?.callsign)
                hasher.combine(sector.activeController?.frequency)
            }
            let ownershipSignature = hasher.finalize()
            guard sectors.count != lastSectorCount
                    || activeSectorCount != lastActiveSectorCount
                    || ownershipSignature != lastOwnershipSignature
                    || selectedControllerCID != lastSelectedControllerCID
                    || friendCIDs != lastSectorFriendCIDs
                    || myCID != lastSectorMyCID else { return }
            lastSectorCount = sectors.count
            lastActiveSectorCount = activeSectorCount
            lastOwnershipSignature = ownershipSignature
            lastSelectedControllerCID = selectedControllerCID
            lastSectorFriendCIDs = friendCIDs
            lastSectorMyCID = myCID

            sectorStyleManager.updateSectors(
                on: mapView,
                sectors: sectors,
                controllers: controllers,
                airports: airports,
                selectedControllerCID: selectedControllerCID,
                friendCIDs: friendCIDs,
                myCID: myCID
            )
        }
        
        func updateAirports(
            _ airports: [VatglassesAirport],
            filledICAOs: Set<String>,
            selectedICAO: String? = nil,
            friendControlledICAOs: Set<String> = [],
            highlights: [String: AirportHighlight] = [:],
            connectedICAOs: Set<String>? = nil,
            activitySignature: Int = 0
        ) {
            guard let mapView else { return }
            guard airports.count != lastAirportCount
                    || activitySignature != lastAirportActivitySignature
                    || filledICAOs != lastFilledICAOs
                    || selectedICAO != lastSelectedAirportICAO
                    || friendControlledICAOs != lastFriendControlledICAOs
                    || highlights != lastAirportHighlights
                    || connectedICAOs != lastConnectedICAOs else { return }
            lastAirportCount = airports.count
            lastAirportActivitySignature = activitySignature
            lastFilledICAOs = filledICAOs
            lastSelectedAirportICAO = selectedICAO
            lastFriendControlledICAOs = friendControlledICAOs
            lastAirportHighlights = highlights
            lastConnectedICAOs = connectedICAOs
            airportStyleManager.updateAirports(
                on: mapView,
                airports: airports,
                filledICAOs: filledICAOs,
                selectedICAO: selectedICAO,
                friendControlledICAOs: friendControlledICAOs,
                highlights: highlights,
                connectedICAOs: connectedICAOs
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
                routeStyleManager.updateRoutes(
                    on: mapView,
                    pilot: pilot,
                    airportCoordinates: airportCoordinates
                )
            } else if let icao = selectedAirportICAO,
                      let traffic = airportTraffic,
                      let airportCoord = airportCoordinates[icao] {
                routeStyleManager.updateAirportRoutes(
                    on: mapView,
                    airportCoordinate: airportCoord,
                    airborneDepartures: traffic.airborneDepartures,
                    airborneArrivals: traffic.airborneArrivals
                )
            } else {
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

            let sectorDotInteraction = TapInteraction(
                .layer(SectorStyleManager.sectorDotLayerId)
            ) { [weak self] feature, context in
                guard let self else { return false }
                guard
                    let jsonValue = feature.properties["id"] ?? nil,
                    case let .string(sectorId) = jsonValue
                else { return false }
                DispatchQueue.main.async { self.viewModel.selectSector(id: sectorId) }
                return true
            }
            mapView.mapboxMap.addInteraction(sectorDotInteraction)

            let longPress = UILongPressGestureRecognizer(
                target: self,
                action: #selector(Coordinator.handleSectorLongPress(_:))
            )
            longPress.minimumPressDuration = 0.5
            mapView.addGestureRecognizer(longPress)

            let mapTapInteraction = TapInteraction { [weak self] context in
                guard let self else { return false }
                self.viewModel.dismissPilotSheet()
                self.viewModel.dismissAirportSheet()
                self.viewModel.dismissSectorSheet()
                return true
            }
            mapView.mapboxMap.addInteraction(mapTapInteraction)
        }

        @objc func handleSectorLongPress(_ recognizer: UILongPressGestureRecognizer) {
            guard recognizer.state == .began, let mapView else { return }

            let point = recognizer.location(in: mapView)
            let options = RenderedQueryOptions(
                layerIds: [SectorStyleManager.sectorFillLayerId],
                filter: nil
            )
            mapView.mapboxMap.queryRenderedFeatures(with: point, options: options) { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let features):
                    guard
                        let feature = features.first,
                        let jsonValue = feature.queriedFeature.feature.properties?["id"] ?? nil,
                        case let .string(sectorId) = jsonValue
                    else { return }
                    HapticManager.impact(.medium, prefsEnabled: self.viewModel.hapticFeedbackEnabled)
                    DispatchQueue.main.async { self.viewModel.selectSector(id: sectorId) }
                case .failure:
                    break
                }
            }
        }
    }
}



