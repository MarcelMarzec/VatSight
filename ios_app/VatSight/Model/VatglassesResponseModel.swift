//
//  VatglassesResponseModel.swift
//  VatSight
//
//  Created by Marcel Marzec on 03/06/2026.
//

import Foundation
import Turf
import CoreLocation

struct VatglassesComitModel: Codable {
    let sha: String
}

// MARK: - Position Model

/// Represents a controller position in Vatglasses
struct VatglassesPosition: Codable {
    let callsign: String
    let frequency: String
    let type: String  // CTR, APP, TWR, GND, DEL, FSS
    let facilityPrefixes: [String]  // "pre" array in JSON
    let colors: [String]?  // Hex color codes from "colours" array
    
    /// Returns the primary color hex string if available
    var primaryColorHex: String? {
        colors?.first
    }
}

// MARK: - Sector Data Model

struct VatglassesSector: Codable, Identifiable {
    let id: String
    let ownerRefs: [String]  // Ordered list of owner position IDs (hierarchical)
    let frequency: String
    let geometry: SectorGeometry
    let properties: SectorProperties?
    
    var isActive: Bool
    var activeOwnerColorHex: String?  // Color hex from active owner position
    var activeOwnerRef: String?  // The position ID of the active owner (e.g., "YYD")
    var activeController: Controllers?  // The actual controller controlling this sector
    /// True for sectors sourced from nodata.json — FIRs with no full VATGlasses data.
    /// These are matched by callsign prefix and displayed with a "Basic Data Only" indicator.
    var isBasicDataOnly: Bool
    
    init(id: String, ownerRefs: [String], frequency: String, geometry: SectorGeometry, properties: SectorProperties?, isActive: Bool = false, activeOwnerColorHex: String? = nil, activeOwnerRef: String? = nil, activeController: Controllers? = nil, isBasicDataOnly: Bool = false) {
        self.id = id
        self.ownerRefs = ownerRefs
        self.frequency = frequency
        self.geometry = geometry
        self.properties = properties
        self.isActive = isActive
        self.activeOwnerColorHex = activeOwnerColorHex
        self.activeOwnerRef = activeOwnerRef
        self.activeController = activeController
        self.isBasicDataOnly = isBasicDataOnly
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case ownerRefs
        case frequency
        case geometry
        case properties
        case isBasicDataOnly
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        ownerRefs = try container.decode([String].self, forKey: .ownerRefs)
        frequency = try container.decode(String.self, forKey: .frequency)
        geometry = try container.decode(SectorGeometry.self, forKey: .geometry)
        properties = try container.decodeIfPresent(SectorProperties.self, forKey: .properties)
        isBasicDataOnly = try container.decodeIfPresent(Bool.self, forKey: .isBasicDataOnly) ?? false
        isActive = false // Default value when decoding
        activeOwnerColorHex = nil
        activeOwnerRef = nil
        activeController = nil
    }
}

struct SectorGeometry: Codable {
    let type: String // "Polygon" or "MultiPolygon"
    let coordinates: [[[[Double]]]] // GeoJSON coordinate format
    
    // Helper to convert to Turf geometry
    var turfGeometry: Geometry? {
        if type == "Polygon", let firstPolygon = coordinates.first {
            let rings = firstPolygon.map { ring in
                ring.compactMap { coord -> CLLocationCoordinate2D? in
                    guard coord.count >= 2 else { return nil }
                    return CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
                }
            }.filter { !$0.isEmpty }
            guard !rings.isEmpty else { return nil }
            return .polygon(Polygon(rings))
        } else if type == "MultiPolygon" {
            let polygons = coordinates.compactMap { polygonCoords -> Polygon? in
                let rings = polygonCoords.map { ring in
                    ring.compactMap { coord -> CLLocationCoordinate2D? in
                        guard coord.count >= 2 else { return nil }
                        return CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
                    }
                }.filter { !$0.isEmpty }
                guard !rings.isEmpty else { return nil }
                return Polygon(rings)
            }
            guard !polygons.isEmpty else { return nil }
            return .multiPolygon(MultiPolygon(polygons))
        }
        return nil
    }
}

