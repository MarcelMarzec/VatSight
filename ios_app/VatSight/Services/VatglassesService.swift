//
//  VatglassesService.swift
//  VatSight
//
//  Created by Marcel Marzec on 03/06/2026.
//
import Foundation
import ZIPFoundation
internal import _LocationEssentials

final class VatglassesService {
    
    private let commitURL = URL(string: "https://api.github.com/repos/lennycolton/vatglasses-data/commits/main")!
    private let repoURL = URL(string: "https://api.github.com/repos/lennycolton/vatglasses-data/zipball/main")!

    /// Cache of compiled NSRegularExpression objects keyed by pattern string.
    /// Avoids recompiling the same regex on every resolvePositionLabel call.
    private var regexCache: [String: NSRegularExpression] = [:]
    
    private var cachedData: VatglassesData?
    private var lastFetchDate: Date?
    
    // MARK: - Persistent Storage
    private let cacheFileURL: URL = {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("vatglasses_cache.json")
    }()
    
    init() {
        loadCachedDataFromDisk()
    }
    
    // MARK: - Public API
    
    /// Fetches Vatglasses sector data from GitHub.
    /// Returns cached data immediately if available, then checks for updates in the background.
    func fetchSectorData(completion: @escaping (Result<VatglassesData, Error>) -> Void) {
        if let cached = cachedData {
            completion(.success(cached))
        }

        fetchCommitInfo { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let commitModel):
                if let cached = self.cachedData, cached.commitSHA == commitModel.sha {
                    return
                }
                self.downloadAndParseSectors(commitSHA: commitModel.sha, completion: completion)

            case .failure(let error):
                if self.cachedData == nil {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Returns cached sector data if available
    func getCachedSectors() -> [VatglassesSector] {
        cachedData?.sectors ?? []
    }

    /// Returns all known positions from the cached vatglasses data.
    func getCachedPositions() -> [String: VatglassesPosition] {
        cachedData?.allPositions ?? [:]
    }
    
    /// Clears all cached data (both in-memory and on disk).
    func clearCache() {
        cachedData = nil
        lastFetchDate = nil

        if FileManager.default.fileExists(atPath: cacheFileURL.path) {
            try? FileManager.default.removeItem(at: cacheFileURL)
        }
    }
    
    /// Returns sectors with active controller status based on online VATSIM controllers.
    func getActiveSectors(controllers: [Controllers]) -> [VatglassesSector] {
        guard var sectors = cachedData?.sectors,
              let allPositions = cachedData?.allPositions else { return [] }

        let frequencyGroupedControllers = buildFrequencyGroupedControllers(from: controllers)
        var positionActiveCache: [String: (isActive: Bool, controller: Controllers?)] = [:]

        for i in sectors.indices {
            if let (activeOwnerRef, matchingController) = findActiveOwnerWithController(
                for: sectors[i],
                allPositions: allPositions,
                frequencyGroupedControllers: frequencyGroupedControllers,
                positionActiveCache: &positionActiveCache
            ) {
                sectors[i].isActive = true
                sectors[i].activeOwnerRef = activeOwnerRef
                sectors[i].activeController = matchingController
                sectors[i].activeOwnerColorHex = allPositions[activeOwnerRef]?.primaryColorHex
            } else {
                sectors[i].isActive = false
                sectors[i].activeOwnerRef = nil
                sectors[i].activeController = nil
                sectors[i].activeOwnerColorHex = nil
            }
        }

        return sectors
    }
    
    // MARK: - Hierarchical Ownership Matching

    /// Scopes a raw ownerRef to a specific FIR region, unless it already contains a cross-file
    /// prefix (e.g. "fss/EUCME" is returned as-is; "CT" becomes "regionPrefix/CT").
    private func scopedOwnerRef(_ ref: String, regionPrefix: String) -> String {
        return ref.contains("/") ? ref : "\(regionPrefix)/\(ref)"
    }

    /// Normalises a frequency string to a canonical form for comparison.
    /// Strips trailing zeros after the decimal point, but keeps at least one decimal digit.
    /// e.g. "119.900" -> "119.9", "120.500" -> "120.5", "121.000" -> "121.0"
    private func normaliseFrequency(_ raw: String) -> String {
        guard let value = Double(raw) else { return raw }
        // Format with up to 3 decimal places then strip trailing zeros
        var formatted = String(format: "%.3f", value)
        // Find the last non-zero character after the decimal, stopping before ".0"
        while formatted.hasSuffix("0") && !formatted.hasSuffix(".0") {
            formatted.removeLast()
        }
        return formatted
    }

    /// Groups controllers by normalised frequency for efficient lookup during sector matching.
    private func buildFrequencyGroupedControllers(from controllers: [Controllers]) -> [String: [Controllers]] {
        var grouped: [String: [Controllers]] = [:]
        
        for controller in controllers {
            let key = normaliseFrequency(controller.frequency)
            grouped[key, default: []].append(controller)
        }
        
        return grouped
    }
    
    /// Walks the hierarchical ownership chain for a sector and returns the first active owner.
    private func findActiveOwnerWithController(
        for sector: VatglassesSector,
        allPositions: [String: VatglassesPosition],
        frequencyGroupedControllers: [String: [Controllers]],
        positionActiveCache: inout [String: (isActive: Bool, controller: Controllers?)]
    ) -> (ownerRef: String, controller: Controllers)? {
        for ownerRef in sector.ownerRefs {
            if let cached = positionActiveCache[ownerRef] {
                if cached.isActive, let controller = cached.controller {
                    return (ownerRef, controller)
                }
                continue
            }

            // All ownerRefs are scoped at parse time (e.g. "soca/CA", "fss/EUCME"),
            // so the lookup is always a direct key match.
            let position = allPositions[ownerRef]

            guard let pos = position else {
                positionActiveCache[ownerRef] = (isActive: false, controller: nil)
                continue
            }

            if let matchingController = findMatchingController(
                position: pos,
                frequencyGroupedControllers: frequencyGroupedControllers
            ) {
                positionActiveCache[ownerRef] = (isActive: true, controller: matchingController)
                return (ownerRef, matchingController)
            } else {
                positionActiveCache[ownerRef] = (isActive: false, controller: nil)
            }
        }

        return nil
    }
    
    /// Returns the first controller whose callsign matches the given position, or nil if none match.
    private func findMatchingController(
        position: VatglassesPosition,
        frequencyGroupedControllers: [String: [Controllers]]
    ) -> Controllers? {
        let normalisedFrequency = normaliseFrequency(position.frequency)
        guard let controllersOnFrequency = frequencyGroupedControllers[normalisedFrequency] else {
            return nil
        }

        return controllersOnFrequency.first {
            matchesCallsignPattern(controller: $0, position: position)
        }
    }
    
    /// Returns true if the controller's callsign matches the position's facility prefix and type.
    /// Supports two patterns: `FACILITY_TYPE` and `FACILITY_MIDDLE_TYPE` (e.g. SOCA_N_APP).
    private func matchesCallsignPattern(
        controller: Controllers,
        position: VatglassesPosition
    ) -> Bool {
        let controllerCallsign = controller.callsign
        let posType = position.type

        guard controllerCallsign.hasSuffix(posType) else { return false }

        for facilityPrefix in position.facilityPrefixes {
            guard controllerCallsign.hasPrefix(facilityPrefix) else { continue }

            let facilityLength = facilityPrefix.count
            let typeLength = posType.count
            let callsignLength = controllerCallsign.count

            // FACILITY_TYPE (e.g. SOCA_APP)
            if callsignLength == facilityLength + 1 + typeLength {
                let index = controllerCallsign.index(controllerCallsign.startIndex, offsetBy: facilityLength)
                if controllerCallsign[index] == "_" { return true }
            }

            // FACILITY_MIDDLE_TYPE (e.g. SOCA_N_APP, SOCA_JR_APP)
            if callsignLength > facilityLength + 1 + typeLength {
                let afterFacility = controllerCallsign.index(controllerCallsign.startIndex, offsetBy: facilityLength)
                let beforeType = controllerCallsign.index(controllerCallsign.endIndex, offsetBy: -typeLength - 1)
                if controllerCallsign[afterFacility] == "_" && controllerCallsign[beforeType] == "_" { return true }
            }
        }

        return false
    }
    
    // MARK: - Persistent Cache Methods
    
    private func loadCachedDataFromDisk() {
        guard FileManager.default.fileExists(atPath: cacheFileURL.path) else { return }

        do {
            let data = try Data(contentsOf: cacheFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode(VatglassesData.self, from: data)
            guard decoded.schemaVersion == VatglassesData.currentSchemaVersion else {
                print("Vatglasses cache schema version \(decoded.schemaVersion) is outdated (current: \(VatglassesData.currentSchemaVersion)), discarding.")
                try? FileManager.default.removeItem(at: cacheFileURL)
                return
            }
            cachedData = decoded
        } catch {
            print("Failed to load cached Vatglasses data: \(error)")
            try? FileManager.default.removeItem(at: cacheFileURL)
        }
    }

    private func saveCachedDataToDisk() {
        guard let dataToSave = cachedData else { return }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(dataToSave)
            try data.write(to: cacheFileURL, options: .atomic)
        } catch {
            print("Failed to save Vatglasses cache: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func fetchCommitInfo(completion: @escaping (Result<VatglassesComitModel, Error>) -> Void) {
        let task = URLSession.shared.dataTask(with: commitURL) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "VatglassesService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data from commit endpoint"])))
                return
            }
            
