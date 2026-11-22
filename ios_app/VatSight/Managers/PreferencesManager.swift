//
//  PreferencesManager.swift
//  VatSight
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

    // MARK: - Friends

    func addFriend(_ cid: Int) {
        guard !userPrefs.friendCIDs.contains(cid) else { return }
        userPrefs.friendCIDs.append(cid)
        try? context.save()
    }

    func incrementSwipeToAddFriendHint() {
        userPrefs.swipeToAddFriendHintCount += 1
        try? context.save()
    }

    var shouldShowSwipeToAddFriendHint: Bool {
        userPrefs.swipeToAddFriendHintCount < 3
    }

    func removeFriend(_ cid: Int) {
        userPrefs.friendCIDs.removeAll { $0 == cid }
        try? context.save()
    }

    /// The user's own VATSIM CID (0 if not set).
    var myCID: Int { userPrefs.vatsimCID }

    /// Friend CIDs. Own CID is handled separately (renders gold, not green).
    var allFriendCIDs: Set<Int> {
        Set(userPrefs.friendCIDs)
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

    func updateHapticFeedbackEnabled(_ value: Bool) {
        userPrefs.hapticFeedbackEnabled = value
        try? context.save()
    }

    // MARK: - Ads

    func updateAdsEnabled(_ value: Bool) {
        userPrefs.adsEnabled = value
        try? context.save()
    }

    func updateNativeAdsEnabled(_ value: Bool) {
        userPrefs.nativeAdsEnabled = value
        try? context.save()
    }

    func updateRewardedAdsEnabled(_ value: Bool) {
        userPrefs.rewardedAdsEnabled = value
        try? context.save()
    }

    func updateAppOpenAdsEnabled(_ value: Bool) {
        userPrefs.appOpenAdsEnabled = value
        try? context.save()
    }

    func incrementAdsViewed() {
        userPrefs.adsViewedCount += 1
        try? context.save()
    }

    // MARK: - Engagement Prompts

    func recordLaunch() {
        userPrefs.launchCount += 1
        if userPrefs.firstLaunchDate == nil { userPrefs.firstLaunchDate = Date() }
        try? context.save()
    }

    func incrementDetailViewCount() {
        userPrefs.detailViewCount += 1
        try? context.save()
    }

    func recordReviewRequest(version: String) {
        userPrefs.lastReviewRequestVersion = version
        userPrefs.lastReviewRequestDate = Date()
        try? context.save()
    }

    func recordSupportPromptShown() {
        userPrefs.supportPromptCount += 1
        userPrefs.lastSupportPromptDate = Date()
        try? context.save()
    }

    func optOutOfSupportPrompt() {
        userPrefs.supportPromptOptedOut = true
        try? context.save()
    }

    // MARK: - Events & Bookings

    func updateUpcomingEventWindowHours(_ hours: Int) {
        userPrefs.upcomingEventWindowHours = hours
        try? context.save()
    }

    func updateUpcomingBookingWindowHours(_ hours: Int) {
        userPrefs.upcomingBookingWindowHours = hours
        try? context.save()
    }

    func updateShowEventAirportHighlights(_ value: Bool) {
        userPrefs.showEventAirportHighlights = value
        try? context.save()
    }

    func updateShowBookingAirportHighlights(_ value: Bool) {
        userPrefs.showBookingAirportHighlights = value
        try? context.save()
    }

    func updateShowBookedSectors(_ value: Bool) {
        userPrefs.showBookedSectors = value
        try? context.save()
    }

    func updateEventTimeDisplay(_ value: EventTimeDisplay) {
        userPrefs.eventTimeDisplay = value
        try? context.save()
    }

    func updateEventsViewMode(_ value: EventsViewMode) {
        userPrefs.eventsViewMode = value
        try? context.save()
    }

    /// The Events tab filter as last chosen by the user.
    var eventFilter: EventFilter {
        EventFilter(
            types: Set(userPrefs.eventFilterTypes.map(VatsimEventType.init(rawValue:))),
            region: userPrefs.eventFilterRegion.isEmpty ? nil : userPrefs.eventFilterRegion,
            division: userPrefs.eventFilterDivision.isEmpty ? nil : userPrefs.eventFilterDivision,
            vatsimOrganisedOnly: userPrefs.eventFilterVatsimOnly
        )
    }

    func updateEventFilter(_ filter: EventFilter) {
        userPrefs.eventFilterTypes = filter.types.map(\.rawValue).sorted()
        userPrefs.eventFilterRegion = filter.region ?? ""
        userPrefs.eventFilterDivision = filter.division ?? ""
        userPrefs.eventFilterVatsimOnly = filter.vatsimOrganisedOnly
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
