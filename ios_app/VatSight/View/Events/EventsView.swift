//
//  EventsView.swift
//  VatSight
//
//  The Events tab: current and upcoming VATSIM events as a list of cards or a one-day
//  timeline. The view mode and every filter are saved in preferences. Time display and the
//  calendar subscription live in Settings → Events & Bookings.
//

import SwiftUI

struct EventsView: View {
    @Environment(EventsManager.self) private var eventsManager
    @Environment(PreferencesManager.self) private var prefsManager

    var context = EventMapContext()

    @State private var path: [VatsimEvent] = []
    @State private var searchText = ""
    @Namespace private var modeNamespace

    private var viewMode: EventsViewMode { prefsManager.userPrefs.eventsViewMode }
    private var timeDisplay: EventTimeDisplay { prefsManager.userPrefs.eventTimeDisplay }

    private var filter: EventFilter { prefsManager.eventFilter }

    private func updateFilter(_ change: (inout EventFilter) -> Void) {
        var next = filter
        change(&next)
        // A division only makes sense inside its region.
        if let division = next.division, let region = next.region,
           let parent = eventsManager.orgs.divisions.first(where: { $0.id == division })?.parentRegion,
           parent != region {
            next.division = nil
        }
        guard next != filter else { return }
        HapticManager.impact(prefsEnabled: prefsManager.userPrefs.hapticFeedbackEnabled)
        prefsManager.updateEventFilter(next)
    }

