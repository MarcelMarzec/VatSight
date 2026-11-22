//
//  RadarViewModel+EventOverlays.swift
//  VatSight
//
//  Turns EventsManager's overlay inputs into things the map draws: airport highlights,
//  booked sectors and the selected airport's booking list, plus the bookings shown in an
//  event's details.
//
//  Booking → sector matching. Bookings carry only a callsign (no frequency), so each booked
//  callsign is resolved to VATGlasses positions in this order:
//   1. Learned: the positions that callsign actually owned the last time it was online
//      (recorded from live, frequency-verified matches by LearnedPositionStore).
//   2. The only position with that facility prefix and type.
//   3. The callsign's middle component: the position ID itself (EDMM_ALB_CTR → "ALB") or an
//      ICAO fragment plus the middle (EDDM_ND_APP → "DMND", EGLL_N_APP → "LLN").
//   4. Bandbox callsigns without a middle (EDGG_CTR): the position covering most sectors.
//   5. Approximate: a split callsign that matched nothing above falls back to the bandbox
//      position and is labelled "≈" on the map, rather than not being drawn at all.
//  A sector is "booked" when the first booked position in its owner chain is reached before
//  any online one, mirroring how live ownership is resolved top-down.
//

import Foundation
import CoreLocation

/// Indexes over the VATGlasses data, rebuilt only when that data changes.
struct BookingPositionIndexCache {
    /// VATGlasses commit + counts the indexes were built from.
    var signature: String = ""
    /// "PREFIX|TYPE" → position keys.
    var positionsByPrefixAndType: [String: [String]] = [:]
    /// Position key → number of sectors that list it as an owner.
    var ownerReferenceCounts: [String: Int] = [:]
    /// Position key → indices into the base sector list.
    var sectorIndicesByOwner: [String: [Int]] = [:]
    /// Callsign prefix (full ICAO or 3-letter variant) → airport ICAOs.
    var airportICAOsByPrefix: [String: [String]] = [:]
    var airportSignature: Int = -1
}

/// The result of mapping pending bookings to positions.
struct BookedPositionResolution {
    /// Position key → earliest pending booking for it.
    var byPosition: [String: AtcBooking] = [:]
    /// Bookings placed by the approximate fallback (step 5).
    var approximateBookingIDs: Set<Int> = []
}

extension RadarViewModel {

    // MARK: - Entry Points

    func applyEventOverlay(_ overlay: EventOverlayInputs) {
        guard overlay != eventOverlay else { return }
        eventOverlay = overlay
        refreshEventOverlays()
    }

    /// Re-derives highlights, booked sectors and the selected airport's bookings.
    /// Runs after each VATSIM refresh (online state changes) and when the overlay changes.
    func refreshEventOverlays() {
        rebuildBookingIndexesIfNeeded()
        learnLivePositions()

        let online = Set(mergedWithDebugControllers(controllers).map { $0.callsign.uppercased() })
        let pending = eventOverlay.bookings.filter { !online.contains($0.callsign) }

        // Airport highlights
        var highlights: [String: AirportHighlight] = [:]
        if eventOverlay.showBookingHighlights {
            for booking in pending where booking.isAirportPosition {
                for icao in bookingIndexCache.airportICAOsByPrefix[booking.callsignPrefix] ?? [] {
                    highlights[icao] = .upcomingBooking
                }
            }
        }
        if eventOverlay.showEventHighlights {
            for (icao, highlight) in eventOverlay.eventHighlights {
                highlights[icao] = max(highlights[icao] ?? highlight, highlight)
            }
        }
        if highlights != airportHighlights {
            airportHighlights = highlights
        }

        let resolution = resolveBookedPositions(pending)
        bookedPositionIndex = resolution.byPosition
        approximateBookingIDs = resolution.approximateBookingIDs

        updateBookedSectors(pending: pending)
        updateBookingsAtSelectedAirport()
    }

    // MARK: - Selected Airport

