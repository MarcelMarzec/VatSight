//
//  EventDetailView.swift
//  VatSight
//

import SwiftUI
import UIKit

struct EventDetailView: View {
    @Environment(EventsManager.self) private var eventsManager
    @Environment(PreferencesManager.self) private var prefsManager

    @State private var event: VatsimEvent
    @State private var showingCalendarEditor = false
    @State private var showingWebPage = false
    @State private var showsAllBookings = false

    let context: EventMapContext

    /// Bookings beyond this are behind "Show all".
    private static let collapsedBookingCount = 8

    init(event: VatsimEvent, context: EventMapContext = EventMapContext()) {
        _event = State(initialValue: event)
        self.context = context
    }

    private var timeDisplay: EventTimeDisplay { prefsManager.userPrefs.eventTimeDisplay }

    /// The short description is shown separately only when the full description doesn't already contain it.
    private var showsShortDescription: Bool {
        guard !event.shortDescription.isEmpty else { return false }
        guard !event.description.isEmpty else { return true }
        let short = MarkdownParser.comparisonKey(event.shortDescription)
        return !MarkdownParser.comparisonKey(event.description).contains(short)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                BannerAdCard(placement: .eventDetail)
                header
                MetricStrip.eventTimes(start: event.startTime, end: event.endTime, display: timeDisplay)
                statusLine
                airportsSection
                routesSection
                bookingsSection

                if showsShortDescription {
                    textSection(title: "Summary", markdown: event.shortDescription)
                }
                if !event.description.isEmpty {
                    textSection(title: "Details", markdown: event.description)
                }

                organisersSection
                actions
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let link = event.link {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: link, subject: Text(event.name)) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share event")
                }
            }
        }
        .opensWebLinksInApp()
        .sheet(isPresented: $showingCalendarEditor) {
            AddToCalendarView(event: event)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showingWebPage) {
            if let link = event.link {
                SafariView(url: link)
                    .ignoresSafeArea()
            }
        }
        .task(id: event.id) {
            // `GET /view/:id` keeps the detail current if the organiser edited it.
            if let updated = await eventsManager.refreshEvent(id: event.id), updated != event {
                event = updated
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let banner = event.banner {
                Color.clear
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .overlay { RemoteImage(url: banner, maxPixelSize: 1600) }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityHidden(true)
            }
            HStack(spacing: 6) {
                EventTypeBadge(type: event.type)
                if event.isOrganisedByVatsim {
                    VatsimOrganisedBadge()
                }
                Spacer(minLength: 8)
                EventStatusPill(start: event.startTime, end: event.endTime)
            }
            Text(event.name)
                .font(.largeTitle.bold())
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let organiser = event.organisers.first {
                let summary = eventsManager.orgs.summary(for: organiser)
                if !summary.isEmpty {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var statusLine: some View {
        TimelineView(.everyMinute) { timeline in
            let range = EventTimeFormatting.range(start: event.startTime, end: event.endTime, display: timeDisplay)
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
                Text(EventTimeFormatting.relativeStatus(start: event.startTime, end: event.endTime, now: timeline.date))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(range.secondary ?? range.primary)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Airports

    @ViewBuilder
    private var airportsSection: some View {
        let icaos = event.allICAOs
        if !icaos.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                EventSectionTitle(title: icaos.count == 1 ? "Airport" : "Airports")
                FlowLayout(spacing: 8) {
                    ForEach(icaos, id: \.self) { icao in
                        airportTile(icao)
                    }
                }
                if context.onShowAirport != nil {
                    Text("Tap an airport to see it on the map with its ATC and traffic.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func airportTile(_ icao: String) -> some View {
        let showable = context.onShowAirport != nil && context.canShowAirport(icao)
        return Button {
            HapticManager.impact(prefsEnabled: prefsManager.userPrefs.hapticFeedbackEnabled)
            context.onShowAirport?(icao)
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(icao)
                        .font(.headline.monospaced())
                    if let name = context.airportName(icao) {
                        Text(name)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: 130, alignment: .leading)
                    }
                }
                if showable {
                    Image(systemName: "map")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .vatSightCard(cornerRadius: 10)
        }
        .buttonStyle(.plain)
        .disabled(!showable)
        .accessibilityLabel([icao, context.airportName(icao)].compactMap { $0 }.joined(separator: ", "))
        .accessibilityHint(showable ? "Shows the airport on the map" : "")
    }

    // MARK: - Routes

    @ViewBuilder
    private var routesSection: some View {
        if !event.routes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                EventSectionTitle(title: event.routes.count == 1 ? "Route" : "Routes")
                ForEach(event.routes.indices, id: \.self) { index in
                    let route = event.routes[index]
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(route.departure.isEmpty ? "—" : route.departure)
                            Image(systemName: "airplane")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                            Text(route.arrival.isEmpty ? "—" : route.arrival)
                        }
                        .font(.headline.monospaced())
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(route.departure) to \(route.arrival)")
                        if !route.route.isEmpty {
                            Text(route.route)
                                .font(.footnote.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .vatSightCard(cornerRadius: 10)
                    .contextMenu {
                        if !route.route.isEmpty {
                            Button {
                                UIPasteboard.general.string = route.route
                            } label: {
                                Label("Copy Route", systemImage: "doc.on.doc")
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Bookings

    @ViewBuilder
    private var bookingsSection: some View {
        let bookings = context.bookings(event, eventsManager.bookings)
        if !event.allICAOs.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                EventSectionTitle(title: "ATC Bookings", trailing: bookings.isEmpty ? nil : "\(bookings.count)")
                if bookings.isEmpty {
                    Text("No ATC has been booked for this event yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .vatSightCard(cornerRadius: 10)
                } else {
                    let visible = showsAllBookings ? bookings : Array(bookings.prefix(Self.collapsedBookingCount))
                    VStack(spacing: 0) {
                        ForEach(Array(visible.enumerated()), id: \.element.id) { index, booking in
                            if index > 0 {
                                Divider()
                            }
                            AtcBookingRow(booking: booking, labelResolver: context.positionLabel)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }
                        if bookings.count > Self.collapsedBookingCount {
                            Divider()
                            Button {
                                withAnimation(.snappy) { showsAllBookings.toggle() }
                            } label: {
                                Text(showsAllBookings ? "Show Fewer" : "Show All \(bookings.count)")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .vatSightCard(cornerRadius: 10)
                    Text("Bookings at the event's airports, and approach or centre positions covering them, during the event.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Text & Organisers

    private func textSection(title: String, markdown: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            EventSectionTitle(title: title)
            MarkdownText(markdown)
                .padding(14)
                .vatSightCard(cornerRadius: 12)
        }
    }

    @ViewBuilder
    private var organisersSection: some View {
        if !event.organisers.isEmpty {
            let orgs = eventsManager.orgs
            VStack(alignment: .leading, spacing: 8) {
                EventSectionTitle(title: event.organisers.count == 1 ? "Organiser" : "Organisers")
                ForEach(event.organisers.indices, id: \.self) { index in
                    let organiser = event.organisers[index]
                    VStack(alignment: .leading, spacing: 8) {
                        organiserRow("Region", id: organiser.region, name: orgs.regionName(organiser.region))
                        organiserRow("Division", id: organiser.division, name: orgs.divisionName(organiser.division))
                        organiserRow("Subdivision", id: organiser.subdivision, name: orgs.subdivisionName(organiser.subdivision))
                        if organiser.organisedByVatsim {
                            Label("Organised by VATSIM", systemImage: "checkmark.seal.fill")
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .vatSightCard(cornerRadius: 10)
                }
            }
        }
    }

    @ViewBuilder
    private func organiserRow(_ title: String, id: String?, name: String?) -> some View {
        if let id, !id.isEmpty {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 84, alignment: .leading)
                Text(name ?? id)
                    .font(.subheadline)
                Spacer(minLength: 4)
                if name != nil {
                    Text(id)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 10) {
            if event.link != nil {
                Button {
                    showingWebPage = true
                } label: {
                    Label("View on myVATSIM", systemImage: "safari")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
            }
            HStack(spacing: 10) {
                Button {
                    showingCalendarEditor = true
                } label: {
                    Label("Add to Calendar", systemImage: "calendar.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                if let link = event.link {
                    ShareLink(item: link, subject: Text(event.name)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                }
            }
        }
        .padding(.top, 4)
    }
}
