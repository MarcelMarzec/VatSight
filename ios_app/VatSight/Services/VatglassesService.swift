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

    var commitURL: URL {
        let slug = customRepoSlug.isEmpty ? Self.defaultRepoSlug : customRepoSlug
        return URL(string: "https://api.github.com/repos/\(slug)/commits/main")!
    }
    var repoURL: URL {
        let slug = customRepoSlug.isEmpty ? Self.defaultRepoSlug : customRepoSlug
        return URL(string: "https://api.github.com/repos/\(slug)/zipball/main")!
    }

    /// Set to a non-empty "owner/repo" string to use a custom GitHub repository.
    var customRepoSlug: String = ""

    // MARK: - Diagnostics
    /// Parse errors collected during the most recent data load. Cleared on each new fetch.
    var parseErrors: [VatglassesParseError] = []
    /// Controllers that were online but matched no Vatglasses position. Updated by getActiveSectors.
    var unmatchedControllers: [UnmatchedController] = []
    /// Synthetic sectors generated for TWR/APP controllers with no real VATGlasses sector.
    var syntheticSectors: [SyntheticSector] = []

    /// Cache of compiled NSRegularExpression objects keyed by pattern string.
    /// Avoids recompiling the same regex on every resolvePositionLabel call.
    var regexCache: [String: NSRegularExpression] = [:]

    var cachedData: VatglassesData?
    var lastFetchDate: Date?

    // MARK: - Persistent Storage
    let cacheFileURL: URL = {
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
    /// Also generates synthetic APP circle sectors for approach controllers that have no real
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

        // Build the set of ICAOs that already have a matched real APP/DEP sector.
        // A synthetic APP circle must not be generated for these — a real sector already covers
        // the approach airspace even if the specific unmatched controller has no sector of their own.
        var icaosWithRealAppSector = Set<String>()
        for sector in sectors where sector.isActive {
            guard let ctrl = sector.activeController else { continue }
            let upper = ctrl.callsign.uppercased()
            guard upper.hasSuffix("_APP") || upper.hasSuffix("_DEP") else { continue }
            let icao = String(upper.prefix(while: { $0 != "_" }))
            icaosWithRealAppSector.insert(icao)
        }

        // Generate synthetic circle sectors for APP/DEP controllers that had no real sector.
        let synthetic = generateSyntheticSectors(
            unmatchedCIDs: controllers.filter { !matchedCIDs.contains($0.cid) },
            airports: airports,
            icaosWithRealAppSector: icaosWithRealAppSector
        )
        // Mark synthetic controllers (primary + co-controllers) as matched so they don't
        // appear in the unmatched list.
        var syntheticCIDs = Set<Int>()
        for s in synthetic {
            if let cid = s.activeController?.cid { syntheticCIDs.insert(cid) }
            for co in s.activeCoControllers { syntheticCIDs.insert(co.cid) }
        }
        sectors.append(contentsOf: synthetic)

        // Build the unmatched controller list: online ATC not accounted for by any sector.
        // No filtering here — filtering is done in the UI so the user can toggle categories.
        unmatchedControllers = controllers
            .filter { !matchedCIDs.contains($0.cid) && !syntheticCIDs.contains($0.cid) }
            .map { UnmatchedController(callsign: $0.callsign, frequency: $0.frequency, cid: $0.cid, name: $0.name) }

        // Record synthetic sector diagnostics for the developer view.
        // Include both the primary controller and any co-controllers on each sector.
        self.syntheticSectors = synthetic.flatMap { sector -> [SyntheticSector] in
            guard let ctrl = sector.activeController else { return [] }
            let icao = String(ctrl.callsign.prefix(while: { $0 != "_" }))
            let primary = SyntheticSector(icao: icao, callsign: ctrl.callsign, frequency: ctrl.frequency, radiusNm: 20.0, cid: ctrl.cid, name: ctrl.name)
            let co = sector.activeCoControllers.map { co in
                let coIcao = String(co.callsign.prefix(while: { $0 != "_" }))
                return SyntheticSector(icao: coIcao, callsign: co.callsign, frequency: co.frequency, radiusNm: 20.0, cid: co.cid, name: co.name)
            }
            return [primary] + co
        }

        return sectors
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
}
