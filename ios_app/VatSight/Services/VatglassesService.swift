//
//  VatglassesService.swift
//  VatSight
//
//  Created by Marcel Marzec on 03/06/2026.
//
import Foundation
import ZIPFoundation
import CoreLocation
internal import _LocationEssentials

final class VatglassesService {

    static let defaultRepoSlug = "lennycolton/vatglasses-data"

    private var commitURL: URL {
        let slug = customRepoSlug.isEmpty ? Self.defaultRepoSlug : customRepoSlug
        return URL(string: "https://api.github.com/repos/\(slug)/commits/main")!
    }
    private var repoURL: URL {
        let slug = customRepoSlug.isEmpty ? Self.defaultRepoSlug : customRepoSlug
        return URL(string: "https://api.github.com/repos/\(slug)/zipball/main")!
    }

    /// Set to a non-empty "owner/repo" string to use a custom GitHub repository.
    var customRepoSlug: String = ""

    // MARK: - Diagnostics
    /// Parse errors collected during the most recent data load. Cleared on each new fetch.
    private(set) var parseErrors: [VatglassesParseError] = []
    /// Controllers that were online but matched no Vatglasses position. Updated by getActiveSectors.
    private(set) var unmatchedControllers: [UnmatchedController] = []
    /// Synthetic sectors generated for TWR/APP controllers with no real VATGlasses sector.
    private(set) var syntheticSectors: [SyntheticSector] = []

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
    /// Also generates synthetic circle sectors for TWR/APP controllers that have no real
    /// VATGlasses sector, and updates `unmatchedControllers` and `syntheticSectors`.
    func getActiveSectors(controllers: [Controllers], airports: [VatglassesAirport]) -> [VatglassesSector] {
        guard var sectors = cachedData?.sectors,
              let allPositions = cachedData?.allPositions else { return [] }

        let frequencyGroupedControllers = buildFrequencyGroupedControllers(from: controllers)
        let prefixGroupedControllers = buildCallsignPrefixGroupedControllers(from: controllers)
        var positionActiveCache: [String: (isActive: Bool, controller: Controllers?)] = [:]

        // Track which controller CIDs have been matched to at least one sector.
        var matchedCIDs = Set<Int>()

        for i in sectors.indices {
            if sectors[i].isBasicDataOnly {
                // nodata.json sectors: ownerRefs are position IDs (e.g. "KZMP").
                // Look up the parsed nodata position to get its "pre" prefixes, then
                // match the controller callsign against those prefixes + type.
                if let (ownerRef, matchingController) = findActiveOwnerForBasicSector(
                    ownerRefs: sectors[i].ownerRefs,
                    allPositions: allPositions,
                    prefixGroupedControllers: prefixGroupedControllers
                ) {
                    sectors[i].isActive = true
                    sectors[i].activeOwnerRef = ownerRef
                    sectors[i].activeController = matchingController
                    sectors[i].activeOwnerColorHex = allPositions["nodata/\(ownerRef)"]?.primaryColorHex
                    matchedCIDs.insert(matchingController.cid)
                } else {
                    sectors[i].isActive = false
                    sectors[i].activeOwnerRef = nil
                    sectors[i].activeController = nil
                    sectors[i].activeOwnerColorHex = nil
                }
            } else if let (activeOwnerRef, matchingController) = findActiveOwnerWithController(
                for: sectors[i],
                allPositions: allPositions,
                frequencyGroupedControllers: frequencyGroupedControllers,
                prefixGroupedControllers: prefixGroupedControllers,
                positionActiveCache: &positionActiveCache
            ) {
                sectors[i].isActive = true
                sectors[i].activeOwnerRef = activeOwnerRef
                sectors[i].activeController = matchingController
                sectors[i].activeOwnerColorHex = allPositions[activeOwnerRef]?.primaryColorHex
                matchedCIDs.insert(matchingController.cid)
            } else {
                sectors[i].isActive = false
                sectors[i].activeOwnerRef = nil
                sectors[i].activeController = nil
                sectors[i].activeOwnerColorHex = nil
            }
        }

        // Generate synthetic circle sectors for TWR/APP/DEP controllers that had no real sector.
        let synthetic = generateSyntheticSectors(
            unmatchedCIDs: controllers.filter { !matchedCIDs.contains($0.cid) },
            airports: airports
        )
        // Mark synthetic controllers as matched so they don't appear in the unmatched list.
        var syntheticCIDs = Set<Int>()
        for s in synthetic {
            if let cid = s.activeController?.cid { syntheticCIDs.insert(cid) }
        }
        sectors.append(contentsOf: synthetic)

        // Build the unmatched controller list: online ATC not accounted for by any sector.
        // No filtering here — filtering is done in the UI so the user can toggle categories.
        unmatchedControllers = controllers
            .filter { !matchedCIDs.contains($0.cid) && !syntheticCIDs.contains($0.cid) }
            .map { UnmatchedController(callsign: $0.callsign, frequency: $0.frequency, cid: $0.cid, name: $0.name) }

        // Record synthetic sector diagnostics for the developer view.
        self.syntheticSectors = synthetic.compactMap { sector -> SyntheticSector? in
            guard let ctrl = sector.activeController else { return nil }
            let icao = String(ctrl.callsign.prefix(while: { $0 != "_" }))
            let radiusNm: Double = ctrl.callsign.uppercased().hasSuffix("_TWR") ? 5.0 : 20.0
            return SyntheticSector(icao: icao, callsign: ctrl.callsign, frequency: ctrl.frequency, radiusNm: radiusNm, cid: ctrl.cid, name: ctrl.name)
        }

        return sectors
    }

