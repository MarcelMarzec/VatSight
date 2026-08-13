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
            coordinator?.ensureSectorLabelsOnTop()
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
        context.coordinator.updatePilots(
            viewModel.pilots,
            selectedCID: viewModel.selectedCID
        )
        
        context.coordinator.updateSectors(
            viewModel.sectorsToDisplay,
            controllers: viewModel.controllers
        )
        
        context.coordinator.updateAirports(viewModel.airportsToDisplay, filledICAOs: viewModel.filledAirportICAOs)

        context.coordinator.updateRoutes(
            pilot: viewModel.selectedPilot,
            airportCoordinates: viewModel.airportCoordinates
        )
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
                    selectedCID: viewModel.selectedCID
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
                    sectors: viewModel.sectors,
                    controllers: viewModel.controllers
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
                airportStyleManager.updateAirports(
                    on: mapView,
                    airports: viewModel.airportsToDisplay,
                    filledICAOs: viewModel.filledAirportICAOs
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
                routeStyleManager.updateRoutes(
                    on: mapView,
                    pilot: viewModel.selectedPilot,
                    airportCoordinates: viewModel.airportCoordinates
                )
            } catch {
                print("Failed to configure route style:", error)
            }
        }

        func ensureSectorLabelsOnTop() {
            guard let mapView, didInstallSectorStyle else {
                return
            }
            sectorStyleManager.ensureSectorLabelIsOnTop(on: mapView)
        }
        
        // MARK: - Configure Ornaments
        
        func configureOrnaments(for mapView: MapView) {
            mapView.ornaments.options.scaleBar.visibility = .hidden
            mapView.ornaments.options.compass.position = .topTrailing
            mapView.ornaments.options.compass.margins = CGPoint(x: 8, y: 8)
            mapView.ornaments.options.attributionButton.position = .bottomLeading
            mapView.ornaments.options.attributionButton.margins = CGPoint(x: 85, y: 6)
            mapView.ornaments.options.logo.position = .bottomLeading
        }

        // MARK: - Update GeoJSON Source

        func updatePilots(
            _ pilots: [Pilot],
            selectedCID: Int?
        ) {

            guard let mapView, didInstallPilotStyle else { return }

            pilotStyleManager.updatePilots(
                on: mapView,
                pilots: pilots,
                selectedCID: selectedCID
            )
        }
        
        func updateSectors(
            _ sectors: [VatglassesSector],
            controllers: [Controllers]
        ) {
            guard let mapView, didInstallSectorStyle else { return }
            
            sectorStyleManager.updateSectors(
                on: mapView,
                sectors: sectors,
                controllers: controllers
            )
        }
        
        func updateAirports(_ airports: [VatglassesAirport], filledICAOs: Set<String>) {
            guard let mapView else { return }
            airportStyleManager.updateAirports(on: mapView, airports: airports, filledICAOs: filledICAOs)
        }

        func updateRoutes(pilot: Pilot?, airportCoordinates: [String: CLLocationCoordinate2D]) {
            guard let mapView else { return }
            routeStyleManager.updateRoutes(on: mapView, pilot: pilot, airportCoordinates: airportCoordinates)
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
            
            let mapTapInteraction = TapInteraction { [weak self] context in

                    guard let self else {
                        return false
                    }

                    self.viewModel.dismissPilotSheet()

                    return true
                }

                mapView.mapboxMap.addInteraction(mapTapInteraction)
        }
    }
}
