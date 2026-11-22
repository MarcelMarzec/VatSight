//
//  EventsManager.swift
//  VatSight
//
//  Owns the VATSIM Events and ATC Bookings feeds: fetching, disk caching, refresh cadence,
//  and the derived overlay inputs used by the map and airport sheet.
//
//  Kept separate from RadarViewModel on purpose: RadarViewModel is an ObservableObject whose
//  every change re-runs the map's updateUIView, so this data only reaches the map through
//  `overlay`, which changes at most once a minute and only when its contents differ.
//

import Foundation
import Observation

@Observable
final class EventsManager {

    // MARK: Published state

    /// Current and upcoming events, sorted by start time. Ended events are pruned.
    private(set) var events: [VatsimEvent] = []
    /// Bookings that haven't ended yet, sorted by start time.
    private(set) var bookings: [AtcBooking] = []
    private(set) var isLoadingEvents = false
    private(set) var eventsError: String?
    private(set) var lastEventsFetch: Date?
    private(set) var lastBookingsFetch: Date?
    /// Inputs for the map overlays; only reassigned when the value changes.
    private(set) var overlay = EventOverlayInputs.empty
    /// Region, division and subdivision names from the Core API.
    private(set) var orgs = VatsimOrgDirectory.empty

    // MARK: Private

    @ObservationIgnored private let prefs: PreferencesManager
    @ObservationIgnored private let eventsService = EventsService()
    @ObservationIgnored private let bookingsService = BookingsService()
    @ObservationIgnored private let orgService = OrgDirectoryService()
    @ObservationIgnored private var isFetchingOrgs = false
    /// Observed so views reading `events(atAirport:)` refresh when the feed changes.
    private var eventsByICAO: [String: [VatsimEvent]] = [:]
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var hasStarted = false
    @ObservationIgnored private var isFetchingBookings = false

    /// Server sends `Cache-Control: max-age=600` for events.
    private static let eventsRefreshInterval: TimeInterval = 10 * 60
    /// Bookings change rarely; 5 minutes keeps the map fresh without hammering the API.
    private static let bookingsRefreshInterval: TimeInterval = 5 * 60
    /// The overlay is re-evaluated on this tick so statuses roll over as time passes.
    private static let tickInterval: Duration = .seconds(60)
    /// Regions and divisions almost never change.
    private static let orgsRefreshInterval: TimeInterval = 7 * 24 * 3600

    private static let cacheDirectory: URL =
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    private static let eventsCacheURL = cacheDirectory.appending(path: "vatsim_events_cache.json")
    private static let bookingsCacheURL = cacheDirectory.appending(path: "vatsim_bookings_cache.json")
    private static let orgsCacheURL = cacheDirectory.appending(path: "vatsim_orgs_cache.json")

    init(prefs: PreferencesManager) {
        self.prefs = prefs
    }

    // MARK: - Lifecycle