    func updateBookingsAtSelectedAirport() {
        guard let icao = selectedAirportICAO else {
            if !bookingsAtSelectedAirport.isEmpty { bookingsAtSelectedAirport = [] }
            return
        }
        let prefixes = Set(vatglassesService.callsignPrefixes(for: icao))
        let online = Set(mergedWithDebugControllers(controllers).map { $0.callsign.uppercased() })

        var result = eventOverlay.bookings.filter {
            !online.contains($0.callsign) && prefixes.contains($0.callsignPrefix) && !$0.callsign.hasSuffix("_ATIS")
        }
        // Top-down cover (APP/CTR) through the airport's VATGlasses owner chain.
        if let airport = selectedAirport {
            var seen = Set(result.map(\.id))
            for ownerRef in airport.ownerRefs {
                if let booking = bookedPositionIndex[ownerRef], seen.insert(booking.id).inserted {
                    result.append(booking)
                }
            }
        }
        result.sort(by: bookingOrder)
        if result != bookingsAtSelectedAirport {
            bookingsAtSelectedAirport = result
        }
    }

    /// Start time, then DEL → GND → TWR → APP → CTR.
    private func bookingOrder(_ a: AtcBooking, _ b: AtcBooking) -> Bool {
        if a.start != b.start { return a.start < b.start }
        let orderA = positionOrder(a.callsign), orderB = positionOrder(b.callsign)
        if orderA != orderB { return orderA < orderB }
        return a.callsign < b.callsign
    }

    // MARK: - Event Bookings

    /// Every booking (any type, online or not) overlapping the event at its airports, including
    /// approach and centre positions that cover those airports top-down.
    func bookings(for event: VatsimEvent, from allBookings: [AtcBooking]) -> [AtcBooking] {
        let icaos = event.allICAOs
        guard !icaos.isEmpty else { return [] }
        rebuildBookingIndexesIfNeeded()

        let overlapping = allBookings.filter {
            $0.start < event.endTime && $0.end > event.startTime && $0.facilitySuffix != "ATIS"
        }
        guard !overlapping.isEmpty else { return [] }

        var prefixes = Set<String>()
        var ownerRefs = Set<String>()
        for icao in icaos {
            prefixes.formUnion(vatglassesService.callsignPrefixes(for: icao))
            if let airport = airports.first(where: { $0.icao.uppercased() == icao }) {
                ownerRefs.formUnion(airport.ownerRefs)
            }
        }

        var result: [AtcBooking] = []
        var seen = Set<Int>()
        for booking in overlapping where prefixes.contains(booking.callsignPrefix) {
            if seen.insert(booking.id).inserted { result.append(booking) }
        }
        if !ownerRefs.isEmpty {
            for booking in overlapping where !seen.contains(booking.id) {
                let keys = positionKeys(for: booking).keys
                if keys.contains(where: ownerRefs.contains) {
                    seen.insert(booking.id)
                    result.append(booking)
                }
            }
        }
        return result.sorted(by: bookingOrder)
    }

    // MARK: - Map Display

    /// Booked sectors to draw, honouring the sector layer toggle, merge mode and altitude filter.
    var bookedSectorsToDisplay: [BookedSector] {
        guard showSectorsLayer, eventOverlay.showBookedSectors else { return [] }
        if mergeSectors { return mergedBookedSectors }
        guard altitudeFilterEnabled else { return bookedSectors }
        return bookedSectors.filter { booked in
            guard let props = booked.sector.properties,
                  let minFL = props.min,
                  let maxFL = props.max else { return true }
            return selectedAltitudeFt >= Double(minFL) * 100 && selectedAltitudeFt <= Double(maxFL) * 100
        }
    }

    /// One dissolved polygon per booking, like merged live sectors. Cached until the booked set changes.
    var mergedBookedSectors: [BookedSector] {
        if let cached = mergedBookedSectorsCache, cached.signature == bookedSectorsSignature {
            return cached.sectors
        }
        var groups: [Int: [BookedSector]] = [:]
        var order: [Int] = []
        for booked in bookedSectors {
            if groups[booked.booking.id] == nil { order.append(booked.booking.id) }
            groups[booked.booking.id, default: []].append(booked)
        }
        let merged: [BookedSector] = order.compactMap { id in
            guard let group = groups[id], let first = group.first else { return nil }
            guard group.count > 1 else { return first }
            let geometry = SectorGeoJSON.unionGeometry(of: group.map(\.sector))
            let sector = VatglassesSector(
                id: "BOOKED-MERGED/\(first.booking.id)",
                ownerRefs: [],
                frequency: "",
                geometry: geometry,
                properties: first.sector.properties,
                isBasicDataOnly: first.sector.isBasicDataOnly,
                isSynthetic: true
            )
            return BookedSector(sector: sector, booking: first.booking)
        }
        mergedBookedSectorsCache = (bookedSectorsSignature, merged)
        return merged
    }