    private var filteredEvents: [VatsimEvent] {
        let filter = self.filter
        let orgs = eventsManager.orgs
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return eventsManager.events.filter { event in
            guard filter.matches(event) else { return false }
            guard !query.isEmpty else { return true }
            return event.matches(search: query)
                || event.organisers.contains { orgs.summary(for: $0).localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                header
                content
            }
            .background(Color(.systemBackground))
            .navigationTitle("Events")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Events, airports, divisions")
            .navigationDestination(for: VatsimEvent.self) { event in
                EventDetailView(event: event, context: context)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            modeToggle
            filterChips
        }
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    /// List / Timeline switch in the style of the map's glass controls.
    private var modeToggle: some View {
        GlassEffectContainer {
            HStack(spacing: 0) {
                ForEach(EventsViewMode.allCases, id: \.self) { mode in
                    let isSelected = mode == viewMode
                    Button {
                        guard !isSelected else { return }
                        HapticManager.impact(prefsEnabled: prefsManager.userPrefs.hapticFeedbackEnabled)
                        withAnimation(.snappy) {
                            prefsManager.updateEventsViewMode(mode)
                        }
                    } label: {
                        Label(mode.displayName, systemImage: mode.systemImage)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background {
                                if isSelected {
                                    Capsule()
                                        .fill(Color.primary.opacity(0.16))
                                        .matchedGeometryEffect(id: "mode", in: modeNamespace)
                                }
                            }
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(4)
            .glassEffect(.regular, in: .capsule)
        }
        .padding(.horizontal)
    }

    private var filterChips: some View {
        let filter = self.filter
        let counts = eventsManager.eventCountsByOrganiser
        let regions = eventsManager.filterRegions
        let divisions = eventsManager.filterDivisions(inRegion: filter.region)
        let orgs = eventsManager.orgs

        return ScrollView(.horizontal) {
            HStack(spacing: 8) {
                if filter.isActive {
                    Button {
                        updateFilter { $0 = EventFilter() }
                    } label: {
                        VatSightChip(isSelected: false) {
                            Image(systemName: "xmark")
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear filters")
                }

                ForEach(VatsimEventType.knownTypes, id: \.self) { type in
                    let isOn = filter.types.contains(type)
                    Button {
                        updateFilter { filter in
                            if isOn { filter.types.remove(type) } else { filter.types.insert(type) }
                        }
                    } label: {
                        VatSightChip(isSelected: isOn) {
                            Label(type.displayName, systemImage: type.systemImage)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }

                Menu {
                    Picker("Region", selection: Binding(
                        get: { filter.region },
                        set: { value in updateFilter { $0.region = value } }
                    )) {
                        Text("All Regions").tag(String?.none)
                        ForEach(regions) { region in
                            Text(optionTitle(region.name, id: region.id, count: counts.regions[region.id]))
                                .tag(String?.some(region.id))
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    VatSightChip(isSelected: filter.region != nil) {
                        HStack(spacing: 4) {
                            Image(systemName: "globe")
                            Text(filter.region.map { orgs.regionName($0) ?? $0 } ?? "Region")
                            Image(systemName: "chevron.down")
                                .font(.caption2.weight(.bold))
                        }
                    }
                }

                Menu {
                    Picker("Division", selection: Binding(
                        get: { filter.division },
                        set: { value in updateFilter { $0.division = value } }
                    )) {
                        Text("All Divisions").tag(String?.none)
                        ForEach(divisions) { division in
                            Text(optionTitle(division.name, id: division.id, count: counts.divisions[division.id]))
                                .tag(String?.some(division.id))
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    VatSightChip(isSelected: filter.division != nil) {
                        HStack(spacing: 4) {
                            Image(systemName: "map")
                            Text(filter.division.map { orgs.divisionName($0) ?? $0 } ?? "Division")
                            Image(systemName: "chevron.down")
                                .font(.caption2.weight(.bold))
                        }
                    }
                }

                Button {
                    updateFilter { $0.vatsimOrganisedOnly.toggle() }
                } label: {
                    VatSightChip(isSelected: filter.vatsimOrganisedOnly) {
                        Label("VATSIM", systemImage: "checkmark.seal")
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Organised by VATSIM")
                .accessibilityAddTraits(filter.vatsimOrganisedOnly ? .isSelected : [])
            }
            .padding(.horizontal)
        }
        .scrollIndicators(.hidden)
    }

    /// "Europe (except UK) · EUD — 12"
    private func optionTitle(_ name: String, id: String, count: Int?) -> String {
        let base = name == id ? id : "\(name) (\(id))"
        guard let count, count > 0 else { return base }
        return "\(base) — \(count)"
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        let events = filteredEvents
        if eventsManager.events.isEmpty {
            if eventsManager.isLoadingEvents || (eventsManager.lastEventsFetch == nil && eventsManager.eventsError == nil) {
                ProgressView("Loading events…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView {
                    Label("No Events", systemImage: "calendar.badge.exclamationmark")
                } description: {
                    Text(eventsManager.eventsError ?? "There are no current or upcoming VATSIM events.")
                } actions: {
                    Button("Try Again") {
                        Task { await eventsManager.refreshAll() }
                    }
                    .buttonStyle(.glass)
                }
                .frame(maxHeight: .infinity)
            }
        } else if events.isEmpty {
            ContentUnavailableView {
                Label("No Matching Events", systemImage: "line.3.horizontal.decrease.circle")
            } description: {
                Text(searchText.isEmpty ? "No events match the selected filters." : "No events match “\(searchText)”.")
            } actions: {
                if filter.isActive {
                    Button("Clear Filters") { updateFilter { $0 = EventFilter() } }
                        .buttonStyle(.glass)
                }
            }
            .frame(maxHeight: .infinity)
        } else {
            switch viewMode {
            case .list:
                EventListView(events: events, timeDisplay: timeDisplay, orgs: eventsManager.orgs, onSelect: open)
                    .refreshable { await eventsManager.refreshAll() }
            case .timeline:
                EventTimelineView(events: events, timeDisplay: timeDisplay, onSelect: open)
            }
        }
    }

    private func open(_ event: VatsimEvent) {
        HapticManager.impact(prefsEnabled: prefsManager.userPrefs.hapticFeedbackEnabled)
        path.append(event)
    }
}
