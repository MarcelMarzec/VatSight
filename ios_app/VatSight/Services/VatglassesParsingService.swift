//
//  VatglassesParsingService.swift
//  VatSight
//

import Foundation
import ZIPFoundation

// MARK: - Parsing
extension VatglassesService {

    func extractAndParseSectors(from zipData: Data) throws -> VatglassesData {
        // Create temporary directory for extraction
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let zipPath = tempDir.appendingPathComponent("vatglasses.zip")
        try zipData.write(to: zipPath)

        let extractPath = tempDir.appendingPathComponent("extracted")
        try FileManager.default.createDirectory(at: extractPath, withIntermediateDirectories: true)
        try FileManager.default.unzipItem(at: zipPath, to: extractPath)

        let (sectors, airports, allPositions, callsignLabels) = try self.parseVatglassesFiles(in: extractPath)

        return VatglassesData(
            sectors: sectors,
            airports: airports,
            allPositions: allPositions,
            lastUpdated: Date(),
            commitSHA: "",
            callsignLabels: callsignLabels
        )
    }

    func parseVatglassesFiles(in directory: URL) throws -> ([VatglassesSector], [VatglassesAirport], [String: VatglassesPosition], [String: [String: String]]) {
        var sectors: [VatglassesSector] = []
        var airports: [VatglassesAirport] = []
        var allPositions: [String: VatglassesPosition] = [:]
        var mergedCallsignLabels: [String: [String: String]] = [:]

        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: nil)

        // Categorise JSON files: standalone (Type 2: data/ed.json) vs subdirectory (Type 1: data/zoa/airspace.json)
        var dataDirectories: Set<URL> = []
        var standaloneFiles: [URL] = []
        var nodataFileURL: URL? = nil

        while let fileURL = enumerator?.nextObject() as? URL {
            guard fileURL.pathExtension == "json",
                  fileURL.path.contains("/data/"),
                  !fileURL.path.contains("/ownership/") else {
                continue
            }

            // nodata.json is handled separately — its "owner" strings are raw FIR
            // identifiers, not position keys, so it needs its own parsing path.
            if fileURL.lastPathComponent == "nodata.json" {
                nodataFileURL = fileURL
                continue
            }

            let pathComponents = fileURL.pathComponents
            if let dataIndex = pathComponents.lastIndex(of: "data") {
                let componentsAfterData = pathComponents.suffix(from: dataIndex + 1)
                if componentsAfterData.count == 1 {
                    standaloneFiles.append(fileURL)
                } else if componentsAfterData.count == 2 {
                    dataDirectories.insert(fileURL.deletingLastPathComponent())
                }
            }
        }

        // Process Type 1 directories (airspace.json + positions.json + ownership/)
        for directoryURL in dataDirectories {
            do {
                let directoryName = directoryURL.lastPathComponent
                let (parsedSectors, parsedAirports, positions, callsignLabels) = try parseType1Directory(directoryURL)
                sectors.append(contentsOf: parsedSectors)
                airports.append(contentsOf: parsedAirports)
                // Store positions only under their scoped key to prevent cross-FIR collisions.
                // ownerRefs in sectors are already prefixed at parse time.
                for (posKey, position) in positions {
                    allPositions["\(directoryName)/\(posKey)"] = position
                }
                // Merge callsign labels (later files may override earlier ones for the same type+middle).
                for (type, middleMap) in callsignLabels {
                    for (middle, label) in middleMap {
                        mergedCallsignLabels[type, default: [:]][middle] = label
                    }
                }
            } catch {
                let msg = error.localizedDescription
                print("Failed to parse directory \(directoryURL.lastPathComponent): \(msg)")
                parseErrors.append(VatglassesParseError(source: directoryURL.lastPathComponent, message: msg, date: Date()))
            }
        }

