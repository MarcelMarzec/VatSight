//
//  VatsimEvent.swift
//  VatSight
//
//  Models for the VATSIM Events API (https://my.vatsim.net/api/v2/events).
//  Every field in the published schema is decoded. Decoding is tolerant: unknown event
//  types are kept, and missing optional fields fall back to empty values instead of failing.
//

import Foundation

// MARK: - Event Type

nonisolated enum VatsimEventType: Hashable, Sendable, Codable {
    case event
    case controllerExamination
    case vasopsEvent
    case other(String)

    init(rawValue: String) {
        switch rawValue.trimmingCharacters(in: .whitespaces).lowercased() {
        case "event": self = .event
        case "controller examination": self = .controllerExamination
        case "vasops event": self = .vasopsEvent
        default: self = .other(rawValue)
        }
    }

    var rawValue: String {
        switch self {
        case .event: return "Event"
        case .controllerExamination: return "Controller Examination"
        case .vasopsEvent: return "VASOPS Event"
        case .other(let value): return value
        }
    }

    var displayName: String {
        switch self {
        case .event: return "Event"
        case .controllerExamination: return "ATC Exam"
        case .vasopsEvent: return "VASOPS"
        case .other(let value): return value
        }
    }

    var systemImage: String {
        switch self {
        case .event: return "star.fill"
        case .controllerExamination: return "graduationcap.fill"
        case .vasopsEvent: return "airplane.circle.fill"
        case .other: return "calendar"
        }
    }

    /// The types documented by the API, used to populate filters.
    static let knownTypes: [VatsimEventType] = [.event, .controllerExamination, .vasopsEvent]

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: (try? container.decode(String.self)) ?? "")
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

// MARK: - Nested Objects

nonisolated struct EventOrganiser: Codable, Hashable, Sendable {
    let region: String?
    let division: String?
    let subdivision: String?
    let organisedByVatsim: Bool

    enum CodingKeys: String, CodingKey {
        case region, division, subdivision
        case organisedByVatsim = "organised_by_vatsim"
    }

    init(region: String?, division: String?, subdivision: String?, organisedByVatsim: Bool) {
        self.region = region
        self.division = division
        self.subdivision = subdivision
        self.organisedByVatsim = organisedByVatsim
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        region = (try? c.decodeIfPresent(String.self, forKey: .region)) ?? nil
        division = (try? c.decodeIfPresent(String.self, forKey: .division)) ?? nil
        subdivision = (try? c.decodeIfPresent(String.self, forKey: .subdivision)) ?? nil
        organisedByVatsim = (try? c.decodeIfPresent(Bool.self, forKey: .organisedByVatsim)) ?? false
    }

    /// e.g. "EMEA · EUD · GER"
    var summary: String {
        [region, division, subdivision]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .joined(separator: " · ")
    }
}

nonisolated struct EventAirport: Codable, Hashable, Sendable {
    let icao: String

    init(icao: String) { self.icao = icao }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        icao = ((try? c.decode(String.self, forKey: .icao)) ?? "").uppercased()
    }
}

nonisolated struct EventRoute: Codable, Hashable, Sendable {
    let departure: String
    let arrival: String
    let route: String

    init(departure: String, arrival: String, route: String) {
        self.departure = departure
        self.arrival = arrival
        self.route = route
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        departure = ((try? c.decodeIfPresent(String.self, forKey: .departure)) ?? nil)?.uppercased() ?? ""
        arrival = ((try? c.decodeIfPresent(String.self, forKey: .arrival)) ?? nil)?.uppercased() ?? ""
        route = ((try? c.decodeIfPresent(String.self, forKey: .route)) ?? nil) ?? ""
    }
}

// MARK: - Event

nonisolated enum VatsimEventStatus: Sendable, Equatable {
    case upcoming
    case live
    case ended
}

