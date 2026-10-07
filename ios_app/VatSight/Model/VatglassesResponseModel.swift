//
//  VatglassesResponseModel.swift
//  VatSight
//

import Foundation
import Turf
import CoreLocation

struct VatglassesComitModel {
    let sha: String
    let commitDate: Date?
}

extension VatglassesComitModel: Decodable {
    private enum CodingKeys: String, CodingKey { case sha, commit }
    private enum CommitKeys: String, CodingKey { case committer }
    private enum CommitterKeys: String, CodingKey { case date }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sha = try container.decode(String.self, forKey: .sha)

        if let commitContainer = try? container.nestedContainer(keyedBy: CommitKeys.self, forKey: .commit),
           let committerContainer = try? commitContainer.nestedContainer(keyedBy: CommitterKeys.self, forKey: .committer),
           let dateString = try? committerContainer.decode(String.self, forKey: .date) {
            let formatter = ISO8601DateFormatter()
            commitDate = formatter.date(from: dateString)
        } else {
            commitDate = nil
        }
    }
}

// MARK: - Position Model

struct VatglassesPosition: Codable {
    let callsign: String
    let frequency: String?       // nil for some positions (e.g. NAT)
    let type: String             // CTR, APP, TWR, GND, DEL, FSS
    let facilityPrefixes: [String]
    let colors: [String]?

    var primaryColorHex: String? { colors?.first }
}

// MARK: - Sector Data Model

struct VatglassesSector: Codable, Identifiable {
    let id: String
    let ownerRefs: [String]  // Ordered list of owner position IDs (hierarchical)
    let frequency: String
    let geometry: SectorGeometry
    let properties: SectorProperties?
    
    var isActive: Bool
    var activeOwnerColorHex: String?
    var activeOwnerRef: String?
    var activeController: Controllers?
    var activeCoControllers: [Controllers] // co-controllers on a shared synthetic circle
    var isBasicDataOnly: Bool // from nodata.json — FIRs without full VATGlasses data
    var isSynthetic: Bool    // dynamically generated circle (5 nm TWR / 20 nm APP/DEP)

    init(id: String, ownerRefs: [String], frequency: String, geometry: SectorGeometry, properties: SectorProperties?, isActive: Bool = false, activeOwnerColorHex: String? = nil, activeOwnerRef: String? = nil, activeController: Controllers? = nil, activeCoControllers: [Controllers] = [], isBasicDataOnly: Bool = false, isSynthetic: Bool = false) {
        self.id = id
        self.ownerRefs = ownerRefs
        self.frequency = frequency
        self.geometry = geometry
        self.properties = properties
        self.isActive = isActive
        self.activeOwnerColorHex = activeOwnerColorHex
        self.activeOwnerRef = activeOwnerRef
        self.activeController = activeController
        self.activeCoControllers = activeCoControllers
        self.isBasicDataOnly = isBasicDataOnly
        self.isSynthetic = isSynthetic
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case ownerRefs
        case frequency
        case geometry
        case properties
        case isBasicDataOnly
        // isSynthetic excluded — regenerated each session, never cached.
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        ownerRefs = try container.decode([String].self, forKey: .ownerRefs)
        frequency = try container.decode(String.self, forKey: .frequency)
        geometry = try container.decode(SectorGeometry.self, forKey: .geometry)
        properties = try container.decodeIfPresent(SectorProperties.self, forKey: .properties)
        isBasicDataOnly = try container.decodeIfPresent(Bool.self, forKey: .isBasicDataOnly) ?? false
        isSynthetic = false
        isActive = false
        activeOwnerColorHex = nil
        activeOwnerRef = nil
        activeController = nil
        activeCoControllers = []
    }
}

struct SectorGeometry: Codable {
    let type: String // "Polygon" or "MultiPolygon"
    let coordinates: [[[[Double]]]] // GeoJSON coordinate format
    
    /// Returns the approximate centroid of the sector geometry by averaging all outer ring coordinates.
    var centroid: CLLocationCoordinate2D? {
        let outerRings: [[Double]] = coordinates.compactMap { $0.first }.flatMap { $0 }
        guard !outerRings.isEmpty else { return nil }
        let validCoords = outerRings.filter { $0.count >= 2 }
        guard !validCoords.isEmpty else { return nil }
        let lat = validCoords.map { $0[1] }.reduce(0, +) / Double(validCoords.count)
        let lon = validCoords.map { $0[0] }.reduce(0, +) / Double(validCoords.count)
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

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
    let callsign: String?       // human-readable name (e.g., "Okecie")
    let ownerRefs: [String]     // hierarchical topdown owner chain
    let runways: [String]
    
    var id: String { icao }
    
    var isActive: Bool = false
    var activeController: Controllers?
    var groundServiceIndicators: String = "" // T=TWR, G=GND, D=DEL, A=ATIS
    
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
    static let currentSchemaVersion = 10 // bump to force re-download on schema changes

    let schemaVersion: Int
    let sectors: [VatglassesSector]
    let airports: [VatglassesAirport]
    let allPositions: [String: VatglassesPosition]
    let lastUpdated: Date
    let commitSHA: String
    let commitDate: Date?
    /// positionType → middleComponent → humanLabel. Keys may be literals or regex patterns.
    let callsignLabels: [String: [String: String]]

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case sectors
        case airports
        case allPositions
        case lastUpdated
        case commitSHA
        case commitDate
        case callsignLabels
    }
    
    init(sectors: [VatglassesSector], airports: [VatglassesAirport], allPositions: [String: VatglassesPosition], lastUpdated: Date, commitSHA: String, commitDate: Date? = nil, callsignLabels: [String: [String: String]] = [:]) {
        self.schemaVersion = Self.currentSchemaVersion
        self.sectors = sectors
        self.airports = airports
        self.allPositions = allPositions
        self.lastUpdated = lastUpdated
        self.commitSHA = commitSHA
        self.commitDate = commitDate
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
        commitDate = try container.decodeIfPresent(Date.self, forKey: .commitDate)
        callsignLabels = try container.decodeIfPresent([String: [String: String]].self, forKey: .callsignLabels) ?? [:]
    }
}