struct SectorProperties: Codable {
    let min: Int?
    let max: Int?
    let name: String?      // Human-readable sector name (e.g. "Solling Low")
    let groupName: String? // Human-readable group name resolved from "groups" dict (e.g. "Maastricht")
    let color: String?
    
    enum CodingKeys: String, CodingKey {
        case min
        case max
        case name
        case groupName
        case color
    }
}

// MARK: - Airport Model

struct VatglassesAirport: Codable, Identifiable {
    let icao: String
    let latitude: Double
    let longitude: Double
    let callsign: String?       // Human-readable airport name (e.g., "Okecie")
    let ownerRefs: [String]     // Ordered list of owner position IDs (hierarchical, "topdown")
    let runways: [String]       // Available runway identifiers (e.g., ["33", "11", "29", "15"])
    
    var id: String { icao }
    
    var isActive: Bool = false
    var activeController: Controllers?
    /// Letters representing present ground-service controllers: T=TWR, G=GND, D=DEL, A=ATIS
    var groundServiceIndicators: String = ""
    
    enum CodingKeys: String, CodingKey {
        case icao
        case latitude
        case longitude
        case callsign
        case ownerRefs
        case runways
    }
    
    init(icao: String, latitude: Double, longitude: Double, callsign: String? = nil, ownerRefs: [String], runways: [String] = []) {
        self.icao = icao
        self.latitude = latitude
        self.longitude = longitude
        self.callsign = callsign
        self.ownerRefs = ownerRefs
        self.runways = runways
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        icao = try container.decode(String.self, forKey: .icao)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        callsign = try container.decodeIfPresent(String.self, forKey: .callsign)
        ownerRefs = try container.decode([String].self, forKey: .ownerRefs)
        runways = try container.decodeIfPresent([String].self, forKey: .runways) ?? []
        isActive = false
        activeController = nil
        groundServiceIndicators = ""
    }
}

// MARK: - Sector File Collection

struct VatglassesData: Codable {
    /// Increment this whenever the cache schema changes to force a fresh download.
    static let currentSchemaVersion = 6

    let schemaVersion: Int
    let sectors: [VatglassesSector]
    let airports: [VatglassesAirport]
    let allPositions: [String: VatglassesPosition]
    let lastUpdated: Date
    let commitSHA: String
    /// Merged callsign label definitions from all parsed vatglasses region files.
    /// Structure: positionType → middleComponent → humanLabel
    /// e.g. ["TWR": ["": "Tower", "I": "Info (AFIS)"], "GND": ["": "Ground", "^[A-Z]": "Ground"]]
    /// An empty middle key ("") matches callsigns with no middle component (e.g. EGLL_TWR).
    /// Non-empty keys may be literal strings or regex patterns.
    let callsignLabels: [String: [String: String]]

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case sectors
        case airports
        case allPositions
        case lastUpdated
        case commitSHA
        case callsignLabels
    }
    
    init(sectors: [VatglassesSector], airports: [VatglassesAirport], allPositions: [String: VatglassesPosition], lastUpdated: Date, commitSHA: String, callsignLabels: [String: [String: String]] = [:]) {
        self.schemaVersion = Self.currentSchemaVersion
        self.sectors = sectors
        self.airports = airports
        self.allPositions = allPositions
        self.lastUpdated = lastUpdated
        self.commitSHA = commitSHA
        self.callsignLabels = callsignLabels
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0
        sectors = try container.decode([VatglassesSector].self, forKey: .sectors)
        airports = try container.decodeIfPresent([VatglassesAirport].self, forKey: .airports) ?? []
        allPositions = try container.decode([String: VatglassesPosition].self, forKey: .allPositions)
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
        commitSHA = try container.decode(String.self, forKey: .commitSHA)
        callsignLabels = try container.decodeIfPresent([String: [String: String]].self, forKey: .callsignLabels) ?? [:]
    }
}
