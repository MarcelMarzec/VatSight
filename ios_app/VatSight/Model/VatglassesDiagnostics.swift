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

/// A dynamically generated sector: a TWR or APP/DEP controller was online but had no real
/// VATGlasses sector. A circle approximation was drawn around the airport instead.
struct SyntheticSector: Identifiable {
    let id = UUID()
    let icao: String          // Airport ICAO (e.g. "LSZH")
    let callsign: String      // Controller callsign (e.g. "LSZH_TWR")
    let frequency: String
    let radiusNm: Double      // 5 for TWR, 20 for APP/DEP
    let cid: Int
    let name: String
}

/// Snapshot of all developer diagnostics produced during the last data load / active-sector pass.
struct VatglassesDiagnostics {
    /// Errors from parsing individual files or directories.
    var parseErrors: [VatglassesParseError] = []
    /// Controllers online that matched no Vatglasses sector/position.
    var unmatchedControllers: [UnmatchedController] = []
    /// Airports whose coordinates were outside valid WGS-84 ranges after parsing.
    var invalidAirports: [InvalidAirport] = []
    /// Sectors that were synthetically generated because no real sector data existed.
    var syntheticSectors: [SyntheticSector] = []
    /// Timestamp of when this snapshot was last updated.
    var lastUpdated: Date = .distantPast
}