    /// Generates synthetic circle sectors for TWR/APP/DEP controllers that are online
    /// but have no matching real VATGlasses sector.
    ///
    /// Performance notes:
    /// - Builds an O(1) ICAO → airport lookup once before iteration.
    /// - Deduplicates by (ICAO + position type) so only one circle is drawn per airport per type.
    /// - Circle geometry (64 vertices) is lightweight and computed only when needed.
    private func generateSyntheticSectors(
        unmatchedCIDs controllers: [Controllers],
        airports: [VatglassesAirport]
    ) -> [VatglassesSector] {
        // Build a fast ICAO → airport coordinate lookup.
        var airportByICAO: [String: VatglassesAirport] = [:]
        airportByICAO.reserveCapacity(airports.count)
        for airport in airports {
            airportByICAO[airport.icao.uppercased()] = airport
        }

        var result: [VatglassesSector] = []
        // Dedup key: "LSZH_TWR", "EDDH_APP" etc. — one circle per callsign type per airport.
        var seenKeys = Set<String>()

        for controller in controllers {
            let upper = controller.callsign.uppercased()

            // Only synthesise for TWR, APP, and DEP positions.
            let isTWR = upper.hasSuffix("_TWR")
            let isAPP = upper.hasSuffix("_APP") || upper.hasSuffix("_DEP")
            guard isTWR || isAPP else { continue }

            // Skip mentor/trainee callsigns (e.g. EPKK_X_TWR, EPKK_T_TWR). _X_ and _T_ are
            // VATSIM-standard infixes for mentoring/training sessions and should never get a
            // synthetic sector — the real controller's sector already covers the airspace.
            guard !upper.contains("_X_") && !upper.contains("_T_") else { continue }

            // Extract the ICAO prefix (everything before the first underscore).
            guard let underscoreIdx = upper.firstIndex(of: "_") else { continue }
            let icao = String(upper[upper.startIndex..<underscoreIdx])

            // Deduplicate: skip if we already generated a circle for this callsign.
            guard seenKeys.insert(upper).inserted else { continue }

            // Require a known airport with valid coordinates.
            guard let airport = airportByICAO[icao],
                  abs(airport.latitude) <= 90,
                  abs(airport.longitude) <= 180 else { continue }

            let radiusNm: Double = isTWR ? 5.0 : 20.0
            let geometry = makeCircleGeometry(latitude: airport.latitude, longitude: airport.longitude, radiusNm: radiusNm)

            let posType = isTWR ? "TWR" : "APP"
            // Altitudes stored in FL (hundreds of feet): TWR 0–FL20 (0–2000ft), APP/DEP FL20–FL200 (2000–20000ft).
            let minFL = isTWR ? 0 : 20
            let maxFL = isTWR ? 20 : 200
            let properties = SectorProperties(
                min: minFL,
                max: maxFL,
                name: "\(icao) \(posType) (Synthetic)",
                groupName: nil,
                color: nil
            )

            result.append(VatglassesSector(
                id: "synthetic/\(upper)",
                ownerRefs: [icao],
                frequency: controller.frequency,
                geometry: geometry,
                properties: properties,
                isActive: true,
                activeOwnerColorHex: nil,
                activeOwnerRef: icao,
                activeController: controller,
                isBasicDataOnly: true,
                isSynthetic: true
            ))
        }

        return result
    }

