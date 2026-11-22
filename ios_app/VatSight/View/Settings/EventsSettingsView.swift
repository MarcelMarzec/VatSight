//
//  EventsSettingsView.swift
//  VatSight
//

import SwiftUI
import SwiftData

struct EventsSettingsView: View {
    @Environment(PreferencesManager.self) private var prefsManager
    @Environment(EventsManager.self) private var eventsManager
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                Toggle(isOn: binding(\.showEventAirportHighlights, prefsManager.updateShowEventAirportHighlights)) {
                    settingLabel("Event Airports", detail: "Highlight airports with a live or upcoming event")
                }
                if prefsManager.userPrefs.showEventAirportHighlights {
                    Picker("Upcoming Events Within", selection: binding(\.upcomingEventWindowHours, prefsManager.updateUpcomingEventWindowHours)) {
                        ForEach(EventHighlightWindows.eventOptions, id: \.self) { hours in
                            Text(hoursLabel(hours)).tag(hours)
                        }
                    }
                }
            } header: {
                Label("Events on the Map", systemImage: "star")
            }

            Section {
                Toggle(isOn: binding(\.showBookingAirportHighlights, prefsManager.updateShowBookingAirportHighlights)) {
                    settingLabel("Booked Airports", detail: "Highlight airports with booked ATC that isn't online yet")
                }
                Toggle(isOn: binding(\.showBookedSectors, prefsManager.updateShowBookedSectors)) {
                    settingLabel("Booked Sectors", detail: "Outline the airspace booked controllers will cover")
                }
                Picker("Upcoming Bookings Within", selection: binding(\.upcomingBookingWindowHours, prefsManager.updateUpcomingBookingWindowHours)) {
                    ForEach(EventHighlightWindows.bookingOptions, id: \.self) { hours in
                        Text(hoursLabel(hours)).tag(hours)
                    }
                }
            } header: {
                Label("ATC Bookings", systemImage: "headphones")
            } footer: {
                Text("The same window is used for the ATC Bookings list in each airport's details.")
            }

            Section {
                Picker("Show Times In", selection: Binding(
                    get: { prefsManager.userPrefs.eventTimeDisplay },
                    set: { value in
                        prefsManager.updateEventTimeDisplay(value)
                        eventsManager.recomputeOverlay()
                    }
                )) {
                    ForEach(EventTimeDisplay.allCases, id: \.self) { display in
                        Text(display.displayName).tag(display)
                    }
                }
                .pickerStyle(.segmented)
                .listRowSeparator(.hidden)

                let sample = Date()
                LabeledContent("Example", value: EventTimeFormatting.time(sample, display: prefsManager.userPrefs.eventTimeDisplay))
                    .foregroundStyle(.secondary)
            } header: {
                Label("Time Display", systemImage: "clock")
            } footer: {
                Text("Applies to events, the timeline and ATC bookings. The timeline's days follow UTC unless Local is selected.")
            }

            Section {
                MapLegendRow(title: AirportHighlight.activeEvent.displayName, detail: "Larger dot, purple ring and glow, ★ badge") {
                    AirportDotSample(ring: MapLegendColors.event, fill: .primary, glow: true, outerRing: true)
                }
                MapLegendRow(title: AirportHighlight.upcomingEvent.displayName, detail: "Purple ring with a calendar badge") {
                    AirportDotSample(ring: MapLegendColors.event, fill: .clear)
                }
                MapLegendRow(title: AirportHighlight.upcomingBooking.displayName, detail: "Cyan ring with a headphones badge") {
                    AirportDotSample(ring: MapLegendColors.booking, fill: .clear)
                }
                MapLegendRow(title: "Booked Sector", detail: "Dashed cyan outline with callsign and booked time. ≈ means estimated") {
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(MapLegendColors.booking, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .frame(width: 22, height: 16)
                }
                NavigationLink {
                    MapLegendView()
                } label: {
                    Label("Full Map Legend", systemImage: "map")
                }
            } header: {
                Label("Map Legend", systemImage: "info.circle")
            }

            Section {
                Button {
                    openURL(EventsService.calendarSubscriptionURL)
                } label: {
                    Label("Subscribe to VATSIM Events", systemImage: "calendar.badge.plus")
                }
            } footer: {
                Text("Adds the official VATSIM events feed to the Calendar app. It updates automatically.")
            }
        }
        .navigationTitle("Events & Bookings")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    private func binding<Value>(
        _ keyPath: ReferenceWritableKeyPath<UserPreferencesModel, Value>,
        _ update: @escaping (Value) -> Void
    ) -> Binding<Value> {
        Binding(
            get: { prefsManager.userPrefs[keyPath: keyPath] },
            set: { value in
                update(value)
                eventsManager.recomputeOverlay()
            }
        )
    }

    private func settingLabel(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func hoursLabel(_ hours: Int) -> String {
        hours == 1 ? "1 hour" : "\(hours) hours"
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserPreferencesModel.self, configurations: config)
    let prefs = PreferencesManager(context: ModelContext(container))

    return NavigationStack {
        EventsSettingsView()
            .environment(prefs)
            .environment(EventsManager(prefs: prefs))
    }
}