        // Process Type 2 standalone files (combined JSON)
        for fileURL in standaloneFiles {
            do {
                let data = try Data(contentsOf: fileURL)
                let filePrefix = fileURL.deletingPathExtension().lastPathComponent
                let (parsedSectors, parsedAirports, positions, callsignLabels) = try parseType2File(data: data, filename: fileURL.lastPathComponent)
                sectors.append(contentsOf: parsedSectors)
                airports.append(contentsOf: parsedAirports)
                // Store positions only under their scoped key to prevent cross-FIR collisions.
                for (posKey, position) in positions {
                    allPositions["\(filePrefix)/\(posKey)"] = position
                }
                // Merge callsign labels.
                for (type, middleMap) in callsignLabels {
                    for (middle, label) in middleMap {
                        mergedCallsignLabels[type, default: [:]][middle] = label
                    }
                }
            } catch {
                let msg = error.localizedDescription
                print("Failed to parse file \(fileURL.lastPathComponent): \(msg)")
                parseErrors.append(VatglassesParseError(source: fileURL.lastPathComponent, message: msg, date: Date()))
            }
        }

        // Process nodata.json — basic-data-only FIR sectors for unimplemented regions.
        // Also extracts positions, airports, and callsign labels from the full schema.
        if let nodataURL = nodataFileURL,
           let nodataData = try? Data(contentsOf: nodataURL) {
            let (nodataSectors, nodataAirports, nodataPositions, nodataCallsigns) = parseNodataFile(data: nodataData)
            sectors.append(contentsOf: nodataSectors)
            airports.append(contentsOf: nodataAirports)
            // Scope nodata positions under "nodata/" prefix to avoid collisions.
            for (posKey, position) in nodataPositions {
                allPositions["nodata/\(posKey)"] = position
            }
            // Merge callsign labels from nodata.json.
            for (type, middleMap) in nodataCallsigns {
                for (middle, label) in middleMap {
                    mergedCallsignLabels[type, default: [:]][middle] = label
                }
            }
        }