nonisolated struct VatsimEvent: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let type: VatsimEventType
    let name: String
    let link: URL?
    let organisers: [EventOrganiser]
    let airports: [EventAirport]
    let routes: [EventRoute]
    let startTime: Date
    let endTime: Date
    /// Markdown
    let shortDescription: String
    /// Markdown
    let description: String
    let banner: URL?

    enum CodingKeys: String, CodingKey {
        case id, type, name, link, organisers, airports, routes, banner, description
        case startTime = "start_time"
        case endTime = "end_time"
        case shortDescription = "short_description"
    }

    init(
        id: Int,
        type: VatsimEventType,
        name: String,
        link: URL?,
        organisers: [EventOrganiser],
        airports: [EventAirport],
        routes: [EventRoute],
        startTime: Date,
        endTime: Date,
        shortDescription: String,
        description: String,
        banner: URL?
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.link = link
        self.organisers = organisers
        self.airports = airports
        self.routes = routes
        self.startTime = startTime
        self.endTime = max(endTime, startTime)
        self.shortDescription = shortDescription
        self.description = description
        self.banner = banner
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        type = (try? c.decode(VatsimEventType.self, forKey: .type)) ?? .other("")
        name = ((try? c.decodeIfPresent(String.self, forKey: .name)) ?? nil) ?? "Untitled Event"
        link = Self.url(from: (try? c.decodeIfPresent(String.self, forKey: .link)) ?? nil)
        organisers = ((try? c.decodeIfPresent([EventOrganiser].self, forKey: .organisers)) ?? nil) ?? []
        let rawAirports = ((try? c.decodeIfPresent([EventAirport].self, forKey: .airports)) ?? nil) ?? []
        airports = rawAirports.filter { !$0.icao.isEmpty }
        routes = ((try? c.decodeIfPresent([EventRoute].self, forKey: .routes)) ?? nil) ?? []

        let startString = try c.decode(String.self, forKey: .startTime)
        let endString = try c.decode(String.self, forKey: .endTime)
        guard let start = EventDateParsing.iso8601(startString) else {
            throw DecodingError.dataCorruptedError(forKey: .startTime, in: c, debugDescription: "Invalid date \(startString)")
        }
        startTime = start
        endTime = max(EventDateParsing.iso8601(endString) ?? start, start)

        shortDescription = ((try? c.decodeIfPresent(String.self, forKey: .shortDescription)) ?? nil) ?? ""
        description = ((try? c.decodeIfPresent(String.self, forKey: .description)) ?? nil) ?? ""
        banner = Self.url(from: (try? c.decodeIfPresent(String.self, forKey: .banner)) ?? nil)
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(type, forKey: .type)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(link?.absoluteString, forKey: .link)
        try c.encode(organisers, forKey: .organisers)
        try c.encode(airports, forKey: .airports)
        try c.encode(routes, forKey: .routes)
        try c.encode(EventDateParsing.iso8601String(startTime), forKey: .startTime)
        try c.encode(EventDateParsing.iso8601String(endTime), forKey: .endTime)
        try c.encode(shortDescription, forKey: .shortDescription)
        try c.encode(description, forKey: .description)
        try c.encodeIfPresent(banner?.absoluteString, forKey: .banner)
    }

    private static func url(from string: String?) -> URL? {
        guard let string = string?.trimmingCharacters(in: .whitespacesAndNewlines), !string.isEmpty else { return nil }
        return URL(string: string)
    }

    // MARK: Derived

    var duration: TimeInterval { endTime.timeIntervalSince(startTime) }

    /// All ICAOs involved, in order: listed airports, then route endpoints not already listed.
    var allICAOs: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for icao in airports.map(\.icao) + routes.flatMap({ [$0.departure, $0.arrival] })
        where !icao.isEmpty && seen.insert(icao).inserted {
            result.append(icao)
        }
        return result
    }

    var isOrganisedByVatsim: Bool { organisers.contains { $0.organisedByVatsim } }

    func status(at now: Date = Date()) -> VatsimEventStatus {
        if now < startTime { return .upcoming }
        if now < endTime { return .live }
        return .ended
    }

    func overlaps(_ start: Date, _ end: Date) -> Bool {
        startTime < end && endTime > start
    }
}

// MARK: - Response Wrappers

nonisolated struct VatsimEventListResponse: Decodable, Sendable {
    let data: [VatsimEvent]

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Decode element-by-element so one malformed event doesn't discard the whole feed.
        var items = try c.nestedUnkeyedContainer(forKey: .data)
        var events: [VatsimEvent] = []
        while !items.isAtEnd {
            if let event = try? items.decode(VatsimEvent.self) {
                events.append(event)
            } else {
                _ = try? items.decode(DiscardedValue.self)
            }
        }
        data = events
    }

    private enum CodingKeys: String, CodingKey { case data }
}