    /// Finds the first online controller for a nodata.json sector.
    ///
    /// For each ownerRef (a position ID like "KZMP"), looks up the parsed nodata position
    /// under "nodata/{ownerRef}" and delegates to `findMatchingController` which uses the
    /// callsign-primary, frequency-secondary strategy.
    ///
    /// Falls back to a direct prefix match against the ownerRef itself for legacy entries
    /// (e.g. regions where the ownerRef IS the callsign prefix and no position was parsed).
    private func findActiveOwnerForBasicSector(
        ownerRefs: [String],
        allPositions: [String: VatglassesPosition],
        prefixGroupedControllers: [String: [Controllers]]
    ) -> (ownerRef: String, controller: Controllers)? {
        // frequencyGroupedControllers not needed here — nodata positions rarely have frequencies.
        // Pass an empty map so findMatchingController falls through to callsign-only matching.
        let emptyFreqMap: [String: [Controllers]] = [:]

        for ownerRef in ownerRefs {
            // Primary path: delegate to the shared matching logic.
            if let position = allPositions["nodata/\(ownerRef)"] {
                if let match = findMatchingController(
                    position: position,
                    frequencyGroupedControllers: emptyFreqMap,
                    prefixGroupedControllers: prefixGroupedControllers
                ) {
                    return (ownerRef, match)
                }
            }

            // Fallback: ownerRef itself is used as a callsign prefix (legacy / non-US regions
            // where the sector owner string doubles as the prefix, e.g. "KZBW" → "KZBW_FSS").
            let key = ownerRef.uppercased()
            if let candidates = prefixGroupedControllers[key],
               let match = candidates.first {
                return (ownerRef, match)
            }
        }
        return nil
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

    /// Groups controllers by the callsign prefix (the component before the first `_`).
    /// Used as a fast lookup for positions that have no frequency in the data.
    private func buildCallsignPrefixGroupedControllers(from controllers: [Controllers]) -> [String: [Controllers]] {
        var grouped: [String: [Controllers]] = [:]
        for controller in controllers {
            let upper = controller.callsign.uppercased()
            if let underscore = upper.firstIndex(of: "_") {
                let prefix = String(upper[upper.startIndex..<underscore])
                grouped[prefix, default: []].append(controller)
            }
        }
        return grouped
    }
    
    /// Walks the hierarchical ownership chain for a sector and returns the first active owner.
    private func findActiveOwnerWithController(
        for sector: VatglassesSector,
        allPositions: [String: VatglassesPosition],
        frequencyGroupedControllers: [String: [Controllers]],
        prefixGroupedControllers: [String: [Controllers]],
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
                frequencyGroupedControllers: frequencyGroupedControllers,
                prefixGroupedControllers: prefixGroupedControllers
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
    ///
    /// Matching strategy (mirrors the vatglasses reference implementation):
    /// 1. Always use callsign pattern as the primary filter — narrows candidates via the
    ///    prefix-keyed lookup (O(1) per `pre` entry) so no full scan is needed.
    /// 2. When the position has a frequency, additionally require the controller to be on
    ///    that frequency. This eliminates false positives when two positions share the same
    ///    callsign prefix but operate on different frequencies (e.g. different APP sectors).
    /// 3. When the position has no frequency (e.g. NAT, oceanic FSS positions), the callsign
    ///    match alone is sufficient — there is no secondary filter to apply.
    private func findMatchingController(
        position: VatglassesPosition,
        frequencyGroupedControllers: [String: [Controllers]],
        prefixGroupedControllers: [String: [Controllers]]
    ) -> Controllers? {
        // Collect candidates by callsign prefix — O(pre.count) lookups, not O(controllers).
        var trainingMatch: Controllers? = nil

        for pre in position.facilityPrefixes {
            let key = pre.uppercased()
            guard let candidates = prefixGroupedControllers[key] else { continue }

            for controller in candidates {
                guard matchesCallsignPattern(controller: controller, position: position) else { continue }

                // Callsign matches. If the position has a frequency, also verify the controller
                // is on that frequency to avoid cross-sector false positives.
                let frequencyMatches: Bool
                if let freq = position.frequency {
                    let normFreq = normaliseFrequency(freq)
                    let controllerFreq = normaliseFrequency(controller.frequency)
                    frequencyMatches = controllerFreq == normFreq
                } else {
                    // No frequency defined — callsign match is sufficient.
                    frequencyMatches = true
                }

                guard frequencyMatches else { continue }

                // Deprioritise mentor/trainee callsigns (_X_, _T_) — keep them as a fallback
                // but always prefer the real controller if one also matches this position.
                let upper = controller.callsign.uppercased()
                if upper.contains("_X_") || upper.contains("_T_") {
                    if trainingMatch == nil { trainingMatch = controller }
                } else {
                    return controller
                }
            }
        }

        // No plain controller matched — fall back to the training/mentor match if present.
        return trainingMatch
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
                try? FileManager.default.removeItem(at: cacheFileURL)
                return
            }
            cachedData = decoded
        } catch {
            try? FileManager.default.removeItem(at: cacheFileURL)
        }
    }

