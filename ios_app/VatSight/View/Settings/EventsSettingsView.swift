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
            Section("Events") {
                Toggle("Highlight Event Airports", isOn: binding(\.showEventAirportHighlights, prefsManager.updateShowEventAirportHighlights))
                if prefsManager.userPrefs.showEventAirportHighlights {
                    Picker("Upcoming Within", selection: binding(\.upcomingEventWindowHours, prefsManager.updateUpcomingEventWindowHours)) {
                        ForEach(EventHighlightWindows.eventOptions, id: \.self) { hours in
                            Text(hoursLabel(hours)).tag(hours)
                        }
                    }
                }
            }

            Section("ATC Bookings") {
                Toggle("Highlight Booked Airports", isOn: binding(\.showBookingAirportHighlights, prefsManager.updateShowBookingAirportHighlights))
                Toggle("Show Booked Sectors", isOn: binding(\.showBookedSectors, prefsManager.updateShowBookedSectors))
                Picker("Upcoming Within", selection: binding(\.upcomingBookingWindowHours, prefsManager.updateUpcomingBookingWindowHours)) {
                    ForEach(EventHighlightWindows.bookingOptions, id: \.self) { hours in
                        Text(hoursLabel(hours)).tag(hours)
                    }
                }
            }

            Section("Times") {
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

                LabeledContent("Example", value: EventTimeFormatting.time(Date(), display: prefsManager.userPrefs.eventTimeDisplay))
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    openURL(EventsService.calendarSubscriptionURL)
                } label: {
                    Label("Subscribe in Calendar", systemImage: "calendar.badge.plus")
                }
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