    /// ICAOs with traffic (flying or prefiled) to or from `icao`, including itself, or nil for
    /// no airport. Airports outside this set are faded on the map.
    func airportConnections(for icao: String?) -> Set<String>? {
        guard let selected = icao?.uppercased() else { return nil }
        var connected: Set<String> = [selected]
        func link(_ departure: String, _ arrival: String) {
            let dep = departure.uppercased(), arr = arrival.uppercased()
            if dep == selected, !arr.isEmpty { connected.insert(arr) }
            if arr == selected, !dep.isEmpty { connected.insert(dep) }
        }
        for pilot in pilots {
            if let plan = pilot.flight_plan { link(plan.departure, plan.arrival) }
        }
        for prefile in prefiles {
            if let plan = prefile.flight_plan { link(plan.departure, plan.arrival) }
        }
        return connected
    }

    // MARK: - Learning

    /// Records which positions each online controller owns, so a later booking for the same
    /// callsign resolves exactly. Only frequency-verified VATGlasses matches are recorded.
    private func learnLivePositions() {
        var observations: [String: Set<String>] = [:]
        for sector in sectors where sector.isActive && !sector.isSynthetic {
            guard let controller = sector.activeController, let ownerRef = sector.activeOwnerRef else { continue }
            let key = Self.positionKey(forOwnerRef: ownerRef, in: sector)
            guard allPositions[key] != nil else { continue }
            observations[controller.callsign.uppercased(), default: []].insert(key)
        }
        guard !observations.isEmpty else { return }
        learnedPositions.record(observations)
    }

    // MARK: - Indexes

    private func rebuildBookingIndexesIfNeeded() {
        let baseSectors = vatglassesService.getCachedSectors()
        let positions = allPositions
        let commit = vatglassesService.cachedData?.commitSHA ?? ""
        let signature = "\(commit)#\(positions.count)#\(baseSectors.count)"
        if signature != bookingIndexCache.signature {
            var byPrefixAndType: [String: [String]] = [:]
            for (key, position) in positions {
                let type = position.type.uppercased()
                for prefix in position.facilityPrefixes {
                    byPrefixAndType["\(prefix.uppercased())|\(type)", default: []].append(key)
                }
            }
            var counts: [String: Int] = [:]
            var indices: [String: [Int]] = [:]
            for (index, sector) in baseSectors.enumerated() {
                for ownerRef in sector.ownerRefs {
                    let key = Self.positionKey(forOwnerRef: ownerRef, in: sector)
                    counts[key, default: 0] += 1
                    indices[key, default: []].append(index)
                }
            }
            bookingIndexCache.positionsByPrefixAndType = byPrefixAndType
            bookingIndexCache.ownerReferenceCounts = counts
            bookingIndexCache.sectorIndicesByOwner = indices
            bookingIndexCache.signature = signature
        }

        let airportSignature = airports.count
        if airportSignature != bookingIndexCache.airportSignature {
            var byPrefix: [String: [String]] = [:]
            for airport in airports {
                for prefix in vatglassesService.callsignPrefixes(for: airport.icao) {
                    byPrefix[prefix, default: []].append(airport.icao)
                }
            }
            bookingIndexCache.airportICAOsByPrefix = byPrefix
            bookingIndexCache.airportSignature = airportSignature
        }
    }

    /// Basic-data (nodata.json) sectors list raw FIR IDs ("KZMP") while their positions are
    /// keyed "NODATA/KZMP"; every other sector already uses the position key.
    static func positionKey(forOwnerRef ownerRef: String, in sector: VatglassesSector) -> String {
        guard sector.isBasicDataOnly, !ownerRef.hasPrefix("NODATA/") else { return ownerRef }
        return "NODATA/\(ownerRef.uppercased())"
    }

    // MARK: - Resolution

    func resolveBookedPositions(_ bookings: [AtcBooking]) -> BookedPositionResolution {
        var resolution = BookedPositionResolution()
        for booking in bookings {
            let (keys, approximate) = positionKeys(for: booking)
            guard !keys.isEmpty else { continue }
            if approximate { resolution.approximateBookingIDs.insert(booking.id) }
            for key in keys {
                if let existing = resolution.byPosition[key], existing.start <= booking.start { continue }
                resolution.byPosition[key] = booking
            }
        }
        return resolution
    }

