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

        // RESTORE SAVED CAMERA POSITION

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

        context.coordinator.mapView = mapView
        context.coordinator.configureOrnaments(for: mapView)

        // STYLE LOADED

        mapView.mapboxMap.onMapLoaded.observeNext { [weak coordinator = context.coordinator] _ in

            coordinator?.installPilotStyleIfNeeded()

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

        // INSTALL INTERACTIONS

        context.coordinator.installTapInteractions()

        return mapView
    }

    // MARK: - Update UIView

    func updateUIView(
        _ mapView: MapView,
        context: Context
    ) {

        context.coordinator.updatePilots(
            viewModel.pilots
        )
    }

    // MARK: - Coordinator

    final class Coordinator {

        weak var mapView: MapView?

        var cancelables = Set<AnyCancelable>()

        let viewModel: RadarViewModel

        let prefsManager: PreferencesManager

        private let styleManager = RadarStyleManager()

        private var didInstallStyle = false

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

            guard !didInstallStyle else {
                return
            }

            do {

                try styleManager.configurePilots(
                    on: mapView
                )

                didInstallStyle = true

                styleManager.updatePilots(
                    on: mapView,
                    pilots: viewModel.pilots
                )

            } catch {

                print("❌ Failed to configure pilot style:", error)
            }
        }
        
        // MARK: - Configure Ornaments
        
        func configureOrnaments(for mapView: MapView) {

            // SCALE BAR
            mapView.ornaments.options.scaleBar.visibility = .hidden

            // COMPASS
            mapView.ornaments.options.compass.position = .topTrailing
            mapView.ornaments.options.compass.margins = CGPoint(x: 8, y: 8)

            // ATTRIBUTION
            mapView.ornaments.options.attributionButton.position = .bottomLeading
            mapView.ornaments.options.attributionButton.margins = CGPoint(x: 85, y: 6)

            // LOGO (optional but usually bottom-right default)
            mapView.ornaments.options.logo.position = .bottomLeading
        }

        // MARK: - Update GeoJSON Source

        func updatePilots(
            _ pilots: [Pilot]
        ) {

            guard let mapView else {
                return
            }

            guard didInstallStyle else {
                return
            }

            styleManager.updatePilots(
                on: mapView,
                pilots: pilots
            )
        }

        // MARK: - Tap Interaction

        func installTapInteractions() {

            guard let mapView else {
                return
            }

            // PILOT ICON TAPS

            let pilotInteraction = TapInteraction(
                .layer(RadarStyleManager.pilotIconLayerId)
            ) { [weak self] feature, context in

                guard let self else {
                    return false
                }

                let properties = feature.properties
                // properties is a JSONObject: [String: JSONValue?]
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

            // CALLSIGN LABEL TAPS

            let labelInteraction = TapInteraction(
                .layer(RadarStyleManager.pilotLabelLayerId)
            ) { [weak self] feature, context in

                guard let self else {
                    return false
                }

                let properties = feature.properties
                // properties is a JSONObject: [String: JSONValue?]
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
        }
    }
}
