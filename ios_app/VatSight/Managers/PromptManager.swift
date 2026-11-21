//
//  PromptManager.swift
//  VatSight
//

import Foundation

/// Decides when to ask for an App Store review or show the Support VatSight prompt.
/// Both wait until the user has clearly found the app useful, and at most one is shown per launch.
@Observable
final class PromptManager {

    enum Prompt { case review, support }

    // MARK: - Configuration

    private enum Review {
        static let minLaunches = 4
        static let minDaysSinceFirstLaunch = 3.0
        static let minDetailViews = 10
        static let minDaysBetweenRequests = 120.0 // iOS also caps the system prompt at 3 a year
    }

    private enum Support {
        static let minLaunches = 8
        static let minDaysSinceFirstLaunch = 7.0
        static let minDetailViews = 25
        static let minDaysBetweenPrompts = 30.0
        static let maxPrompts = 3
        static let minDaysAfterReviewRequest = 3.0
    }

    private let prefs: PreferencesManager
    @ObservationIgnored private var hasPromptedThisLaunch = false

    init(prefs: PreferencesManager) {
        self.prefs = prefs
    }

    private var settings: UserPreferencesModel { prefs.userPrefs }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    // MARK: - Events

    func recordLaunch() {
        prefs.recordLaunch()
    }

    /// Called when a pilot, airport or sector sheet is closed: the moment after a successful lookup.
    func recordDetailViewed() {
        prefs.incrementDetailViewCount()
    }

    // MARK: - Decision

    /// The prompt to show now, if any. Marks it as shown, so call it only when it will be presented.
    func nextPrompt() -> Prompt? {
        guard !hasPromptedThisLaunch, settings.hasCompletedOnboarding else { return nil }

        let prompt: Prompt? = if isReviewDue { .review } else if isSupportPromptDue { .support } else { nil }
        switch prompt {
        case .review: prefs.recordReviewRequest(version: appVersion)
        case .support: prefs.recordSupportPromptShown()
        case nil: return nil
        }
        hasPromptedThisLaunch = true
        return prompt
    }

    private var isReviewDue: Bool {
        settings.launchCount >= Review.minLaunches
            && daysSince(settings.firstLaunchDate) >= Review.minDaysSinceFirstLaunch
            && settings.detailViewCount >= Review.minDetailViews
            && settings.lastReviewRequestVersion != appVersion
            && daysSince(settings.lastReviewRequestDate) >= Review.minDaysBetweenRequests
    }

    private var isSupportPromptDue: Bool {
        AdsManager.isConfigured
            && !settings.adsEnabled
            && !settings.supportPromptOptedOut
            && settings.supportPromptCount < Support.maxPrompts
            && settings.launchCount >= Support.minLaunches
            && daysSince(settings.firstLaunchDate) >= Support.minDaysSinceFirstLaunch
            && settings.detailViewCount >= Support.minDetailViews
            && daysSince(settings.lastSupportPromptDate) >= Support.minDaysBetweenPrompts
            && daysSince(settings.lastReviewRequestDate) >= Support.minDaysAfterReviewRequest
    }

    /// Days since `date`, or infinity when it never happened.
    private func daysSince(_ date: Date?) -> Double {
        guard let date else { return .infinity }
        return Date().timeIntervalSince(date) / 86_400
    }
}