    /// The VATGlasses position keys a booked callsign will staff (see the file header).
    func positionKeys(for booking: AtcBooking) -> (keys: [String], approximate: Bool) {
        if let learned = learnedPositions.keys(for: booking.callsign) {
            let valid = learned.filter { allPositions[$0] != nil }
            if !valid.isEmpty { return (valid, false) }
        }
        return Self.heuristicPositionKeys(
            for: booking,
            positionsByPrefixAndType: bookingIndexCache.positionsByPrefixAndType,
            ownerReferenceCounts: bookingIndexCache.ownerReferenceCounts
        )
    }

    /// Steps 2–5 of the resolution order. Pure, so it can be tested in isolation.
    static func heuristicPositionKeys(
        for booking: AtcBooking,
        positionsByPrefixAndType: [String: [String]],
        ownerReferenceCounts: [String: Int]
    ) -> (keys: [String], approximate: Bool) {
        let type = booking.facilitySuffix
        guard !type.isEmpty, type != "ATIS",
              let candidates = positionsByPrefixAndType["\(booking.callsignPrefix)|\(type)"],
              !candidates.isEmpty else { return ([], false) }

        if candidates.count == 1 { return (candidates, false) }

        func bandbox() -> [String] {
            let best = candidates.map { ownerReferenceCounts[$0] ?? 0 }.max() ?? 0
            return best > 0 ? candidates.filter { (ownerReferenceCounts[$0] ?? 0) == best } : []
        }

        // Mentor/trainee infixes don't identify a position.
        var middle = booking.middleComponent
        if middle == "X" || middle == "T" { middle = "" }

        if middle.isEmpty { return (bandbox(), false) }

        let matched = matchPositions(candidates, middle: middle, prefix: booking.callsignPrefix, type: type)
        if !matched.isEmpty { return (matched, false) }
        let fallback = bandbox()
        return (fallback, !fallback.isEmpty)
    }

    /// Picks the position(s) a split callsign refers to. VATGlasses IDs are either the middle
    /// component itself (EDMM_ALB_CTR → "ALB") or an ICAO fragment plus the middle
    /// (EDDM_ND_APP → "DMND", EGLL_N_APP → "LLN", LON_S_CTR → "LS", EGCC_N_TWR → "CCTN").
    /// Returns nothing when it can't tell.
    static func matchPositions(_ candidates: [String], middle: String, prefix: String, type: String) -> [String] {
        func positionID(_ key: String) -> String {
            key.split(separator: "/").last.map { String($0).uppercased() } ?? ""
        }

        let exact = candidates.filter { positionID($0) == middle }
        if !exact.isEmpty { return exact }

        func isFragment(_ lead: Substring) -> Bool {
            if lead.isEmpty || prefix.hasSuffix(lead) || prefix.hasPrefix(lead) { return true }
            // Fragment + first letter of the type, e.g. "CC" + "T" for EGCC tower.
            guard lead.count >= 2, lead.last == type.first else { return false }
            let core = lead.dropLast()
            return prefix.hasSuffix(core) || prefix.hasPrefix(core)
        }

        let patterned: [(key: String, leadLength: Int)] = candidates.compactMap { key in
            let id = positionID(key)
            guard id.hasSuffix(middle) else { return nil }
            let lead = id.dropLast(middle.count)
            return isFragment(lead) ? (key, lead.count) : nil
        }
        guard let shortest = patterned.map(\.leadLength).min() else { return [] }
        return patterned.filter { $0.leadLength == shortest }.map(\.key)
    }

    // MARK: - Booked Sectors