        return (sectors, airports, allPositions, mergedCallsignLabels)
    }

    /// Parses a Type 1 directory containing `airspace.json`, optional `positions.json`, and optional `ownership/`.
    func parseType1Directory(_ directoryURL: URL) throws -> ([VatglassesSector], [VatglassesAirport], [String: VatglassesPosition], [String: [String: String]]) {
        let fileManager = FileManager.default

        let positionsURL = directoryURL.appendingPathComponent("positions.json")
        var positions: [String: VatglassesPosition] = [:]
        var callsignLabels: [String: [String: String]] = [:]
        if fileManager.fileExists(atPath: positionsURL.path) {
            let positionsData = try Data(contentsOf: positionsURL)
            (positions, callsignLabels) = try parsePositionsJSON(data: positionsData)
        }

        let airspaceURL = directoryURL.appendingPathComponent("airspace.json")
        guard fileManager.fileExists(atPath: airspaceURL.path) else {
            throw NSError(domain: "VatglassesService", code: -2,
                         userInfo: [NSLocalizedDescriptionKey: "Missing airspace.json in \(directoryURL.lastPathComponent)"])
        }
        let airspaceData = try Data(contentsOf: airspaceURL)

        // Also check airspace.json for a top-level "callsigns" key (some Type 1 regions put it there)
        if let airspaceJSON = try? JSONSerialization.jsonObject(with: airspaceData) as? [String: Any],
           let airspaceCallsigns = airspaceJSON["callsigns"] as? [String: [String: String]] {
            for (type, middleMap) in airspaceCallsigns {
                for (middle, label) in middleMap {
                    callsignLabels[type, default: [:]][middle] = label
                }
            }
        }

        var ownershipMap: [String: [String]] = [:]
        var airportOwnership: [String: [String]] = [:]
        let defaultOwnershipURL = directoryURL.appendingPathComponent("ownership/default.json")
        if fileManager.fileExists(atPath: defaultOwnershipURL.path) {
            let ownershipData = try Data(contentsOf: defaultOwnershipURL)
            (ownershipMap, airportOwnership) = try parseOwnershipJSON(data: ownershipData)
        }

        // Parse groups map from airspace.json if present
        let groupNames = parseGroupNames(from: airspaceData)

        let sectors = try parseAirspaceJSON(
            data: airspaceData,
            ownershipMap: ownershipMap,
            positions: positions,
            regionPrefix: directoryURL.lastPathComponent,
            groupNames: groupNames
        )
        let airports = parseType1Airports(from: airspaceData, airportOwnership: airportOwnership)

        return (sectors, airports, positions, callsignLabels)
    }

    /// Parses a Type 2 combined file (e.g., `data/ed.json`) containing airspace, positions, and ownership.
    func parseType2File(data: Data, filename: String) throws -> ([VatglassesSector], [VatglassesAirport], [String: VatglassesPosition], [String: [String: String]]) {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "VatglassesService", code: -3,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid JSON in \(filename)"])
        }

        // Extract region prefix from filename (e.g., "ed.json" -> "ed")
        let regionPrefix = filename.replacingOccurrences(of: ".json", with: "")

        // Parse top-level "callsigns" key if present.
        let callsignLabels = json["callsigns"] as? [String: [String: String]] ?? [:]

        // Parse groups map (key -> human name), stripping any HTML tags (e.g. <br/>).
        var groupNames: [String: String] = [:]
        if let groupsJSON = json["groups"] as? [String: [String: Any]] {
            for (key, value) in groupsJSON {
                if let name = value["name"] as? String {
                    groupNames[key] = stripHTML(name)
                }
            }
        }

        // Parse positions
        let positionsJSON = json["positions"] as? [String: [String: Any]] ?? [:]
        var positions: [String: VatglassesPosition] = [:]

        for (posKey, posData) in positionsJSON {
            guard let callsign = posData["callsign"] as? String,
                  let type = posData["type"] as? String else {
                continue
            }

            // "pre" may be a bare string or an array depending on the file format.
            let facilityPrefixes = parseFacilityPrefixes(posData["pre"])

            var colors: [String]? = nil
            if let coloursArray = posData["colours"] as? [[String: Any]] {
                colors = coloursArray.compactMap { $0["hex"] as? String }
            }

            positions[posKey] = VatglassesPosition(
                callsign: callsign,
                frequency: posData["frequency"] as? String,
                type: type,
                facilityPrefixes: facilityPrefixes,
                colors: colors
            )
        }

        // Parse airspace
        guard let airspaceArray = json["airspace"] as? [[String: Any]] else {
            // No airspace data, but parse airports if present
            var airports: [VatglassesAirport] = []
            if let airportsJSON = json["airports"] as? [String: Any] {
                airports = createAirportsFromRichJSON(airportsJSON)
            }
            return ([], airports, positions, callsignLabels)
        }

        var sectors: [VatglassesSector] = []

        for airspace in airspaceArray {
            guard let id = airspace["id"] as? String,
                  let owner = airspace["owner"] as? [String],
                  let sectorData = airspace["sectors"] as? [[String: Any]] else {
                continue
            }

            // Scope plain ownerRefs to this region; cross-file refs (e.g. "fss/EUCME") are kept as-is.
            let scopedOwner = owner.map { scopedOwnerRef($0, regionPrefix: regionPrefix) }

            // Get frequency from first position if available
            let firstOwner = owner.first ?? ""
            let frequency = positions[firstOwner]?.frequency ?? "Unknown"

            // Each airspace can have multiple altitude sectors
            for (index, sector) in sectorData.enumerated() {
                guard let points = sector["points"] as? [[String]],
                      !points.isEmpty else {
                    continue
                }

                let min = sector["min"] as? Int ?? 0
                let max = sector["max"] as? Int ?? 999

                let coordinates = convertVatglassesCoordinates(points)

                let geometry = SectorGeometry(
                    type: "Polygon",
                    coordinates: [[coordinates]]
                )

                let groupKey = airspace["group"] as? String
                let properties = SectorProperties(
                    min: min,
                    max: max,
                    name: airspace["id"] as? String ?? id,
                    groupName: groupKey.flatMap { groupNames[$0] } ?? groupKey,
                    color: nil
                )

                // Create globally unique sector ID with region prefix
                let baseSectorId = sectorData.count > 1 ? "\(id)_\(index)" : id
                let sectorId = "\(regionPrefix)/\(baseSectorId)"

                let vatglassesSector = VatglassesSector(
                    id: sectorId,
                    ownerRefs: scopedOwner,
                    frequency: frequency,
                    geometry: geometry,
                    properties: properties,
                    isActive: false
                )

                sectors.append(vatglassesSector)
            }
        }

        // Parse airports if present
        var airports: [VatglassesAirport] = []
        if let airportsJSON = json["airports"] as? [String: Any] {
            airports = createAirportsFromRichJSON(airportsJSON)
        }

        return (sectors, airports, positions, callsignLabels)
    }

    /// Parses `data/nodata.json` according to the full schema:
    /// - `airspace`: FIR outlines tagged `isBasicDataOnly = true`; owners are ICAO facility IDs.
    /// - `positions`: controller position definitions keyed by facility ID (e.g. `"KZBW"`).
    /// - `airports`: airport reference data with decimal-degree coords.
    /// - `callsigns`: position-type → middle-component → label lookup table.
    /// - `groups`: group key → display name, resolved into sector `groupName` properties.
    ///
    /// Returns `(sectors, airports, positions, callsignLabels)` using `"nodata"` as the
    /// region prefix so all keys are globally unique.
    func parseNodataFile(data: Data) -> ([VatglassesSector], [VatglassesAirport], [String: VatglassesPosition], [String: [String: String]]) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ([], [], [:], [:])
        }

        // MARK: groups — strip HTML tags (e.g. <br/>) from display names.
        var groupNames: [String: String] = [:]
        if let groupsJSON = json["groups"] as? [String: [String: Any]] {
            for (key, value) in groupsJSON {
                if let name = value["name"] as? String {
                    groupNames[key] = stripHTML(name)
                }
            }
        }

        // MARK: callsigns
        let callsignLabels = json["callsigns"] as? [String: [String: String]] ?? [:]

        // MARK: positions
        var positions: [String: VatglassesPosition] = [:]
        if let positionsJSON = json["positions"] as? [String: [String: Any]] {
            for (posKey, posData) in positionsJSON {
                guard let callsign = posData["callsign"] as? String,
                      let type = posData["type"] as? String else { continue }

                let facilityPrefixes = parseFacilityPrefixes(posData["pre"])

                var colors: [String]? = nil
                if let coloursArray = posData["colours"] as? [[String: Any]] {
                    colors = coloursArray.compactMap { $0["hex"] as? String }
                }

                positions[posKey] = VatglassesPosition(
                    callsign: callsign,
                    frequency: posData["frequency"] as? String,
                    type: type,
                    facilityPrefixes: facilityPrefixes,
                    colors: colors
                )
            }
        }

        // MARK: airports
        var airports: [VatglassesAirport] = []
        if let airportsJSON = json["airports"] as? [String: [String: Any]] {
            for (icao, airportData) in airportsJSON {
                guard let coordRaw = airportData["coord"],
                      let (lat, lon) = parseCoord(coordRaw) else { continue }

                // topdown refs in nodata.json are facility IDs — scope them under "nodata/"
                let rawTopdown: [String]
                if let td = airportData["topdown"] as? [String] {
                    rawTopdown = td
                } else {
                    rawTopdown = parseFacilityPrefixes(airportData["pre"])
                }
                let ownerRefs = rawTopdown.map { "nodata/\($0)" }

                airports.append(VatglassesAirport(
                    icao: icao,
                    latitude: lat,
                    longitude: lon,
                    callsign: airportData["callsign"] as? String,
                    ownerRefs: ownerRefs
                ))
            }
        }

        // MARK: airspace / sectors
        guard let airspaceArray = json["airspace"] as? [[String: Any]] else {
            return ([], airports, positions, callsignLabels)
        }

        var sectors: [VatglassesSector] = []

        for airspace in airspaceArray {
            guard let id = airspace["id"] as? String,
                  let sectorData = airspace["sectors"] as? [[String: Any]] else { continue }

            // owner is an array of facility-ID strings per the schema.
            var ownerRefs: [String] = []
            if let ownerArray = airspace["owner"] as? [String] {
                // Split any comma-separated entries (legacy format)
                ownerRefs = ownerArray.flatMap { $0.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
            } else if let ownerString = airspace["owner"] as? String {
                ownerRefs = ownerString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            }

            let groupKey = airspace["group"] as? String

            for (index, sector) in sectorData.enumerated() {
                guard let points = sector["points"] as? [[String]], !points.isEmpty else { continue }

                let coordinates = convertVatglassesCoordinates(points)
                guard !coordinates.isEmpty else { continue }

                let geometry = SectorGeometry(
                    type: "Polygon",
                    coordinates: [[coordinates]]
                )

                let properties = SectorProperties(
                    min: sector["min"] as? Int,
                    max: sector["max"] as? Int,
                    name: id,
                    groupName: groupKey.flatMap { groupNames[$0] } ?? groupKey,
                    color: nil
                )

                let baseSectorId = sectorData.count > 1 ? "\(id)_\(index)" : id
                sectors.append(VatglassesSector(
                    id: "nodata/\(baseSectorId)",
                    ownerRefs: ownerRefs,   // raw FIR identifiers, matched by prefix at activation time
                    frequency: "Unknown",
                    geometry: geometry,
                    properties: properties,
                    isActive: false,
                    isBasicDataOnly: true
                ))
            }
        }

        return (sectors, airports, positions, callsignLabels)
    }

    func parsePositionsJSON(data: Data) throws -> ([String: VatglassesPosition], [String: [String: String]]) {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "VatglassesService", code: -4,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid positions.json format - not a JSON object"])
        }

        // Parse top-level "callsigns" key if present.
        let callsignLabels = json["callsigns"] as? [String: [String: String]] ?? [:]

        // Supports two formats: wrapped (`{ "positions": {...} }`) or direct (`{ "SNE": {...} }`)
        let positionsJSON: [String: [String: Any]]

        if let wrappedPositions = json["positions"] as? [String: [String: Any]] {
            positionsJSON = wrappedPositions
        } else if let directPositions = json as? [String: [String: Any]] {
            positionsJSON = directPositions.filter { _, value in
                value["frequency"] != nil || value["callsign"] != nil
            }
        } else {
            throw NSError(domain: "VatglassesService", code: -4,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid positions.json format - positions not found"])
        }

        var positions: [String: VatglassesPosition] = [:]

        for (posKey, posData) in positionsJSON {
            guard let callsign = posData["callsign"] as? String,
                  let type = posData["type"] as? String else {
                continue
            }

            // "pre" may be a bare string ("TOR") or an array (["TOR", "YYZ"]) depending on the file format.
            let facilityPrefixes = parseFacilityPrefixes(posData["pre"])

            var colors: [String]? = nil
            if let coloursArray = posData["colours"] as? [[String: Any]] {
                colors = coloursArray.compactMap { $0["hex"] as? String }
            }

            positions[posKey] = VatglassesPosition(
                callsign: callsign,
                frequency: posData["frequency"] as? String,
                type: type,
                facilityPrefixes: facilityPrefixes,
                colors: colors
            )
        }

        return (positions, callsignLabels)
    }

    /// Parses the "groups" dictionary from airspace data, returning a map of group key → human name.
    func parseGroupNames(from data: Data) -> [String: String] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let groupsJSON = json["groups"] as? [String: [String: Any]] else { return [:] }
        return groupsJSON.compactMapValues { ($0["name"] as? String).map { stripHTML($0) } }
    }

    /// Replaces HTML line-break tags with ". " and strips any remaining HTML tags.
    func stripHTML(_ raw: String) -> String {
        raw.replacingOccurrences(of: "<br\\s*/?>", with: ". ", options: .regularExpression)
           .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
           .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Parses the "pre" field from a position entry, which may be a bare String or an [String] array.
    func parseFacilityPrefixes(_ raw: Any?) -> [String] {
        if let array = raw as? [String] { return array }
        if let single = raw as? String { return [single] }
        return []
    }

    func parseAirspaceJSON(
        data: Data,
        ownershipMap: [String: [String]],
        positions: [String: VatglassesPosition],
        regionPrefix: String,
        groupNames: [String: String] = [:]
    ) throws -> [VatglassesSector] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "VatglassesService", code: -5,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid airspace.json format - not a JSON object"])
        }

        // Supports two formats: wrapped object or direct array
        var airspaceArray: [[String: Any]] = []

        if let wrappedAirspace = json["airspace"] as? [String: [String: Any]] {
            for (airspaceID, airspaceData) in wrappedAirspace {
                var converted = airspaceData
                if converted["id"] == nil { converted["id"] = airspaceID }
                converted["_key"] = airspaceID
                airspaceArray.append(converted)
            }
        } else if let directArray = json["airspace"] as? [[String: Any]] {
            airspaceArray = directArray
        } else {
            throw NSError(domain: "VatglassesService", code: -5,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid airspace.json format - expected array or wrapped object"])
        }

        var sectors: [VatglassesSector] = []

        for airspace in airspaceArray {
            let id: String
            if let idValue = airspace["id"] as? String {
                id = idValue
            } else if let keyValue = airspace["_key"] as? String {
                id = keyValue
            } else {
                continue
            }

            guard let sectorData = airspace["sectors"] as? [[String: Any]] else { continue }

            // Prefer ownership map; fall back to inline owner field
            var rawOwner: [String] = []
            if let mappedOwner = ownershipMap[id] {
                rawOwner = mappedOwner
            } else if let keyValue = airspace["_key"] as? String, let mappedOwner = ownershipMap[keyValue] {
                rawOwner = mappedOwner
            } else if let airspaceOwner = airspace["owner"] as? [String] {
                rawOwner = airspaceOwner
            }

            // Scope plain ownerRefs to this region; cross-file refs (e.g. "fss/EUCME") are kept as-is.
            let owner = rawOwner.map { scopedOwnerRef($0, regionPrefix: regionPrefix) }

            let frequency = positions[rawOwner.first ?? ""]?.frequency ?? "Unknown"

            for (index, sector) in sectorData.enumerated() {
                guard let points = sector["points"] as? [[String]], !points.isEmpty else { continue }

                let geometry = SectorGeometry(
                    type: "Polygon",
                    coordinates: [[convertVatglassesCoordinates(points)]]
                )
                let groupKey = airspace["group"] as? String
                let properties = SectorProperties(
                    min: sector["min"] as? Int ?? 0,
                    max: sector["max"] as? Int ?? 999,
                    name: airspace["id"] as? String ?? id,
                    groupName: groupKey.flatMap { groupNames[$0] } ?? groupKey,
                    color: nil
                )
                let baseSectorId = sectorData.count > 1 ? "\(id)_\(index)" : id
                let vatglassesSector = VatglassesSector(
                    id: "\(regionPrefix)/\(baseSectorId)",
                    ownerRefs: owner,
                    frequency: frequency,
                    geometry: geometry,
                    properties: properties,
                    isActive: false
                )
                sectors.append(vatglassesSector)
            }
        }

        return sectors
    }

    func parseOwnershipJSON(data: Data) throws -> ([String: [String]], [String: [String]]) {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "VatglassesService", code: -6,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid ownership JSON format"])
        }

        let airspaceOwnership = json["airspace"] as? [String: [String]] ?? [:]
        let airportOwnership = json["airports"] as? [String: [String]] ?? [:]

        return (airspaceOwnership, airportOwnership)
    }

    func createAirportsFromRichJSON(_ airportsJSON: [String: Any]) -> [VatglassesAirport] {
        return airportsJSON.compactMap { icao, value in
            guard let airportData = value as? [String: Any],
                  let (lat, lon) = parseCoord(airportData["coord"] as Any) else {
                return nil
            }
            return VatglassesAirport(
                icao: icao,
                latitude: lat,
                longitude: lon,
                callsign: airportData["callsign"] as? String,
                ownerRefs: resolveOwnerRefs(icao: icao, airportData: airportData, airportOwnership: [:]),
                runways: airportData["runways"] as? [String] ?? []
            )
        }
    }

    func parseType1Airports(from airspaceData: Data, airportOwnership: [String: [String]]) -> [VatglassesAirport] {
        guard let json = try? JSONSerialization.jsonObject(with: airspaceData) as? [String: Any],
              let airportsJSON = json["airports"] as? [String: Any] else {
            return []
        }

        return airportsJSON.compactMap { icao, value in
            guard let airportData = value as? [String: Any],
                  let (lat, lon) = parseCoord(airportData["coord"] as Any) else {
                return nil
            }
            return VatglassesAirport(
                icao: icao,
                latitude: lat,
                longitude: lon,
                callsign: airportData["callsign"] as? String,
                ownerRefs: resolveOwnerRefs(icao: icao, airportData: airportData, airportOwnership: airportOwnership),
                runways: airportData["runways"] as? [String] ?? []
            )
        }
    }

    /// Returns ownerRefs for an airport, preferring the ownership file over inline keys.
    func resolveOwnerRefs(icao: String, airportData: [String: Any], airportOwnership: [String: [String]]) -> [String] {
        if let refs = airportOwnership[icao] { return refs }
        if let refs = airportData["topdown"] as? [String] { return refs }
        if let refs = airportData["pre"] as? [String] { return refs }
        if let ref = airportData["pre"] as? String { return [ref] }
        return []
    }
}
