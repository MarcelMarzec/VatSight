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
    @State private var loadingRotation: Double = 0
    @State private var showingLayerMenu = false
    @State private var showingSearch = false
    @State private var showingDebug = false
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
            }
            .onDisappear {
                viewModel.stopAutoRefresh()
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
            if viewModel.isLoadingData {
                VStack {
                    Image("loadingArrow")
                        .resizable()
                        .frame(width: 32, height: 32)
                        .rotationEffect(.degrees(loadingRotation))
                        .padding()
                        .glassEffect()
                        .clipShape(.circle)
                        .onAppear {
                            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                                loadingRotation = 360
                            }
                        }
                    
                    Text("Loading radar data...")
                        .font(.caption)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .glassEffect()
                        .clipShape(.capsule)
                }
                .transition(.scale.combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: viewModel.isLoadingData)
            }
            
        
        }
        .overlay(alignment: .topTrailing) {
            VStack(spacing: 12) {
                // Search + layer menu — joined as one pill
                GlassEffectContainer {
                    VStack(spacing: 0) {
                        Button {
                            showingSearch = true
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
                        } label: {
                            Image(systemName: "paperplane")
                                .imageScale(.medium)
                                .padding(12)
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

                // Altitude filter toggle button
                GlassEffectContainer {
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            viewModel.toggleAltitudeFilter()
                        }
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
                                .font(.system(size: 9, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)

                            // Selected altitude
                            Text(altitudeLabel(for: viewModel.selectedAltitudeFt))
                                .font(.caption2.bold())
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)

                            // Rotated slider filling available height
                            Slider(
                                value: Binding(
                                    get: { viewModel.selectedAltitudeFt },
                                    set: { viewModel.selectedAltitudeFt = $0 }
                                ),
                                in: 0...60_000,
                                step: 100
                            )
                            .frame(width: trackHeight)
                            .rotationEffect(.degrees(-90))
                            .frame(width: 44, height: trackHeight)

                            // GND at bottom
                            Text("GND")
                                .font(.system(size: 9))
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
            GlassEffectContainer {
                Button {
                    showingDebug = true
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
    
    /// Formats an altitude in feet as a display string.
    /// 0 → "GND", 1–9999 → "7000 ft", 10000+ → "FL100"
    private func altitudeLabel(for feet: Double) -> String {
        let rounded = Int(feet)
        if rounded == 0 { return "GND" }
        if rounded < 10000 { return "\(rounded) ft" }
        return "FL\(rounded / 100)"
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