    /// Loads the disk cache, then starts the refresh loop. Safe to call more than once.
    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        Task { [weak self] in
            await self?.loadDiskCache()
            self?.startRefreshLoop()
        }
    }

    func handleForeground() {
        guard hasStarted else { return }
        startRefreshLoop()
    }

    func handleBackground() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    private func startRefreshLoop() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refreshIfStale()
                self.recomputeOverlay()
                try? await Task.sleep(for: Self.tickInterval)
            }
        }
    }

    // MARK: - Fetching

    private func refreshIfStale() async {
        let now = Date()
        let eventsStale = lastEventsFetch.map { now.timeIntervalSince($0) >= Self.eventsRefreshInterval } ?? true
        let bookingsStale = lastBookingsFetch.map { now.timeIntervalSince($0) >= Self.bookingsRefreshInterval } ?? true
        let orgsStale = orgs.fetched.map { now.timeIntervalSince($0) >= Self.orgsRefreshInterval } ?? true
        await withTaskGroup(of: Void.self) { group in
            if eventsStale { group.addTask { await self.refreshEvents() } }
            if bookingsStale { group.addTask { await self.refreshBookings() } }
            if orgsStale { group.addTask { await self.refreshOrgs() } }
        }
    }

    /// Pull-to-refresh: fetches both feeds regardless of age.
    func refreshAll() async {
        async let e: Void = refreshEvents()
        async let b: Void = refreshBookings()
        _ = await (e, b)
        recomputeOverlay()
    }

    func refreshEvents() async {
        guard !isLoadingEvents else { return }
        isLoadingEvents = true
        defer { isLoadingEvents = false }
        do {
            let result = try await eventsService.fetchEvents(.latest)
            apply(events: result.events)
            eventsError = nil
            lastEventsFetch = Date()
            Self.writeCache(result.payload, to: Self.eventsCacheURL)
        } catch is CancellationError {
            return
        } catch {
            if (error as? URLError)?.code == .cancelled { return }
            eventsError = events.isEmpty
                ? "Couldn't load events. Check your connection and try again."
                : nil
            // Retry sooner than the normal interval.
            lastEventsFetch = Date().addingTimeInterval(-Self.eventsRefreshInterval + 60)
        }
    }

    func refreshBookings() async {
        guard !isFetchingBookings else { return }
        isFetchingBookings = true
        defer { isFetchingBookings = false }
        do {
            let result = try await bookingsService.fetchBookings()
            apply(bookings: result.bookings)
            lastBookingsFetch = Date()
            Self.writeCache(result.payload, to: Self.bookingsCacheURL)
        } catch {
            lastBookingsFetch = Date().addingTimeInterval(-Self.bookingsRefreshInterval + 60)
        }
    }

    func refreshOrgs() async {
        guard !isFetchingOrgs else { return }
        isFetchingOrgs = true
        defer { isFetchingOrgs = false }
        guard let result = try? await orgService.fetchDirectory(), !result.directory.isEmpty else { return }
        if result.directory != orgs { orgs = result.directory }
        Self.writeCache(result.payload, to: Self.orgsCacheURL)
    }

    /// Refreshes a single event via `GET /view/:id`, replacing it in place.
    /// Returns nil if the event was removed upstream.
    func refreshEvent(id: Int) async -> VatsimEvent? {
        guard let updated = try? await eventsService.fetchEvent(id: id) else {
            return events.first { $0.id == id }
        }
        if let index = events.firstIndex(where: { $0.id == id }), events[index] != updated {
            var copy = events
            copy[index] = updated
            apply(events: copy)
        }
        return updated
    }

    private func apply(events newEvents: [VatsimEvent]) {
        let now = Date()
        let sorted = newEvents
            .filter { $0.endTime > now }
            .sorted { $0.startTime == $1.startTime ? $0.name < $1.name : $0.startTime < $1.startTime }
        guard sorted != events else { return }
        events = sorted

        var index: [String: [VatsimEvent]] = [:]
        for event in sorted {
            for icao in event.allICAOs {
                index[icao, default: []].append(event)
            }
        }
        eventsByICAO = index
        recomputeOverlay()
    }

    private func apply(bookings newBookings: [AtcBooking]) {
        let now = Date()
        let sorted = newBookings
            .filter { $0.end > now }
            .sorted { $0.start == $1.start ? $0.callsign < $1.callsign : $0.start < $1.start }
        guard sorted != bookings else { return }
        bookings = sorted
        recomputeOverlay()
    }

    // MARK: - Disk Cache

    private func loadDiskCache() async {
        let eventsURL = Self.eventsCacheURL
        let bookingsURL = Self.bookingsCacheURL
        async let cachedEvents = Self.readCachedEvents(eventsURL)
        async let cachedBookings = Self.readCachedBookings(bookingsURL)
        async let cachedOrgs = Self.readCachedOrgs(Self.orgsCacheURL)
        let (e, b, o) = await (cachedEvents, cachedBookings, cachedOrgs)
        if events.isEmpty, !e.isEmpty { apply(events: e) }
        if bookings.isEmpty, !b.isEmpty { apply(bookings: b) }
        if orgs.isEmpty, let o { orgs = o }
    }

    @concurrent
    private static func readCachedOrgs(_ url: URL) async -> VatsimOrgDirectory? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return await OrgDirectoryService.decodeCached(data)
    }

    @concurrent
    private static func readCachedEvents(_ url: URL) async -> [VatsimEvent] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return await EventsService.decodeCachedEvents(data)
    }

    @concurrent
    private static func readCachedBookings(_ url: URL) async -> [AtcBooking] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return await BookingsService.decodeCachedBookings(data)
    }

    private static func writeCache(_ data: Data, to url: URL) {
        Task.detached(priority: .utility) {
            try? data.write(to: url, options: .atomic)
        }
    }

    // MARK: - Overlay

    /// Re-derives the map overlay from the feeds, the clock and the user's settings.
    /// Cheap (a single pass over each feed); only publishes when the result differs.
    func recomputeOverlay(now: Date = Date()) {
        let userPrefs = prefs.userPrefs

        // Drop anything that has ended since the last tick.
        if events.contains(where: { $0.endTime <= now }) {
            events.removeAll { $0.endTime <= now }
            eventsByICAO = eventsByICAO.compactMapValues { list in
                let kept = list.filter { $0.endTime > now }
                return kept.isEmpty ? nil : kept
            }
        }
        if bookings.contains(where: { $0.end <= now }) {
            bookings.removeAll { $0.end <= now }
        }

        let eventWindowEnd = now.addingTimeInterval(userPrefs.upcomingEventWindow)
        var eventHighlights: [String: AirportHighlight] = [:]
        for event in events where event.startTime <= eventWindowEnd {
            let highlight: AirportHighlight = event.startTime <= now ? .activeEvent : .upcomingEvent
            for icao in event.allICAOs where (eventHighlights[icao] ?? .upcomingBooking) < highlight {
                eventHighlights[icao] = highlight
            }
        }

        let bookingWindow = userPrefs.upcomingBookingWindow
        let relevantBookings = bookings.filter { $0.isRelevant(at: now, window: bookingWindow) }

        let next = EventOverlayInputs(
            eventHighlights: eventHighlights,
            bookings: relevantBookings,
            showEventHighlights: userPrefs.showEventAirportHighlights,
            showBookingHighlights: userPrefs.showBookingAirportHighlights,
            showBookedSectors: userPrefs.showBookedSectors,
            timeDisplay: EventTimeDisplayValue(rawValue: userPrefs.eventTimeDisplay.rawValue) ?? .utc
        )
        if next != overlay {
            overlay = next
        }
    }

    // MARK: - Queries

    /// Live and upcoming events that involve this airport, soonest first.
    func events(atAirport icao: String) -> [VatsimEvent] {
        eventsByICAO[icao.uppercased()] ?? []
    }

    /// Every VATSIM region from the Core API, plus any ID seen in the feed that the API
    /// didn't list (so a filter is never missing an organiser).
    var filterRegions: [VatsimRegion] {
        var result = orgs.regions
        let known = Set(result.map(\.id))
        let extra = Set(events.flatMap { $0.organisers.compactMap(\.region) }).subtracting(known)
        result += extra.filter { !$0.isEmpty }.sorted().map { VatsimRegion(id: $0, name: $0) }
        return result
    }

    /// Divisions from the Core API, limited to `region` when one is selected.
    func filterDivisions(inRegion region: String?) -> [VatsimDivision] {
        var result = orgs.divisions
        let known = Set(result.map(\.id))
        let feedDivisions = events.flatMap { event in
            event.organisers.compactMap { organiser -> (String, String?)? in
                guard let division = organiser.division, !division.isEmpty else { return nil }
                return (division, organiser.region)
            }
        }
        var seen = Set<String>()
        for (division, parent) in feedDivisions where !known.contains(division) && seen.insert(division).inserted {
            result.append(VatsimDivision(id: division, name: division, parentRegion: parent))
        }
        guard let region else { return result }
        return result.filter { $0.parentRegion == nil || $0.parentRegion == region }
    }

    /// Number of current/upcoming events per region and division ID, for filter labels.
    var eventCountsByOrganiser: (regions: [String: Int], divisions: [String: Int]) {
        var regions: [String: Int] = [:]
        var divisions: [String: Int] = [:]
        for event in events {
            for region in Set(event.organisers.compactMap(\.region)) { regions[region, default: 0] += 1 }
            for division in Set(event.organisers.compactMap(\.division)) { divisions[division, default: 0] += 1 }
        }
        return (regions, divisions)
    }
}