nonisolated struct VatsimEventResponse: Decodable, Sendable {
    let data: VatsimEvent
}

/// Swallows one undecodable element so an unkeyed container can advance past it.
nonisolated struct DiscardedValue: Decodable, Sendable {
    init(from decoder: any Decoder) throws {}
}

// MARK: - Date Parsing

nonisolated enum EventDateParsing {
    nonisolated(unsafe) private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    nonisolated(unsafe) private static let whole: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Parses "2026-11-22T05:00:00.000000Z" and variants with or without fractional seconds.
    static func iso8601(_ string: String) -> Date? {
        if let date = fractional.date(from: string) { return date }
        if let date = whole.date(from: string) { return date }
        // Strip any fractional component the formatter refuses (e.g. 6+ digits on some OS versions).
        if let dot = string.firstIndex(of: ".") {
            var rest = string[string.index(after: dot)...]
            while let first = rest.first, first.isNumber { rest = rest.dropFirst() }
            return whole.date(from: String(string[..<dot]) + rest)
        }
        return nil
    }

    static func iso8601String(_ date: Date) -> String {
        whole.string(from: date)
    }

    /// Booking API format: "yyyy-MM-dd HH:mm:ss" in UTC.
    nonisolated(unsafe) private static let bookingFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    nonisolated(unsafe) private static let bookingDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func bookingDate(_ string: String) -> Date? {
        if let date = bookingFormatter.date(from: string) { return date }
        return iso8601(string)
    }

    static func bookingString(_ date: Date) -> String {
        bookingFormatter.string(from: date)
    }

    /// "yyyy-MM-dd" for the booking API's `date` query parameter.
    static func bookingDay(_ date: Date) -> String {
        bookingDayFormatter.string(from: date)
    }
}

// MARK: - Organisation Directory (Core API v1)

/// `GET https://api.vatsim.net/api/regions/`
nonisolated struct VatsimRegion: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let name: String
}

/// `GET https://api.vatsim.net/api/divisions/`
nonisolated struct VatsimDivision: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let name: String
    let parentRegion: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case parentRegion = "parentregion"
    }
}

/// `GET https://api.vatsim.net/api/subdivisions/`
nonisolated struct VatsimSubdivision: Codable, Hashable, Sendable, Identifiable {
    let code: String
    let name: String
    let parentDivision: String?

    var id: String { code }

    enum CodingKeys: String, CodingKey {
        case code
        case name = "fullname"
        case parentDivision = "parentdivision"
    }
}

/// Region, division and subdivision names, used to label organisers and build filters.
nonisolated struct VatsimOrgDirectory: Codable, Sendable, Equatable {
    var regions: [VatsimRegion] = []
    var divisions: [VatsimDivision] = []
    var subdivisions: [VatsimSubdivision] = []
    var fetched: Date? = nil

    static let empty = VatsimOrgDirectory()

    var isEmpty: Bool { regions.isEmpty && divisions.isEmpty }

    func regionName(_ id: String?) -> String? {
        guard let id, !id.isEmpty else { return nil }
        return regions.first { $0.id.caseInsensitiveCompare(id) == .orderedSame }?.name
    }

    func divisionName(_ id: String?) -> String? {
        guard let id, !id.isEmpty else { return nil }
        return divisions.first { $0.id.caseInsensitiveCompare(id) == .orderedSame }?.name
    }

    func subdivisionName(_ code: String?) -> String? {
        guard let code, !code.isEmpty else { return nil }
        return subdivisions.first { $0.code.caseInsensitiveCompare(code) == .orderedSame }?.name
    }

    /// "Europe, Middle East and Africa · Europe · Germany", falling back to IDs where a name is unknown.
    func summary(for organiser: EventOrganiser) -> String {
        [
            regionName(organiser.region) ?? organiser.region,
            divisionName(organiser.division) ?? organiser.division,
            subdivisionName(organiser.subdivision) ?? organiser.subdivision
        ]
        .compactMap { $0?.isEmpty == false ? $0 : nil }
        .joined(separator: " · ")
    }
}
