//
//  VatglassesDiagnostics.swift
//  VatSight
//

import Foundation

/// A single parse-time error recorded while loading Vatglasses data.
struct VatglassesParseError: Identifiable {
    let id = UUID()
    let source: String       // filename or directory that failed
    let message: String
    let date: Date
}

/// A controller that is online on VATSIM but could not be matched to any Vatglasses sector.
struct UnmatchedController: Identifiable {
    let id = UUID()
    let callsign: String
    let frequency: String
    let cid: Int
    let name: String
}

/// An airport whose stored coordinates fall outside valid WGS-84 ranges after parsing.
struct InvalidAirport: Identifiable {
    let id = UUID()
    let icao: String
    let name: String
    let latitude: Double
    let longitude: Double

    var reason: String {
        var parts: [String] = []
        if abs(latitude) > 90  { parts.append("lat \(String(format: "%.6f", latitude))") }
        if abs(longitude) > 180 { parts.append("lon \(String(format: "%.6f", longitude))") }
        return parts.isEmpty ? "unknown" : parts.joined(separator: ", ")
    }
}

/// Snapshot of all developer diagnostics produced during the last data load / active-sector pass.
struct VatglassesDiagnostics {
    /// Errors from parsing individual files or directories.
    var parseErrors: [VatglassesParseError] = []
    /// Controllers online that matched no Vatglasses sector/position.
    var unmatchedControllers: [UnmatchedController] = []
    /// Airports whose coordinates were outside valid WGS-84 ranges after parsing.
    var invalidAirports: [InvalidAirport] = []
    /// Timestamp of when this snapshot was last updated.
    var lastUpdated: Date = .distantPast
}
