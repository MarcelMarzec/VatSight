//
//  VatglassesService.swift
//  VatSight
//
import Foundation
import ZIPFoundation
import CoreLocation

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

    var customRepoSlug: String = ""

    // MARK: - Diagnostics
    var parseErrors: [VatglassesParseError] = []
    var unmatchedControllers: [UnmatchedController] = []
    var syntheticSectors: [SyntheticSector] = []

    var regexCache: [String: NSRegularExpression] = [:] // compiled regex cache

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

    private static let cacheMaxAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days

    /// Serves cache immediately; checks GitHub only when cache is > 7 days old or absent.
    func fetchSectorData(completion: @escaping (Result<VatglassesData, Error>) -> Void) {
        if let cached = cachedData {
            completion(.success(cached))

            // Skip the GitHub commit check if the cache is still fresh.
            let age = Date().timeIntervalSince(cached.lastUpdated)
            if age < Self.cacheMaxAge {
                return
            }
        }

        fetchCommitInfo { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let commitModel):
                if let cached = self.cachedData, cached.commitSHA == commitModel.sha {
                    return
                }
                self.downloadAndParseSectors(commitSHA: commitModel.sha, commitDate: commitModel.commitDate, completion: completion)

            case .failure(let error):
                if self.cachedData == nil {
                    completion(.failure(error))
                } else {
                    // Re-serve cache so the loading flag is dismissed correctly.
                    completion(.success(self.cachedData!))
                }
            }
        }
    }

    func getCachedSectors() -> [VatglassesSector] {
        cachedData?.sectors ?? []
    }

    func getCachedPositions() -> [String: VatglassesPosition] {
        cachedData?.allPositions ?? [:]
    }

    func clearCache() {
        cachedData = nil
        lastFetchDate = nil

        if FileManager.default.fileExists(atPath: cacheFileURL.path) {
            try? FileManager.default.removeItem(at: cacheFileURL)
        }
    }

    func getActiveSectors(controllers: [Controllers], airports: [VatglassesAirport]) -> [VatglassesSector] {
        guard var sectors = cachedData?.sectors,
              let allPositions = cachedData?.allPositions else { return [] }

        let frequencyGroupedControllers = buildFrequencyGroupedControllers(from: controllers)
        let prefixGroupedControllers = buildCallsignPrefixGroupedControllers(from: controllers)
        var positionActiveCache: [String: (isActive: Bool, controller: Controllers?)] = [:]

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
                    sectors[i].activeOwnerColorHex = allPositions["NODATA/\(ownerRef.uppercased())"]?.primaryColorHex
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

        // Suppress synthetic circles where a real matched APP/DEP sector already exists.
        var icaosWithRealAppSector = Set<String>()
        for sector in sectors where sector.isActive {
            guard let ctrl = sector.activeController else { continue }
            let upper = ctrl.callsign.uppercased()
            guard upper.hasSuffix("_APP") || upper.hasSuffix("_DEP") else { continue }
            let icao = String(upper.prefix(while: { $0 != "_" }))
            icaosWithRealAppSector.insert(icao)
        }

        let synthetic = generateSyntheticSectors(
            unmatchedCIDs: controllers.filter { !matchedCIDs.contains($0.cid) },
            airports: airports,
            icaosWithRealAppSector: icaosWithRealAppSector
        )
        var syntheticCIDs = Set<Int>()
        for s in synthetic {
            if let cid = s.activeController?.cid { syntheticCIDs.insert(cid) }
            for co in s.activeCoControllers { syntheticCIDs.insert(co.cid) }
        }
        sectors.append(contentsOf: synthetic)

        unmatchedControllers = controllers
            .filter { !matchedCIDs.contains($0.cid) && !syntheticCIDs.contains($0.cid) }
            .map { UnmatchedController(callsign: $0.callsign, frequency: $0.frequency, cid: $0.cid, name: $0.name) }

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

    /// Returns all controllers covering the airport via the topdown ownership chain (APP, CTR, etc.).
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

    /// Maps VATSIM callsign → human label via vatglasses `callsigns` definitions.
    /// Middle keys may be literal strings or regex patterns (e.g. `^[A-Z]`).
    func resolvePositionLabel(for callsign: String) -> String? {
        guard let labels = cachedData?.callsignLabels else { return nil }
        let parts = callsign.uppercased().components(separatedBy: "_")
        guard parts.count >= 2 else { return nil }

        let type = parts.last!
        let middle = parts.count > 2 ? parts[1..<parts.count - 1].joined(separator: "_") : ""

        guard let middleMap = labels[type] else { return nil }

        if let label = middleMap[middle] { return label } // exact match first

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

    /// Returns the full ICAO and (for 4-char ICAOs) the 3-char variant, e.g. ["KEWR", "EWR"].
    func callsignPrefixes(for icao: String) -> [String] {
        let upper = icao.uppercased()
        if upper.count == 4 {
            return [upper, String(upper.dropFirst())]
        }
        return [upper]
    }

    /// Stage 1: direct callsign prefix match; Stage 2: topdown ownerRef walk.
    func getActiveAirports(controllers: [Controllers], atis: [ATIS] = []) -> [VatglassesAirport] {
        guard var airports = cachedData?.airports,
              let allPositions = cachedData?.allPositions else { return [] }

        var byPrefix: [String: [Controllers]] = [:]
        for ctrl in controllers {
            let upper = ctrl.callsign.uppercased()
            if let underscore = upper.firstIndex(of: "_") {
                let prefix = String(upper[upper.startIndex..<underscore])
                byPrefix[prefix, default: []].append(ctrl)
            }
        }
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

        let suffixPriority = ["_DEL", "_GND", "_TWR", "_APP", "_DEP", "_CTR"]

        for i in airports.indices {
            let icao = airports[i].icao.uppercased()
            let prefixes = callsignPrefixes(for: icao)

            // Stage 1: direct prefix match (also handles middle components like JAX_1_TWR).
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
            if directMatch == nil { // fallback for unusual suffixes
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

            // Stage 2: topdown walk (always runs to catch APP/CTR upper coverage).
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

            let hasAtis = prefixes.contains { atisByPrefix[$0] == true }

            if directMatch == nil {
                airports[i].isActive = topdownMatch != nil || hasAtis
                airports[i].activeController = topdownMatch
            }

            var indicatorLetters: [String] = [] // T=TWR, G=GND, D=DEL, A=ATIS
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