    private func saveCachedDataToDisk() {
        guard let dataToSave = cachedData else { return }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(dataToSave)
            try data.write(to: cacheFileURL, options: .atomic)
        } catch { }
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
        parseErrors = []   // reset diagnostics for this fetch
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
    private func parseNodataFile(data: Data) -> ([VatglassesSector], [VatglassesAirport], [String: VatglassesPosition], [String: [String: String]]) {
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
    private func parseGroupNames(from data: Data) -> [String: String] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let groupsJSON = json["groups"] as? [String: [String: Any]] else { return [:] }
        return groupsJSON.compactMapValues { ($0["name"] as? String).map { stripHTML($0) } }
    }

    /// Replaces HTML line-break tags with ". " and strips any remaining HTML tags.
    private func stripHTML(_ raw: String) -> String {
        raw.replacingOccurrences(of: "<br\\s*/?>", with: ". ", options: .regularExpression)
           .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
           .trimmingCharacters(in: .whitespacesAndNewlines)
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
    /// Some data sources (e.g. US/FAA airports) store coords as integers scaled by 1e6
    /// (e.g. 41979594 instead of 41.979594). Values outside ±360 are normalised by ÷1e6.
    private func parseCoord(_ raw: Any) -> (latitude: Double, longitude: Double)? {
        func normalise(_ v: Double) -> Double {
            return abs(v) > 360 ? v / 1_000_000 : v
        }
        if let doubles = raw as? [Double], doubles.count == 2 {
            return (normalise(doubles[0]), normalise(doubles[1]))
        }
        if let mixed = raw as? [Any], mixed.count == 2 {
            let vals = mixed.compactMap { v -> Double? in
                if let d = v as? Double { return d }
                if let s = v as? String { return Double(s) }
                return nil
            }
            if vals.count == 2 { return (normalise(vals[0]), normalise(vals[1])) }
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
        let prefixGroupedControllers = buildCallsignPrefixGroupedControllers(from: controllers)
        var result: [Controllers] = []
        var seen: Set<Int> = []

        for ownerRef in airport.ownerRefs {
            guard let position = allPositions[ownerRef] else { continue }
            if let ctrl = findMatchingController(position: position, frequencyGroupedControllers: frequencyGroupedControllers, prefixGroupedControllers: prefixGroupedControllers) {
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
        let prefixGroupedControllers = buildCallsignPrefixGroupedControllers(from: controllers)
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

                if let ctrl = findMatchingController(position: pos, frequencyGroupedControllers: frequencyGroupedControllers, prefixGroupedControllers: prefixGroupedControllers) {
                    positionActiveCache[ownerRef] = (isActive: true, controller: ctrl)
                    topdownMatch = ctrl
                    break
                } else {
                    positionActiveCache[ownerRef] = (isActive: false, controller: nil)
                }
            }

            // An ATIS-only airport has no direct or topdown controller match, but should
            // still be shown as active since ATC is present.
            let hasAtis = prefixes.contains { atisByPrefix[$0] == true }

            if directMatch == nil {
                airports[i].isActive = topdownMatch != nil || hasAtis
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

    
    // MARK: - Synthetic Circle Geometry

    /// Generates a GeoJSON Polygon approximating a circle on the Earth's surface.
    ///
    /// Uses the haversine-inverse formula for accurate placement at any latitude.
    /// 64 vertices give a smooth appearance while remaining lightweight for Mapbox.
    private func makeCircleGeometry(latitude: Double, longitude: Double, radiusNm: Double, steps: Int = 64) -> SectorGeometry {
        let radiusM = radiusNm * 1852.0   // nm → metres
        let latRad  = latitude  * .pi / 180
        let lonRad  = longitude * .pi / 180
        let earthR: Double = 6_371_000
        let angularDist = radiusM / earthR

        var ring: [[Double]] = []
        ring.reserveCapacity(steps + 1)

        for i in 0...steps {
            let bearing = (Double(i % steps) / Double(steps)) * 2 * .pi
            let lat2 = asin(sin(latRad) * cos(angularDist) +
                            cos(latRad) * sin(angularDist) * cos(bearing))
            let lon2 = lonRad + atan2(
                sin(bearing) * sin(angularDist) * cos(latRad),
                cos(angularDist) - sin(latRad) * sin(lat2)
            )
            ring.append([lon2 * 180 / .pi, lat2 * 180 / .pi])
        }

        // GeoJSON Polygon → [outerRing] → wrapped in [[[[Double]]]]
        return SectorGeometry(type: "Polygon", coordinates: [[ring]])
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

