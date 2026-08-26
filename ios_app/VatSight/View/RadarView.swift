//
//  RadarView.swift
//  VatSight
//
//  Created by Marcel Marzec on 12/05/2026.
//

import SwiftUI
import SwiftData
import MapboxMaps

struct RadarView: View {

    @Environment(PreferencesManager.self) private var prefsManager
    @EnvironmentObject private var viewModel: RadarViewModel
    @Namespace private var glassNamespace
    @State private var showingLayerMenu = false
    @State private var showingSearch = false
    @State private var showingDebug = false
    /// Timer used to periodically re-evaluate the stale-data banner.
    @State private var stalenessCheckTimer: Timer? = nil
    @State private var staleTick = false // toggled to force SwiftUI re-evaluation
    @State private var pilotDetent: PresentationDetent = .fraction(0.3)
    @State private var airportDetent: PresentationDetent = .fraction(0.3)
    @State private var sectorDetent: PresentationDetent = .height(160)
    // Header height measured from a hidden off-screen render — never inside the sheet itself.
    @State private var sectorHeaderHeight: CGFloat = 160
    
    var body: some View {
        let backgroundColor = Color.Resolved(red: 0.2, green: 0.2, blue: 0.2)
        
        ZStack {
            RadarViewRepresentable(viewModel: viewModel,
                                   prefsManager: prefsManager)
            .ignoresSafeArea()
            .sheet(isPresented: $viewModel.isShowingPilotSheet,
                onDismiss: {
                    viewModel.onPilotSheetDismissed()
                    pilotDetent = .fraction(0.3)
                }
            ) {
                // Bind directly to the live selectedPilot — content updates in-place when
                // a new pilot is tapped without dismissing and re-presenting the sheet.
                if let pilot = viewModel.selectedPilot {
                    PilotDetailsView(
                        pilot: pilot,
                        airportName: { viewModel.airportName(for: $0) },
                        onAirportSelected: { icao in viewModel.selectAirportAndFly(icao: icao) }
                    )
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 20,
                            bottomLeadingRadius: 50,
                            bottomTrailingRadius: 50,
                            topTrailingRadius: 20,
                            style: .continuous
                        )
                    )
                    .presentationDragIndicator(.visible)
                    .presentationDetents([.fraction(0.325), .medium, .large], selection: $pilotDetent)
                    .presentationBackgroundInteraction(.enabled)
                }
            }
            .sheet(isPresented: $viewModel.isShowingAirportSheet,
                onDismiss: {
                    viewModel.dismissAirportSheet()
                    airportDetent = .fraction(0.3)
                }
            ) {
                if let airport = viewModel.selectedAirport {
                    AirportDetailsView(
                        airport: airport,
                        controllers: viewModel.controllersAtSelectedAirport,
                        atis: viewModel.atis,
                        traffic: viewModel.selectedAirportTraffic,
                        labelResolver: { viewModel.resolvePositionLabel(for: $0) },
                        onPilotSelected: { cid, lat, lon in
                            viewModel.selectPilotAndFly(
                                cid: cid,
                                coordinate: .init(latitude: lat, longitude: lon),
                                enableTracking: true
                            )
                        }
                    )
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 20,
                            bottomLeadingRadius: 50,
                            bottomTrailingRadius: 50,
                            topTrailingRadius: 20,
                            style: .continuous
                        )
                    )
                    .presentationDragIndicator(.visible)
                    .presentationDetents([.fraction(0.3), .medium, .large], selection: $airportDetent)
                    .presentationBackgroundInteraction(.enabled)
                }
            }
            .sheet(isPresented: $viewModel.isShowingSectorSheet,
                onDismiss: {
                    viewModel.dismissSectorSheet()
                    sectorHeaderHeight = 160
                    sectorDetent = .height(sectorHeaderHeight)
                }
            ) {
                if let sector = viewModel.selectedSector, let controller = sector.activeController {
                    SectorDetailsView(sector: sector, controller: controller, headerHeight: $sectorHeaderHeight)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 20,
                                bottomLeadingRadius: 50,
                                bottomTrailingRadius: 50,
                                topTrailingRadius: 20,
                                style: .continuous
                            )
                        )
                        .presentationDragIndicator(.visible)
                        .presentationDetents([.height(sectorHeaderHeight), .fraction(0.8), .large], selection: $sectorDetent)
                        .presentationBackgroundInteraction(.enabled)
                        .onChange(of: sectorHeaderHeight) { _, newHeight in
                            sectorDetent = .height(newHeight)
                        }
                }
            }
            .onAppear {
                viewModel.setPreferencesManager(prefsManager)
                viewModel.startAutoRefresh()
                // Re-evaluate the stale banner every 15 s while the map is visible.
                stalenessCheckTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { _ in
                    staleTick.toggle()
                }
            }
            .onDisappear {
                viewModel.stopAutoRefresh()
                stalenessCheckTimer?.invalidate()
                stalenessCheckTimer = nil
            }
            .onChange(of: prefsManager.userPrefs.vatsimRefreshRate) { _, _ in
                viewModel.restartAutoRefresh()
            }
            .onChange(of: prefsManager.pendingNavigateToCID) { _, cid in
                guard let cid else { return }
                defer { prefsManager.pendingNavigateToCID = nil }

                if let pilot = viewModel.pilots.first(where: { $0.cid == cid }) {
                    viewModel.selectPilotAndFly(cid: cid, coordinate: pilot.coordinate)
                } else if let controller = viewModel.controllers.first(where: { $0.cid == cid }),
                          let airport = viewModel.airports.first(where: { $0.activeController?.cid == cid }) {
                    viewModel.selectAirportAndFly(icao: airport.icao)
                } else if let controller = viewModel.controllers.first(where: { $0.cid == cid }),
                          let sector = viewModel.sectors.first(where: { $0.activeController?.cid == cid }) {
                    viewModel.selectSector(id: sector.id)
                }
            }
        }
        .overlay(alignment: .top) {
            StaleBanner()
        }
        .overlay(alignment: .topTrailing) {
            let myCID = prefsManager.userPrefs.vatsimCID
            let isOnline = myCID > 0 && (
                viewModel.pilots.contains(where: { $0.cid == myCID }) ||
                viewModel.airports.contains(where: { $0.activeController?.cid == myCID }) ||
                viewModel.sectors.contains(where: { $0.activeController?.cid == myCID })
            )
            let isSelected = myCID > 0 && viewModel.selectedPilot?.cid == myCID
            HStack(alignment: .top) {
                if isOnline {
                    GlassEffectContainer {
                        Button {
                            locateMe()
                        } label: {
                            Image(systemName: isSelected ? "location.fill" : "location")
                                .imageScale(.medium)
                                .padding(12)
                                .contentShape(.circle)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
                        .glassEffectUnion(id: "pill", namespace: glassNamespace)
                    }
                }
                
                VStack(spacing: 12) {
                    // Search + locate-me + layer menu — joined as one pill
                    GlassEffectContainer {
                        VStack(spacing: 0) {
                            Button {
                                showingSearch = true
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Image(systemName: "magnifyingglass")
                                    .imageScale(.medium)
                                    .padding(12)
                                    .contentShape(.circle)
                            }
                            .buttonStyle(.plain)
                            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
                            .glassEffectUnion(id: "pill", namespace: glassNamespace)

                            Button {
                                showingLayerMenu.toggle()
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Image(systemName: "ellipsis")
                                    .rotationEffect(.degrees(90))
                                    .imageScale(.medium)
                                    .padding(12)
                                    .padding(.bottom, 8)
                                    .contentShape(.circle)
                            }
                            .buttonStyle(.plain)
                            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
                            .glassEffectUnion(id: "pill", namespace: glassNamespace)
                            .popover(isPresented: $showingLayerMenu, arrowEdge: .trailing) {
                                VStack(alignment: .leading, spacing: 0) {
                                    Toggle(isOn: Binding(
                                        get: { viewModel.showInactiveSectors },
                                        set: { _ in viewModel.toggleSectors() }
                                    )) {
                                        Label("Inactive sectors", systemImage: "map")
                                    }
                                    .padding()
                                    Divider()
                                    Toggle(isOn: Binding(
                                        get: { viewModel.showAirports },
                                        set: { _ in viewModel.toggleAirports() }
                                    )) {
                                        Label("All airports", systemImage: "airplane.ticket")
                                    }
                                    .padding()
                                }
                                .presentationCompactAdaptation(.popover)
                            }
                        }
                    }
                    
                    GlassEffectContainer {
                        Button {
                            withAnimation(.spring(duration: 0.3)) {
                                viewModel.toggleAltitudeFilter()
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Image(systemName: viewModel.altitudeFilterEnabled
                                  ? "square.2.layers.3d.fill"
                                  : "square.2.layers.3d")
                                .imageScale(.medium)
                                .foregroundStyle(viewModel.altitudeFilterEnabled ? Color.accentColor : .primary)
                                .padding(12)
                                .contentShape(.circle)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .circle)
                    }

                }
            }
            .padding()
        }
        .overlay(alignment: .trailing) {
            if viewModel.altitudeFilterEnabled {
                GeometryReader { geo in
                    // Reserve space for the buttons above (~160 pt) and bottom safe area.
                    // When a sheet is open, push the slider up so it isn't covered.
                    let topOffset: CGFloat = 180
                    let sheetHeight: CGFloat = {
                        if viewModel.isShowingSectorSheet {
                            return sectorHeaderHeight + 2
                        }
                        if viewModel.isShowingPilotSheet {
                            return geo.size.height * 0.325 + 2
                        }
                        if viewModel.isShowingAirportSheet {
                            return geo.size.height * 0.3 + 2
                        }
                        return 16
                    }()
                    let bottomPad: CGFloat = sheetHeight
                    let availableHeight = geo.size.height - topOffset - bottomPad
                    let trackHeight = max(availableHeight - 56, 60) // subtract label heights

                    VStack(spacing: 0) {
                        Spacer().frame(height: topOffset)

                        VStack(spacing: 6) {
                            // FL600 label at top
                            Text("FL600")
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)

                            // Selected altitude
                            Text(altitudeLabel(for: viewModel.selectedAltitudeFt))
                                .font(.caption2.bold())
                                .monospacedDigit()
                                .lineLimit(1)

                            // Rotated slider filling available height
                            Slider(
                                value: Binding(
                                    get: { viewModel.selectedAltitudeFt },
                                    set: { newValue in
                                        let previous = viewModel.selectedAltitudeFt
                                        viewModel.selectedAltitudeFt = newValue
                                        if newValue == 0 || newValue == 60_000 {
                                            if previous != newValue {
                                                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                                            }
                                        } else if Int(newValue) != Int(previous) {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.4)
                                        }
                                    }
                                ),
                                in: 0...60_000,
                                step: 100
                            )
                            .frame(width: trackHeight)
                            .rotationEffect(.degrees(-90))
                            .frame(width: 44, height: trackHeight)

                            // GND at bottom
                            Text("GND")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 10)
                        .frame(width: 60, height: availableHeight)

                        Spacer().frame(height: bottomPad)
                    }
                    .frame(width: 60, height: geo.size.height)
                }
                .frame(width: 60)
                .padding(.trailing, 8)
                .transition(.scale(scale: 0.85, anchor: .top).combined(with: .opacity))
            }
        }
        .overlay(alignment: .topLeading) {
            if prefsManager.userPrefs.developerModeEnabled {
                GlassEffectContainer {
                    Button {
                        showingDebug = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "ant")
                            .imageScale(.medium)
                            .padding(12)
                            .contentShape(.circle)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingDebug) {
            DebugView(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled)
        }
        .sheet(isPresented: $showingSearch) {
            SearchView(
                airports: viewModel.airports,
                pilots: viewModel.pilots,
                controllers: viewModel.controllers,
                onAirportSelected: { icao in
                    viewModel.selectAirportAndFly(icao: icao)
                },
                onPilotSelected: { cid in
                    guard let pilot = viewModel.pilots.first(where: { $0.cid == cid }) else { return }
                    viewModel.selectPilotAndFly(
                        cid: cid,
                        coordinate: pilot.coordinate,
                        enableTracking: true
                    )
                },
                onControllerSelected: { controller in
                    if let airport = viewModel.airports.first(where: { $0.activeController?.cid == controller.cid }) {
                        viewModel.selectAirportAndFly(icao: airport.icao)
                    } else if let sector = viewModel.sectors.first(where: { $0.activeController?.cid == controller.cid }) {
                        viewModel.selectSector(id: sector.id)
                    }
                }
            )
        }
    }
    
    /// Flies the camera to the user's own aircraft or, if controlling, their airport/sector.
    private func locateMe() {
        let myCID = prefsManager.userPrefs.vatsimCID
        guard myCID > 0 else { return }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        if let pilot = viewModel.pilots.first(where: { $0.cid == myCID }) {
            viewModel.selectPilotAndFly(cid: myCID, coordinate: pilot.coordinate, enableTracking: true)
        } else if let airport = viewModel.airports.first(where: { $0.activeController?.cid == myCID }) {
            viewModel.selectAirportAndFly(icao: airport.icao)
        } else if let sector = viewModel.sectors.first(where: { $0.activeController?.cid == myCID }) {
            viewModel.selectSector(id: sector.id)
        } else {
            // CID exists but not currently online — brief error haptic
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }
    
    private func altitudeLabel(for feet: Double) -> String {
        let rounded = Int(feet)
        if rounded == 0 { return "GND" }
        if rounded < 10000 { return "\(rounded) ft" }
        return "FL\(rounded / 100)"
    }
}

private struct StaleBanner: View {
    @EnvironmentObject private var viewModel: RadarViewModel

    var body: some View {
        if !viewModel.isLoadingData && viewModel.isDataStale {
            HStack(spacing: 6) {
                Image(systemName: viewModel.lastFetchFailed ? "wifi.slash" : "clock")
                    .imageScale(.small)
                Text(viewModel.lastFetchFailed ? "No connection — retrying..." : "Data may be out of date")
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.85))
            .clipShape(Capsule())
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.35), value: viewModel.isDataStale)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserPreferencesModel.self, configurations: config)
    let context = ModelContext(container)

    return RadarView()
        .environment(PreferencesManager(context: context))
        .environmentObject(RadarViewModel())
}
