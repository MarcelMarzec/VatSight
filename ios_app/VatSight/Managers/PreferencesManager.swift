//
//  PreferencesManager.swift
//  VatSight
//
//  Created by Marcel Marzec on 14/05/2026.
//


import SwiftUI
import SwiftData

@Observable
final class PreferencesManager {

    private let context: ModelContext

    var userPrefs: UserPreferencesModel

    init(context: ModelContext) {
        self.context = context

        let descriptor = FetchDescriptor<UserPreferencesModel>()

        do {
            let results = try context.fetch(descriptor)

            if let existing = results.first {
                self.userPrefs = existing
                if existing.vatsimRefreshRate.isEmpty {
                    existing.vatsimRefreshRate = "15s"
                    try? context.save()
                }
            } else {
                let new = UserPreferencesModel()
                context.insert(new)
                try context.save()
                self.userPrefs = new
            }
        } catch {
            let new = UserPreferencesModel()
            context.insert(new)
            try? context.save()
            self.userPrefs = new
        }
    }

    func updateCID(_ cid: Int) {
        userPrefs.vatsimCID = cid
        try? context.save()
    }

    func updateRefreshRate(_ rate: String) {
        userPrefs.vatsimRefreshRate = rate
        try? context.save()
    }
    
    func updateShowInactiveSectors(_ value: Bool) {
        userPrefs.showInactiveSectors = value
        try? context.save()
    }

    func updateShowAirports(_ value: Bool) {
        userPrefs.showAirports = value
        try? context.save()
    }

    func updateShowPilotsLayer(_ value: Bool) {
        userPrefs.showPilotsLayer = value
        try? context.save()
    }

    func updateShowSectorsLayer(_ value: Bool) {
        userPrefs.showSectorsLayer = value
        try? context.save()
    }

    func updateShowAirportLayer(_ value: Bool) {
        userPrefs.showAirportLayer = value
        try? context.save()
    }

    func updateAltitudeFilterEnabled(_ value: Bool) {
        userPrefs.altitudeFilterEnabled = value
        try? context.save()
    }

    func updateMergeSectors(_ value: Bool) {
        userPrefs.mergeSectors = value
        try? context.save()
    }

    // MARK: - Tracked CIDs

    func addTrackedCID(_ cid: Int) {
        guard !userPrefs.trackedCIDs.contains(cid) else { return }
        userPrefs.trackedCIDs.append(cid)
        try? context.save()
    }

    func incrementSwipeToTrackHint() {
        userPrefs.swipeToTrackHintCount += 1
        try? context.save()
    }

    var shouldShowSwipeToTrackHint: Bool {
        userPrefs.swipeToTrackHintCount < 3
    }

    func removeTrackedCID(_ cid: Int) {
        userPrefs.trackedCIDs.removeAll { $0 == cid }
        try? context.save()
    }

    /// The user's own VATSIM CID (0 if not set).
    var myCID: Int { userPrefs.vatsimCID }

    /// All CIDs that should be treated as "friends" on the map:
    /// explicitly tracked CIDs only. The user's own CID is handled separately
    /// as the "self" state so it renders in gold rather than green.
    var allFriendCIDs: Set<Int> {
        Set(userPrefs.trackedCIDs)
    }

    func updateDeveloperMode(_ enabled: Bool) {
        userPrefs.developerModeEnabled = enabled
        try? context.save()
    }

    func updateVatglassesCustomRepo(_ slug: String) {
        userPrefs.vatglassesCustomRepoSlug = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        try? context.save()
    }

    /// True when a custom Vatglasses repo is configured AND developer mode is enabled.
    var isUsingCustomVatglassesRepo: Bool {
        userPrefs.developerModeEnabled && !userPrefs.vatglassesCustomRepoSlug.isEmpty
    }

    func updatePlaneIconMultiplier(_ multiplier: Double) {
        userPrefs.planeIconMultiplier = multiplier
        try? context.save()
    }

    func updateAirportIconMultiplier(_ multiplier: Double) {
        userPrefs.airportIconMultiplier = multiplier
        try? context.save()
    }

    func updateMapStyle(_ style: MapStyle) {
        userPrefs.mapStyle = style
        try? context.save()
    }

    func updateAppTheme(_ theme: AppTheme) {
        userPrefs.appTheme = theme
        try? context.save()
    }

    func markOnboardingComplete() {
        userPrefs.hasCompletedOnboarding = true
        try? context.save()
    }

    // MARK: - Search Filters

    func updateSearchSelectedFacilities(_ ids: Set<Int>) {
        userPrefs.searchSelectedFacilities = Array(ids)
        try? context.save()
    }

    func updateSearchExcludedFacilities(_ ids: Set<Int>) {
        userPrefs.searchExcludedFacilities = Array(ids)
        try? context.save()
    }

    func updateSearchCategory(_ rawValue: String) {
        userPrefs.searchCategoryRaw = rawValue
        try? context.save()
    }

    func updateSearchShowInactiveAirports(_ value: Bool) {
        userPrefs.searchShowInactiveAirports = value
        try? context.save()
    }

    func getRefreshIntervalInSeconds() -> TimeInterval {
        let rateString = userPrefs.vatsimRefreshRate
        
        if rateString.hasSuffix("min") {
            let numberString = rateString.replacingOccurrences(of: "min", with: "")
            let minutes = Int(numberString) ?? 1
            return TimeInterval(minutes * 60)
        } else {
            let numberString = rateString.replacingOccurrences(of: "s", with: "")
            return TimeInterval(Int(numberString) ?? 15)
        }
    }
}
