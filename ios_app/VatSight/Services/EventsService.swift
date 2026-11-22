//
//  EventsService.swift
//  VatSight
//
//  Client for the VATSIM Events API v2 (https://vatsim.dev/api/events-api).
//  Network and decoding work runs off the main actor (`@concurrent`).
//

import Foundation

nonisolated enum EventsServiceError: LocalizedError {
    case badStatus(Int)

    var errorDescription: String? {
        switch self {
        case .badStatus(let code): return "The VATSIM Events service returned an error (\(code))."
        }
    }
}

nonisolated struct EventsService: Sendable {

    static let baseURL = URL(string: "https://my.vatsim.net/api/v2/events")!

    /// Every endpoint documented by the Events API.
    enum Endpoint: Hashable, Sendable {
        /// `GET /latest` — all current and upcoming events.
        case latest
        /// `GET /latest/:num` — the next `num` current and upcoming events.
        case latestCount(Int)
        /// `GET /view/:eventId`
        case event(id: Int)
        /// `GET /view/region/:regionId` (e.g. "AMAS")
        case region(String)
        /// `GET /view/division/:divisionId` (e.g. "USA")
        case division(String)
        /// `GET /export` — iCalendar feed of all current and upcoming events.
        case export

        var url: URL {
            switch self {
            case .latest:
                return EventsService.baseURL.appending(path: "latest")
            case .latestCount(let count):
                return EventsService.baseURL.appending(path: "latest").appending(path: String(max(1, count)))
            case .event(let id):
                return EventsService.baseURL.appending(path: "view").appending(path: String(id))
            case .region(let region):
                return EventsService.baseURL.appending(path: "view/region").appending(path: region)
            case .division(let division):
                return EventsService.baseURL.appending(path: "view/division").appending(path: division)
            case .export:
                return EventsService.baseURL.appending(path: "export")
            }
        }
    }

    /// The iCal feed as a `webcal://` URL, which iOS hands to Calendar as a subscription.
    static var calendarSubscriptionURL: URL {
        var components = URLComponents(url: Endpoint.export.url, resolvingAgainstBaseURL: false)!
        components.scheme = "webcal"
        return components.url!
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Fetches a list endpoint (`latest`, `latestCount`, `region`, `division`).
    /// Returns the decoded events and the raw payload (for disk caching).
    @concurrent
    func fetchEvents(_ endpoint: Endpoint = .latest) async throws -> (events: [VatsimEvent], payload: Data) {
        let data = try await load(endpoint.url)
        let response = try JSONDecoder().decode(VatsimEventListResponse.self, from: data)
        return (response.data, data)
    }

    /// `GET /view/:eventId`. Returns nil when the event no longer exists (HTTP 404).
    @concurrent
    func fetchEvent(id: Int) async throws -> VatsimEvent? {
        var request = URLRequest(url: Endpoint.event(id: id).url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 200
        if status == 404 { return nil }
        guard (200..<300).contains(status) else { throw EventsServiceError.badStatus(status) }
        return try JSONDecoder().decode(VatsimEventResponse.self, from: data).data
    }

    /// Raw iCalendar text from `GET /export`.
    @concurrent
    func fetchCalendarExport() async throws -> String {
        let data = try await load(Endpoint.export.url, accept: "text/calendar")
        return String(decoding: data, as: UTF8.self)
    }

    /// Decodes a previously cached `/latest` payload.
    @concurrent
    static func decodeCachedEvents(_ data: Data) async -> [VatsimEvent] {
        (try? JSONDecoder().decode(VatsimEventListResponse.self, from: data).data) ?? []
    }

    private func load(_ url: URL, accept: String = "application/json") async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(accept, forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw EventsServiceError.badStatus(http.statusCode)
        }
        return data
    }
}

nonisolated struct BookingsService: Sendable {

    static let bookingsURL = URL(string: "https://atc-bookings.vatsim.net/api/booking")!

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    static func url(for query: BookingQuery) -> URL {
        let items = query.queryItems
        guard !items.isEmpty else { return bookingsURL }
        var components = URLComponents(url: bookingsURL, resolvingAgainstBaseURL: false)!
        components.queryItems = items
        return components.url ?? bookingsURL
    }

    /// `GET /api/booking` with any combination of the documented parameters.
    /// Note: the live API currently returns HTTP 500 for `type=event`; callers that need a
    /// type filter should fetch unfiltered and use `BookingQuery.apply(to:)` locally.
    @concurrent
    func fetchBookings(_ query: BookingQuery = BookingQuery()) async throws -> (bookings: [AtcBooking], payload: Data) {
        var request = URLRequest(url: Self.url(for: query))
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw EventsServiceError.badStatus(http.statusCode)
        }
        let decoded = try JSONDecoder().decode(AtcBookingListResponse.self, from: data)
        return (decoded.bookings, data)
    }

    /// `GET /api/booking/{id}`. Returns nil on 404.
    @concurrent
    func fetchBooking(id: Int) async throws -> AtcBooking? {
        var request = URLRequest(url: Self.bookingsURL.appending(path: String(id)))
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 200
        if status == 404 { return nil }
        guard (200..<300).contains(status) else { throw EventsServiceError.badStatus(status) }
        return try JSONDecoder().decode(AtcBooking.self, from: data)
    }

    @concurrent
    static func decodeCachedBookings(_ data: Data) async -> [AtcBooking] {
        (try? JSONDecoder().decode(AtcBookingListResponse.self, from: data).bookings) ?? []
    }
}

/// Client for the Core API v1 organisation lists (public, no key).
nonisolated struct OrgDirectoryService: Sendable {
    static let baseURL = URL(string: "https://api.vatsim.net/api")!

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    @concurrent
    func fetchDirectory() async throws -> (directory: VatsimOrgDirectory, payload: Data) {
        async let regions: [VatsimRegion] = load("regions")
        async let divisions: [VatsimDivision] = load("divisions")
        async let subdivisions: [VatsimSubdivision] = load("subdivisions")
        let directory = VatsimOrgDirectory(
            regions: try await regions.sorted { $0.name < $1.name },
            divisions: try await divisions.sorted { $0.name < $1.name },
            subdivisions: try await subdivisions.sorted { $0.name < $1.name },
            fetched: Date()
        )
        return (directory, try JSONEncoder().encode(directory))
    }

    @concurrent
    static func decodeCached(_ data: Data) async -> VatsimOrgDirectory? {
        try? JSONDecoder().decode(VatsimOrgDirectory.self, from: data)
    }

    private func load<T: Decodable & Sendable>(_ path: String) async throws -> [T] {
        var request = URLRequest(url: Self.baseURL.appending(path: path).appending(path: ""))
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw EventsServiceError.badStatus(http.statusCode)
        }
        // Element-wise so one odd entry doesn't drop the list.
        return try JSONDecoder().decode(LossyArray<T>.self, from: data).elements
    }
}

nonisolated struct LossyArray<Element: Decodable & Sendable>: Decodable, Sendable {
    let elements: [Element]

    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var result: [Element] = []
        while !container.isAtEnd {
            if let element = try? container.decode(Element.self) {
                result.append(element)
            } else {
                _ = try? container.decode(DiscardedValue.self)
            }
        }
        elements = result
    }
}
