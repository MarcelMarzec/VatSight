//
//  AtcBooking.swift
//  VatSight
//
//  Models for the VATSIM ATC Bookings API (https://atc-bookings.vatsim.net/api-spec.json).
//

import Foundation

// MARK: - Booking Type

nonisolated enum AtcBookingType: Hashable, Sendable, Codable {
    case booking
    case event
    case exam
    case training
    case other(String)

    init(rawValue: String) {
        switch rawValue.lowercased() {
        case "booking": self = .booking
        case "event": self = .event
        case "exam": self = .exam
        case "training": self = .training
        default: self = .other(rawValue)
        }
    }

    var rawValue: String {
        switch self {
        case .booking: return "booking"
        case .event: return "event"
        case .exam: return "exam"
        case .training: return "training"
        case .other(let value): return value
        }
    }

    var displayName: String {
        switch self {
        case .booking: return "Booking"
        case .event: return "Event"
        case .exam: return "Exam"
        case .training: return "Training"
        case .other(let value): return value.capitalized
        }
    }

    var systemImage: String {
        switch self {
        case .booking: return "headphones"
        case .event: return "star.fill"
        case .exam: return "graduationcap.fill"
        case .training: return "person.2.fill"
        case .other: return "calendar"
        }
    }

    /// The values the API accepts for the `type` parameter.
    static let apiTypes: [AtcBookingType] = [.booking, .event, .exam, .training]

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: (try? container.decode(String.self)) ?? "booking")
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

// MARK: - Booking

nonisolated struct AtcBooking: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let cid: Int
    let type: AtcBookingType
    let callsign: String
    let start: Date
    let end: Date
    let division: String
    let subdivision: String?

    enum CodingKeys: String, CodingKey {
        case id, cid, type, callsign, start, end, division, subdivision
    }

    init(id: Int, cid: Int, type: AtcBookingType, callsign: String, start: Date, end: Date, division: String, subdivision: String?) {
        self.id = id
        self.cid = cid
        self.type = type
        self.callsign = callsign.uppercased()
        self.start = start
        self.end = max(end, start)
        self.division = division
        self.subdivision = subdivision
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        cid = (try? c.decode(Int.self, forKey: .cid)) ?? 0
        type = (try? c.decode(AtcBookingType.self, forKey: .type)) ?? .booking
        callsign = try c.decode(String.self, forKey: .callsign).uppercased()
        let startString = try c.decode(String.self, forKey: .start)
        let endString = try c.decode(String.self, forKey: .end)
        guard let s = EventDateParsing.bookingDate(startString) else {
            throw DecodingError.dataCorruptedError(forKey: .start, in: c, debugDescription: "Invalid date \(startString)")
        }
        start = s
        end = max(EventDateParsing.bookingDate(endString) ?? s, s)
        division = ((try? c.decodeIfPresent(String.self, forKey: .division)) ?? nil) ?? ""
        subdivision = (try? c.decodeIfPresent(String.self, forKey: .subdivision)) ?? nil
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(cid, forKey: .cid)
        try c.encode(type, forKey: .type)
        try c.encode(callsign, forKey: .callsign)
        try c.encode(EventDateParsing.bookingString(start), forKey: .start)
        try c.encode(EventDateParsing.bookingString(end), forKey: .end)
        try c.encode(division, forKey: .division)
        try c.encodeIfPresent(subdivision, forKey: .subdivision)
    }

    // MARK: Callsign components

    private var components: [Substring] {
        callsign.split(separator: "_", omittingEmptySubsequences: true)
    }

    /// "EDDM" for "EDDM_N_TWR".
    var callsignPrefix: String { components.first.map(String.init) ?? callsign }

    /// "TWR" for "EDDM_N_TWR".
    var facilitySuffix: String { components.count > 1 ? String(components.last!) : "" }

    /// "N" for "EDDM_N_TWR", "" for "EDDM_TWR".
    var middleComponent: String {
        guard components.count > 2 else { return "" }
        return components[1..<(components.count - 1)].joined(separator: "_")
    }

    /// Positions that control an airport directly (as opposed to enroute CTR/FSS).
    var isAirportPosition: Bool {
        ["DEL", "GND", "TWR", "APP", "DEP", "RMP", "ATIS"].contains(facilitySuffix)
    }

    var isEnroutePosition: Bool { ["CTR", "FSS"].contains(facilitySuffix) }

    var duration: TimeInterval { end.timeIntervalSince(start) }

    func isActive(at now: Date = Date()) -> Bool { start <= now && end > now }

    /// Active now, or starting within `window` seconds.
    func isRelevant(at now: Date, window: TimeInterval) -> Bool {
        end > now && start <= now.addingTimeInterval(window)
    }
}

// MARK: - Query