            do {
                let commitModel = try JSONDecoder().decode(VatglassesComitModel.self, from: data)
                completion(.success(commitModel))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
    
    private func downloadAndParseSectors(commitSHA: String, completion: @escaping (Result<VatglassesData, Error>) -> Void) {
        let task = URLSession.shared.dataTask(with: repoURL) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let zipData = data else {
                completion(.failure(NSError(domain: "VatglassesService", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data from repo endpoint"])))
                return
            }
            
            do {
                var vatglassesData = try self.extractAndParseSectors(from: zipData)
                vatglassesData = VatglassesData(
                    sectors: vatglassesData.sectors,
                    airports: vatglassesData.airports,
                    allPositions: vatglassesData.allPositions,
                    lastUpdated: Date(),
                    commitSHA: commitSHA,
                    callsignLabels: vatglassesData.callsignLabels
                )
                
                self.cachedData = vatglassesData
                self.lastFetchDate = Date()
                self.saveCachedDataToDisk()
                
                completion(.success(vatglassesData))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
    
    private func extractAndParseSectors(from zipData: Data) throws -> VatglassesData {
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
    
    private func parseVatglassesFiles(in directory: URL) throws -> ([VatglassesSector], [VatglassesAirport], [String: VatglassesPosition], [String: [String: String]]) {
        var sectors: [VatglassesSector] = []
        var airports: [VatglassesAirport] = []
        var allPositions: [String: VatglassesPosition] = [:]
        var mergedCallsignLabels: [String: [String: String]] = [:]
        
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: nil)
        
        // Categorise JSON files: standalone (Type 2: data/ed.json) vs subdirectory (Type 1: data/zoa/airspace.json)
        var dataDirectories: Set<URL> = []
        var standaloneFiles: [URL] = []

        while let fileURL = enumerator?.nextObject() as? URL {
            guard fileURL.pathExtension == "json",
                  fileURL.path.contains("/data/"),
                  !fileURL.path.contains("/ownership/") else {
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
                print("Failed to parse directory \(directoryURL.lastPathComponent): \(error.localizedDescription)")
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
                print("Failed to parse file \(fileURL.lastPathComponent): \(error.localizedDescription)")
            }
        }
        
        return (sectors, airports, allPositions, mergedCallsignLabels)
    }
    
    /// Parses a Type 1 directory containing `airspace.json`, optional `positions.json`, and optional `ownership/`.
    private func parseType1Directory(_ directoryURL: URL) throws -> ([VatglassesSector], [VatglassesAirport], [String: VatglassesPosition], [String: [String: String]]) {
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
    private func parseType2File(data: Data, filename: String) throws -> ([VatglassesSector], [VatglassesAirport], [String: VatglassesPosition], [String: [String: String]]) {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "VatglassesService", code: -3,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid JSON in \(filename)"])
        }
        
        // Extract region prefix from filename (e.g., "ed.json" -> "ed")
        let regionPrefix = filename.replacingOccurrences(of: ".json", with: "")

        // Parse top-level "callsigns" key if present.
        let callsignLabels = json["callsigns"] as? [String: [String: String]] ?? [:]

        // Parse groups map (key -> human name)
        var groupNames: [String: String] = [:]
        if let groupsJSON = json["groups"] as? [String: [String: Any]] {
            for (key, value) in groupsJSON {
                if let name = value["name"] as? String {
                    groupNames[key] = name
                }
            }
        }

        // Parse positions
        let positionsJSON = json["positions"] as? [String: [String: Any]] ?? [:]
        var positions: [String: VatglassesPosition] = [:]
        
        for (posKey, posData) in positionsJSON {
            guard let callsign = posData["callsign"] as? String,
                  let frequency = posData["frequency"] as? String,
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
                frequency: frequency,
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

    private func parsePositionsJSON(data: Data) throws -> ([String: VatglassesPosition], [String: [String: String]]) {
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
                  let frequency = posData["frequency"] as? String,
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
                frequency: frequency,
                type: type,
                facilityPrefixes: facilityPrefixes,
                colors: colors
            )
        }
        
        return (positions, callsignLabels)
    }

    /// Parses the "groups" dictionary from airspace data, returning a map of group key → human name.
    private func parseGroupNames(from data: Data) -> [String: String] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let groupsJSON = json["groups"] as? [String: [String: Any]] else { return [:] }
        return groupsJSON.compactMapValues { $0["name"] as? String }
    }

    /// Parses the "pre" field from a position entry, which may be a bare String or an [String] array.
    private func parseFacilityPrefixes(_ raw: Any?) -> [String] {
        if let array = raw as? [String] { return array }
        if let single = raw as? String { return [single] }
        return []
    }
    
    private func parseAirspaceJSON(
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
    
    /// Parses a coordinate pair that may contain either `Double` or `String` values.
    private func parseCoord(_ raw: Any) -> (latitude: Double, longitude: Double)? {
        if let doubles = raw as? [Double], doubles.count == 2 {
            return (doubles[0], doubles[1])
        }
        if let mixed = raw as? [Any], mixed.count == 2 {
            let vals = mixed.compactMap { v -> Double? in
                if let d = v as? Double { return d }
                if let s = v as? String { return Double(s) }
                return nil
            }
            if vals.count == 2 { return (vals[0], vals[1]) }
        }
        return nil
    }

    /// Returns ownerRefs for an airport, preferring the ownership file over inline keys.
    private func resolveOwnerRefs(icao: String, airportData: [String: Any], airportOwnership: [String: [String]]) -> [String] {
        if let refs = airportOwnership[icao] { return refs }
        if let refs = airportData["topdown"] as? [String] { return refs }
        if let refs = airportData["pre"] as? [String] { return refs }
        if let ref = airportData["pre"] as? String { return [ref] }
        return []
    }

    private func parseType1Airports(from airspaceData: Data, airportOwnership: [String: [String]]) -> [VatglassesAirport] {
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
    
    private func parseOwnershipJSON(data: Data) throws -> ([String: [String]], [String: [String]]) {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "VatglassesService", code: -6,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid ownership JSON format"])
        }
        
        let airspaceOwnership = json["airspace"] as? [String: [String]] ?? [:]
        let airportOwnership = json["airports"] as? [String: [String]] ?? [:]
        
        return (airspaceOwnership, airportOwnership)
    }
    
    private func createAirportsFromRichJSON(_ airportsJSON: [String: Any]) -> [VatglassesAirport] {
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
    
    func getCachedAirports() -> [VatglassesAirport] {
        cachedData?.airports ?? []
    }

    /// Returns all online controllers that cover the given airport via the topdown ownership chain.
    /// This includes upper positions (APP, CTR, etc.) that provide top-down coverage when lower
    /// positions (TWR, GND, DEL) are offline.
    func getTopdownControllers(for airport: VatglassesAirport, controllers: [Controllers]) -> [Controllers] {
        guard let allPositions = cachedData?.allPositions else { return [] }

        let frequencyGroupedControllers = buildFrequencyGroupedControllers(from: controllers)
        var result: [Controllers] = []
        var seen: Set<Int> = []

        for ownerRef in airport.ownerRefs {
            guard let position = allPositions[ownerRef] else { continue }
            if let ctrl = findMatchingController(position: position, frequencyGroupedControllers: frequencyGroupedControllers) {
                if seen.insert(ctrl.cid).inserted {
                    result.append(ctrl)
                }
            }
        }

        return result
    }

    /// Resolves a human-readable position label for a VATSIM callsign using the vatglasses
    /// `callsigns` definitions parsed from region files.
    ///
    /// Callsign structure: `FACILITY_TYPE` or `FACILITY_MIDDLE_TYPE` (e.g. `EGLL_TWR`, `JAX_1_TWR`, `EPWA_P_DEL`).
    /// The last `_`-delimited component is the position type; any component(s) between the
    /// facility and the type are the "middle". An empty middle matches callsigns with no middle.
    ///
    /// Middle keys in the `callsigns` map may be literal strings or regex patterns (e.g. `^[A-Z]`).
    func resolvePositionLabel(for callsign: String) -> String? {
        guard let labels = cachedData?.callsignLabels else { return nil }
        let parts = callsign.uppercased().components(separatedBy: "_")
        guard parts.count >= 2 else { return nil }

        let type = parts.last!
        // Middle is everything between first part and last part, joined back with "_".
        let middle = parts.count > 2 ? parts[1..<parts.count - 1].joined(separator: "_") : ""

        guard let middleMap = labels[type] else { return nil }

        // Exact match first (handles "" for no-middle, and literal middles like "1", "P").
        if let label = middleMap[middle] { return label }

        // Regex fallback for pattern keys like "^[A-Z]".
        for (pattern, label) in middleMap {
            guard !pattern.isEmpty else { continue }
            let regex: NSRegularExpression
            if let cached = regexCache[pattern] {
                regex = cached
            } else if let compiled = try? NSRegularExpression(pattern: pattern) {
                regexCache[pattern] = compiled
                regex = compiled
            } else {
                continue
            }
            if regex.firstMatch(in: middle, range: NSRange(middle.startIndex..., in: middle)) != nil {
                return label
            }
        }

        return nil
    }

    /// Returns the set of callsign prefixes to try when matching controllers to an airport ICAO.
    /// VATSIM controllers sometimes use a shortened identifier (e.g. `EWR_GND`) instead of the
    /// full 4-letter ICAO (e.g. `KEWR_GND`). This returns both the full ICAO and, for 4-character
    /// ICAOs, the 3-character variant with the leading regional letter stripped.
    func callsignPrefixes(for icao: String) -> [String] {
        let upper = icao.uppercased()
        if upper.count == 4 {
            return [upper, String(upper.dropFirst())]
        }
        return [upper]
    }

    /// Returns airports with active controller status.
    /// Stage 1: any controller whose callsign starts with `{ICAO}_` or the shortened variant
    ///          (e.g. `EWR_` for `KEWR`) is a direct match — DEL, GND, TWR, APP, etc.
    /// Stage 2: walk the `ownerRefs` topdown chain to detect APP/CTR covering the airport.
    ///          This runs in addition to stage 1 to pick up upper-level topdown controllers.
    func getActiveAirports(controllers: [Controllers], atis: [ATIS] = []) -> [VatglassesAirport] {
        guard var airports = cachedData?.airports,
              let allPositions = cachedData?.allPositions else { return [] }

        // --- Pre-process controllers once, O(controllers) ---
        // Key: callsign prefix (first component before '_') → controllers with that prefix.
        // Covers both "EWR" (from "EWR_GND") and "KEWR" (from "KEWR_GND").
        var byPrefix: [String: [Controllers]] = [:]
        for ctrl in controllers {
            let upper = ctrl.callsign.uppercased()
            if let underscore = upper.firstIndex(of: "_") {
                let prefix = String(upper[upper.startIndex..<underscore])
                byPrefix[prefix, default: []].append(ctrl)
            }
        }
        // ATIS: same prefix-keyed structure but built from the atis array.
        var atisByPrefix: [String: Bool] = [:]
        for station in atis {
            let upper = station.callsign.uppercased()
            if let underscore = upper.firstIndex(of: "_") {
                let prefix = String(upper[upper.startIndex..<underscore])
                atisByPrefix[prefix] = true
            }
        }

        let frequencyGroupedControllers = buildFrequencyGroupedControllers(from: controllers)
        var positionActiveCache: [String: (isActive: Bool, controller: Controllers?)] = [:]

        // Suffix priority for choosing the most specific direct controller to display.
        let suffixPriority = ["_DEL", "_GND", "_TWR", "_APP", "_DEP", "_CTR"]

        for i in airports.indices {
            let icao = airports[i].icao.uppercased()
            let prefixes = callsignPrefixes(for: icao) // at most 2 strings

            // Stage 1: direct match using byPrefix, which handles middle components like JAX_1_TWR.
            // For each priority suffix, check all controllers sharing the airport prefix.
            var directMatch: Controllers? = nil
            outer: for suffix in suffixPriority {
                for prefix in prefixes {
                    if let candidates = byPrefix[prefix],
                       let ctrl = candidates.first(where: { $0.callsign.uppercased().hasSuffix(suffix) }) {
                        directMatch = ctrl
                        break outer
                    }
                }
            }
            // Fallback: any non-ATIS controller with a matching prefix (e.g. unusual suffixes).
            if directMatch == nil {
                for prefix in prefixes {
                    if let candidates = byPrefix[prefix] {
                        directMatch = candidates.first { !$0.callsign.uppercased().hasSuffix("_ATIS") }
                        if directMatch != nil { break }
                    }
                }
            }

            if let ctrl = directMatch {
                airports[i].isActive = true
                airports[i].activeController = ctrl
            }

            // Stage 2: topdown — walk ownerRefs for APP/CTR covering this airport.
            // Runs regardless of stage 1 so topdown controllers are always included.
            var topdownMatch: Controllers? = nil
            for ownerRef in airports[i].ownerRefs {
                if let cached = positionActiveCache[ownerRef] {
                    if cached.isActive, let ctrl = cached.controller {
                        topdownMatch = ctrl
                        break
                    }
                    continue
                }

                guard let pos = allPositions[ownerRef] else {
                    positionActiveCache[ownerRef] = (isActive: false, controller: nil)
                    continue
                }

                if let ctrl = findMatchingController(position: pos, frequencyGroupedControllers: frequencyGroupedControllers) {
                    positionActiveCache[ownerRef] = (isActive: true, controller: ctrl)
                    topdownMatch = ctrl
                    break
                } else {
                    positionActiveCache[ownerRef] = (isActive: false, controller: nil)
                }
            }

            if directMatch == nil {
                airports[i].isActive = topdownMatch != nil
                airports[i].activeController = topdownMatch
            }

            // Ground-service indicators: T=TWR, G=GND, D=DEL, A=ATIS
            // Uses byPrefix so middle-component callsigns (e.g. JAX_1_TWR) are matched correctly.
            var indicatorLetters: [String] = []
            for prefix in prefixes {
                if let candidates = byPrefix[prefix], candidates.contains(where: { $0.callsign.uppercased().hasSuffix("_TWR") }) { indicatorLetters.append("T"); break }
            }
            for prefix in prefixes {
                if let candidates = byPrefix[prefix], candidates.contains(where: { $0.callsign.uppercased().hasSuffix("_GND") }) { indicatorLetters.append("G"); break }
            }
            for prefix in prefixes {
                if let candidates = byPrefix[prefix], candidates.contains(where: { $0.callsign.uppercased().hasSuffix("_DEL") }) { indicatorLetters.append("D"); break }
            }
            for prefix in prefixes {
                if atisByPrefix[prefix] == true { indicatorLetters.append("A"); break }
            }
            airports[i].groundServiceIndicators = indicatorLetters.joined(separator: " ")
        }

        return airports
    }

    
    // MARK: - Coordinate Conversion

    /// Converts Vatglasses DDMMSS strings to GeoJSON `[longitude, latitude]` pairs.
    private func convertVatglassesCoordinates(_ points: [[String]]) -> [[Double]] {
        points.compactMap { point in
            guard point.count == 2,
                  let lat = parseDMSCoordinate(point[0], isLongitude: false),
                  let lon = parseDMSCoordinate(point[1], isLongitude: true) else { return nil }
            return [lon, lat]
        }
    }

    /// Parses a DMS string (6 or 7 digits) to decimal degrees.
    /// Western hemisphere longitudes (>180°) are normalised to negative values.
    private func parseDMSCoordinate(_ dms: String, isLongitude: Bool) -> Double? {
        var coordinateString = dms
        var isNegative = false

        if coordinateString.hasPrefix("-") || coordinateString.hasPrefix("W") || coordinateString.hasPrefix("S") {
            isNegative = true
            coordinateString = String(coordinateString.dropFirst())
        }

        guard coordinateString.count == 6 || coordinateString.count == 7 else { return nil }

        let degreeEnd = coordinateString.count == 7 ? 3 : 2
        let minuteEnd = degreeEnd + 2

        guard let degrees = Double(String(coordinateString.prefix(degreeEnd))),
              let minutes = Double(String(coordinateString.dropFirst(degreeEnd).prefix(2))),
              let seconds = Double(String(coordinateString.dropFirst(minuteEnd))) else {
            return nil
        }

        var decimal = degrees + (minutes / 60.0) + (seconds / 3600.0)
        if isNegative { decimal = -decimal }
        if isLongitude && decimal > 180 { decimal -= 360 }

        return decimal
    }
}

