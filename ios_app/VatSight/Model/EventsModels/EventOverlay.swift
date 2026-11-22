//
//  EventOverlay.swift
//  VatSight
//
//  Value types passed from EventsManager to the map. Kept Equatable so the map only
//  rebuilds GeoJSON when something it draws actually changes.
//

import Foundation

/// How an airport dot is highlighted. Higher raw values win when several apply.
nonisolated enum AirportHighlight: Int, Comparable, Sendable {
    case upcomingBooking = 1
    case upcomingEvent = 2
    case activeEvent = 3

    static func < (lhs: AirportHighlight, rhs: AirportHighlight) -> Bool { lhs.rawValue < rhs.rawValue }

    var displayName: String {
        switch self {
        case .upcomingBooking: return "Booked ATC"
        case .upcomingEvent: return "Upcoming Event"
        case .activeEvent: return "Event Now"
        }
    }
}

/// Everything the map needs from the events and bookings feeds at a moment in time.
nonisolated struct EventOverlayInputs: Equatable, Sendable {
    /// ICAO → `.activeEvent` / `.upcomingEvent` (within the user's event window).
    var eventHighlights: [String: AirportHighlight] = [:]
    /// Bookings active now or starting within the user's booking window, sorted by start.
    var bookings: [AtcBooking] = []
    var showEventHighlights = true
    var showBookingHighlights = true
    var showBookedSectors = true
    var timeDisplay: EventTimeDisplayValue = .utc

    static let empty = EventOverlayInputs()
}

/// Sendable mirror of `EventTimeDisplay` for use in background work.
nonisolated enum EventTimeDisplayValue: String, Sendable {
    case utc, local, both
}

/// A VATGlasses sector that will be owned by a booked controller.
struct BookedSector {
    let sector: VatglassesSector
    let booking: AtcBooking
}