/// Every query parameter of `GET /api/booking`. Can be sent to the server (`queryItems`) or
/// evaluated locally with the same semantics (`matches(_:)` / `apply(to:)`).
nonisolated struct BookingQuery: Hashable, Sendable {
    enum Sort: String, CaseIterable, Sendable { case start, end, callsign }
    enum SortDirection: String, CaseIterable, Sendable { case asc, desc }

    /// Only bookings tied to the request's API key. Requires a key; meaningless without one.
    var keyOnly: Bool? = nil
    /// Each element matches as `%element%` (prefix, suffix or anywhere).
    var callsigns: [String] = []
    var cid: Int? = nil
    /// Bookings that start on this UTC day.
    var date: Date? = nil
    var type: AtcBookingType? = nil
    /// Required by the API when `subdivision` is set.
    var division: String? = nil
    var subdivision: String? = nil
    /// Server default: start. Required with `sortDirection`.
    var sort: Sort? = nil
    /// Server default: asc.
    var sortDirection: SortDirection? = nil

    init(
        keyOnly: Bool? = nil,
        callsigns: [String] = [],
        cid: Int? = nil,
        date: Date? = nil,
        type: AtcBookingType? = nil,
        division: String? = nil,
        subdivision: String? = nil,
        sort: Sort? = nil,
        sortDirection: SortDirection? = nil
    ) {
        self.keyOnly = keyOnly
        self.callsigns = callsigns
        self.cid = cid
        self.date = date
        self.type = type
        self.division = division
        self.subdivision = subdivision
        self.sort = sort
        self.sortDirection = sortDirection
    }

    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let keyOnly { items.append(URLQueryItem(name: "key_only", value: keyOnly ? "true" : "false")) }
        let cleaned = callsigns.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if !cleaned.isEmpty { items.append(URLQueryItem(name: "callsign", value: cleaned.joined(separator: ","))) }
        if let cid { items.append(URLQueryItem(name: "cid", value: String(cid))) }
        if let date { items.append(URLQueryItem(name: "date", value: EventDateParsing.bookingDay(date))) }
        if let type { items.append(URLQueryItem(name: "type", value: type.rawValue)) }
        // The API requires division whenever subdivision is present.
        if let division, !division.isEmpty {
            items.append(URLQueryItem(name: "division", value: division))
            if let subdivision, !subdivision.isEmpty {
                items.append(URLQueryItem(name: "subdivision", value: subdivision))
            }
        }
        if let sort {
            items.append(URLQueryItem(name: "sort", value: sort.rawValue))
            items.append(URLQueryItem(name: "sort_dir", value: (sortDirection ?? .asc).rawValue))
        } else if let sortDirection {
            items.append(URLQueryItem(name: "sort", value: Sort.start.rawValue))
            items.append(URLQueryItem(name: "sort_dir", value: sortDirection.rawValue))
        }
        return items
    }

    /// Local equivalent of the server-side filters. `keyOnly` can't be evaluated locally and is ignored.
    func matches(_ booking: AtcBooking) -> Bool {
        let cleaned = callsigns.map { $0.trimmingCharacters(in: .whitespaces).uppercased() }.filter { !$0.isEmpty }
        if !cleaned.isEmpty, !cleaned.contains(where: { booking.callsign.contains($0) }) { return false }
        if let cid, booking.cid != cid { return false }
        if let date, EventDateParsing.bookingDay(booking.start) != EventDateParsing.bookingDay(date) { return false }
        if let type, booking.type != type { return false }
        if let division, !division.isEmpty, booking.division.caseInsensitiveCompare(division) != .orderedSame { return false }
        if let subdivision, !subdivision.isEmpty,
           (booking.subdivision ?? "").caseInsensitiveCompare(subdivision) != .orderedSame { return false }
        return true
    }

    func apply(to bookings: [AtcBooking]) -> [AtcBooking] {
        let filtered = bookings.filter(matches)
        let ascending = (sortDirection ?? .asc) == .asc
        let key = sort ?? .start
        return filtered.sorted { lhs, rhs in
            // Swap operands for descending order so the comparator stays a strict weak ordering.
            let (a, b) = ascending ? (lhs, rhs) : (rhs, lhs)
            switch key {
            case .start: return a.start == b.start ? a.callsign < b.callsign : a.start < b.start
            case .end: return a.end == b.end ? a.callsign < b.callsign : a.end < b.end
            case .callsign: return a.callsign == b.callsign ? a.start < b.start : a.callsign < b.callsign
            }
        }
    }
}

// MARK: - Response Wrapper

nonisolated struct AtcBookingListResponse: Decodable, Sendable {
    let bookings: [AtcBooking]

    init(from decoder: any Decoder) throws {
        var items = try decoder.unkeyedContainer()
        var result: [AtcBooking] = []
        while !items.isAtEnd {
            if let booking = try? items.decode(AtcBooking.self) {
                result.append(booking)
            } else {
                _ = try? items.decode(DiscardedValue.self)
            }
        }
        bookings = result
    }
}