    private func updateBookedSectors(pending: [AtcBooking]) {
        guard eventOverlay.showBookedSectors, !bookedPositionIndex.isEmpty || pending.contains(where: \.isApproachPosition) else {
            assignBookedSectors([])
            return
        }

        let baseSectors = vatglassesService.getCachedSectors()
        let liveByID: [String: Bool] = Dictionary(
            sectors.map { ($0.id, $0.isActive) },
            uniquingKeysWith: { a, b in a || b }
        )

        // Candidate sectors: only those listing a booked position (cheap inverted lookup).
        var candidateIndices = Set<Int>()
        for positionKey in bookedPositionIndex.keys {
            for index in bookingIndexCache.sectorIndicesByOwner[positionKey] ?? [] {
                candidateIndices.insert(index)
            }
        }

        var result: [BookedSector] = []
        var bookedApproachICAOs = Set<String>()
        for index in candidateIndices.sorted() where index < baseSectors.count {
            let sector = baseSectors[index]
            guard liveByID[sector.id] != true else { continue } // already staffed
            // First booked owner in the chain wins, as with live top-down ownership.
            for ownerRef in sector.ownerRefs {
                guard let booking = bookedPositionIndex[Self.positionKey(forOwnerRef: ownerRef, in: sector)] else { continue }
                result.append(BookedSector(sector: sector, booking: booking))
                if booking.isApproachPosition { bookedApproachICAOs.insert(booking.callsignPrefix) }
                break
            }
        }

        // Approach bookings without VATGlasses airspace get the same 15 nm circle as live
        // synthetic sectors, unless live approach coverage already exists there.
        var liveApproachICAOs = Set<String>()
        for sector in sectors where sector.isActive {
            guard let callsign = sector.activeController?.callsign.uppercased(),
                  callsign.hasSuffix("_APP") || callsign.hasSuffix("_DEP") else { continue }
            liveApproachICAOs.insert(String(callsign.prefix { $0 != "_" }))
        }
        var airportByICAO: [String: VatglassesAirport] = [:]
        var seenSynthetic = Set<String>()
        for booking in pending where booking.isApproachPosition {
            let icao = booking.callsignPrefix
            guard !bookedApproachICAOs.contains(icao), !liveApproachICAOs.contains(icao),
                  seenSynthetic.insert(icao).inserted else { continue }
            if airportByICAO.isEmpty {
                airportByICAO = Dictionary(airports.map { ($0.icao.uppercased(), $0) }, uniquingKeysWith: { a, _ in a })
            }
            guard let airport = airportByICAO[icao],
                  abs(airport.latitude) <= 90, abs(airport.longitude) <= 180 else { continue }
            let geometry = SectorGeoJSON.circleGeometry(
                centre: CLLocationCoordinate2D(latitude: airport.latitude, longitude: airport.longitude),
                radiusNm: 15
            )
            let sector = VatglassesSector(
                id: "BOOKED/\(booking.callsign)",
                ownerRefs: [],
                frequency: "",
                geometry: geometry,
                properties: SectorProperties(min: 20, max: 200, name: "\(icao) APP (Synthetic)", groupName: nil, color: nil),
                isBasicDataOnly: true,
                isSynthetic: true
            )
            result.append(BookedSector(sector: sector, booking: booking))
        }

        assignBookedSectors(result)
    }

    private func assignBookedSectors(_ result: [BookedSector]) {
        let approximate = approximateBookingIDs
        let signature = result.map { "\($0.sector.id)#\($0.booking.id)\(approximate.contains($0.booking.id) ? "~" : "")" }
        guard signature != bookedSectorsSignature else { return }
        bookedSectorsSignature = signature
        bookedSectors = result
    }

    // MARK: - Event Context

    /// Map-derived lookups the Events screens need, without them observing this view model.
    func eventMapContext(onShowAirport: ((String) -> Void)?) -> EventMapContext {
        EventMapContext(
            onShowAirport: onShowAirport,
            airportName: { [weak self] in self?.airportName(for: $0) },
            canShowAirport: { [weak self] icao in
                self?.airports.contains { $0.icao.uppercased() == icao.uppercased() } ?? false
            },
            positionLabel: { [weak self] in self?.resolvePositionLabel(for: $0) },
            bookings: { [weak self] event, all in self?.bookings(for: event, from: all) ?? [] }
        )
    }
}

extension AtcBooking {
    var isApproachPosition: Bool { facilitySuffix == "APP" || facilitySuffix == "DEP" }
}

/// Lookups that Events views borrow from the map without observing RadarViewModel
/// (which republishes every refresh).
struct EventMapContext {
    /// Switches to the map and selects the airport. Nil hides "Show on Map".
    var onShowAirport: ((String) -> Void)? = nil
    var airportName: (String) -> String? = { _ in nil }
    var canShowAirport: (String) -> Bool = { _ in false }
    var positionLabel: (String) -> String? = { _ in nil }
    /// (event, all bookings) → the bookings for that event.
    var bookings: (VatsimEvent, [AtcBooking]) -> [AtcBooking] = { _, _ in [] }
}
