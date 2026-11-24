//
//  AdsManager.swift
//  VatSight
//

import SwiftUI
import GoogleMobileAds
import UserMessagingPlatform
import AppTrackingTransparency

/// Owns all optional ads. The Google SDK is only started once the user has opted in.
@Observable
final class AdsManager: NSObject {

    // MARK: - Configuration

    private enum AdUnit {
        // Debug builds always use Google's test units so real ads are never served or clicked during development
        #if DEBUG
        static let native = "ca-app-pub-3940256099942544/3986624511"
        static let rewarded = "ca-app-pub-3940256099942544/1712485313"
        static let appOpen = "ca-app-pub-3940256099942544/5575463023"
        static let eventListNative = "ca-app-pub-3940256099942544/3986624511"
        static let eventBanner = "ca-app-pub-3940256099942544/2435281174"
        static let searchBanner = "ca-app-pub-3940256099942544/2435281174"
        #else
        static let native = infoValue("VSAdUnitNative")
        static let rewarded = infoValue("VSAdUnitRewarded")
        static let appOpen = infoValue("VSAdUnitAppOpen")
        static let eventListNative = infoValue("VSAdUnitEventListNative")
        static let eventBanner = infoValue("VSAdUnitEventBanner")
        static let searchBanner = infoValue("VSAdUnitSearchBanner")
        #endif

        static func infoValue(_ key: String) -> String {
            Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
        }

        static var allConfigured: Bool {
            [infoValue("GADApplicationIdentifier"), native, rewarded, appOpen].allSatisfy(isValid)
        }

        static func isValid(_ unit: String) -> Bool { unit.hasPrefix("ca-app-pub-") }
    }

    enum BannerPlacement {
        case eventDetail, search

        fileprivate var adUnitID: String {
            switch self {
            case .eventDetail: return AdUnit.eventBanner
            case .search: return AdUnit.searchBanner
            }
        }
    }

    private static let eventListAdCount = 5

    /// False when the AdMob IDs are missing from Secrets.xcconfig (e.g. a fork of the public repo).
    static let isConfigured = AdUnit.allConfigured

    private static let adExpiry: TimeInterval = 3600 // native ads go stale after 1h
    private static let appOpenExpiry: TimeInterval = 4 * 3600
    private static let appOpenCooldown: TimeInterval = 4 * 3600
    private static let coldLaunchTimeout: TimeInterval = 3

    // MARK: - State

    struct RewardedSession {
        enum Phase { case loading, showing, between, finished, failed }
        let id = UUID()
        let total: Int
        var watched = 0
        var phase: Phase = .loading
    }

    private let prefs: PreferencesManager

    private(set) var isReady = false
    private(set) var isEnabling = false
    private(set) var privacyOptionsRequired = false
    private(set) var nativeAd: NativeAd?
    /// Shown between cards in the Events list, cycling through them.
    private(set) var eventListAds: [NativeAd] = []
    private(set) var rewardedSession: RewardedSession?

    @ObservationIgnored private var adLoader: AdLoader?
    @ObservationIgnored private var nativeAdLoadedAt: Date?
    @ObservationIgnored private var eventListAdLoader: AdLoader?
    @ObservationIgnored private var eventListAdsLoadedAt: Date?
    @ObservationIgnored private var pendingEventListAds: [NativeAd] = []
    @ObservationIgnored private var nextRewardedAd: RewardedAd?
    @ObservationIgnored private var appOpenAd: AppOpenAd?
    @ObservationIgnored private var appOpenLoadedAt: Date?
    @ObservationIgnored private var lastAppOpenShownAt: Date?
    @ObservationIgnored private var isLoadingAppOpen = false
    @ObservationIgnored private var showAppOpenDeadline: Date?
    @ObservationIgnored private var isShowingFullScreenAd = false

    init(prefs: PreferencesManager) {
        self.prefs = prefs
        super.init()
    }

    private var settings: UserPreferencesModel { prefs.userPrefs }

    var isActive: Bool { Self.isConfigured && settings.adsEnabled && isReady }

    /// Ad unit for a banner placement, or nil when that banner is switched off or not configured.
    func bannerAdUnitID(for placement: BannerPlacement) -> String? {
        let enabled = switch placement {
        case .eventDetail: settings.eventDetailAdsEnabled
        case .search: settings.searchAdsEnabled
        }
        guard isActive, enabled, AdUnit.isValid(placement.adUnitID) else { return nil }
        return placement.adUnitID
    }

    // MARK: - Lifecycle

    /// Called on launch. Does nothing unless the user has already opted in.
    func startIfOptedIn() async {
        guard Self.isConfigured, settings.adsEnabled, !isReady else { return }
        await gatherConsentAndStart(promptForTracking: false)
    }

    /// Called when the user turns ads on. Shows the consent form (UK/EEA) and the ATT prompt.
    func enable() async {
        guard Self.isConfigured else { return }
        prefs.updateAdsEnabled(true)
        guard !isReady else { return }
        isEnabling = true
        await gatherConsentAndStart(promptForTracking: true)
        isEnabling = false
    }

    func disable() {
        prefs.updateAdsEnabled(false)
        nativeAd = nil
        nativeAdLoadedAt = nil
        eventListAds = []
        eventListAdsLoadedAt = nil
        appOpenAd = nil
        nextRewardedAd = nil
        rewardedSession = nil
    }

    /// Drops or preloads ads after a per-type toggle changes.
    func applyAdTypeSettings() {
        if settings.nativeAdsEnabled {
            loadNativeAdIfNeeded()
        } else {
            nativeAd = nil
            nativeAdLoadedAt = nil
        }
        if settings.eventListAdsEnabled {
            loadEventListAdsIfNeeded()
        } else {
            eventListAds = []
            eventListAdsLoadedAt = nil
        }
        if settings.appOpenAdsEnabled {
            loadAppOpenAd()
        } else {
            appOpenAd = nil
        }
        if !settings.rewardedAdsEnabled { endRewardedSession() }
    }

    private func gatherConsentAndStart(promptForTracking: Bool) async {
        let consent = ConsentInformation.shared
        do {
            try await consent.requestConsentInfoUpdate(with: RequestParameters())
            try await ConsentForm.loadAndPresentIfRequired(from: Self.topViewController())
        } catch {
            print("[Ads] Consent error: \(error.localizedDescription)")
        }
        privacyOptionsRequired = consent.privacyOptionsRequirementStatus == .required

        if promptForTracking, ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }

        guard consent.canRequestAds else { return }
        await MobileAds.shared.start()
        isReady = true
        applyAdTypeSettings()
    }

    func presentPrivacyOptions() async {
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: Self.topViewController())
        } catch {
            print("[Ads] Privacy options error: \(error.localizedDescription)")
        }
    }

    // MARK: - Native

    func loadNativeAdIfNeeded() {
        guard isActive, settings.nativeAdsEnabled, adLoader == nil else { return }
        if let loadedAt = nativeAdLoadedAt, Date().timeIntervalSince(loadedAt) < Self.adExpiry { return }

        let mediaOptions = NativeAdMediaAdLoaderOptions()
        mediaOptions.mediaAspectRatio = .square
        let loader = AdLoader(adUnitID: AdUnit.native, rootViewController: nil, adTypes: [.native], options: [mediaOptions])
        loader.delegate = self
        adLoader = loader
        loader.load(Request())
    }

    func loadEventListAdsIfNeeded() {
        guard isActive, settings.eventListAdsEnabled, eventListAdLoader == nil,
              AdUnit.isValid(AdUnit.eventListNative) else { return }
        if let loadedAt = eventListAdsLoadedAt, Date().timeIntervalSince(loadedAt) < Self.adExpiry { return }

        let mediaOptions = NativeAdMediaAdLoaderOptions()
        mediaOptions.mediaAspectRatio = .square
        let multipleOptions = MultipleAdsAdLoaderOptions()
        multipleOptions.numberOfAds = Self.eventListAdCount
        let loader = AdLoader(
            adUnitID: AdUnit.eventListNative,
            rootViewController: nil,
            adTypes: [.native],
            options: [mediaOptions, multipleOptions]
        )
        loader.delegate = self
        pendingEventListAds = []
        eventListAdLoader = loader
        loader.load(Request())
    }

    // MARK: - Rewarded

    func startRewardedSession(count: Int) {
        guard isActive, settings.rewardedAdsEnabled, rewardedSession == nil else { return }
        rewardedSession = RewardedSession(total: count)
        showNextRewardedAd()
    }

    func continueRewardedSession() {
        guard rewardedSession?.phase == .between else { return }
        showNextRewardedAd()
    }

    func endRewardedSession() {
        rewardedSession = nil
        nextRewardedAd = nil
    }

    private func showNextRewardedAd() {
        guard let sessionID = rewardedSession?.id else { return }
        rewardedSession?.phase = .loading
        Task {
            let ad: RewardedAd
            if let preloaded = nextRewardedAd {
                ad = preloaded
                nextRewardedAd = nil
            } else {
                do {
                    ad = try await RewardedAd.load(with: AdUnit.rewarded, request: Request())
                } catch {
                    print("[Ads] Rewarded load failed: \(error.localizedDescription)")
                    if rewardedSession?.id == sessionID { rewardedSession?.phase = .failed }
                    return
                }
            }
            // The user may have stopped the session while the ad was loading
            guard rewardedSession?.id == sessionID else { return }
            ad.fullScreenContentDelegate = self
            rewardedSession?.phase = .showing
            isShowingFullScreenAd = true
            ad.present(from: Self.topViewController()) {}
        }
    }

    private func preloadNextRewardedAd() {
        Task {
            nextRewardedAd = try? await RewardedAd.load(with: AdUnit.rewarded, request: Request())
        }
    }

    // MARK: - App Open

    /// Shows an App Open ad on cold launch, or when returning from the background after the cooldown.
    func handleAppBecameActive(isColdLaunch: Bool) {
        guard isActive, settings.appOpenAdsEnabled, settings.hasCompletedOnboarding,
              !isShowingFullScreenAd, rewardedSession == nil else { return }

        if !isColdLaunch, let lastShown = lastAppOpenShownAt,
           Date().timeIntervalSince(lastShown) < Self.appOpenCooldown {
            return
        }

        if isAppOpenAdFresh {
            showAppOpenAd()
        } else {
            // A load may already be in flight from SDK start-up, so show it when it lands rather than chaining a second load
            if isColdLaunch { showAppOpenDeadline = Date().addingTimeInterval(Self.coldLaunchTimeout) }
            loadAppOpenAd()
        }
    }

    private var isAppOpenAdFresh: Bool {
        guard appOpenAd != nil, let loadedAt = appOpenLoadedAt else { return false }
        return Date().timeIntervalSince(loadedAt) < Self.appOpenExpiry
    }

    private func loadAppOpenAd() {
        guard isActive, settings.appOpenAdsEnabled, !isLoadingAppOpen, !isAppOpenAdFresh else { return }
        isLoadingAppOpen = true
        Task {
            defer { isLoadingAppOpen = false }
            do {
                let ad = try await AppOpenAd.load(with: AdUnit.appOpen, request: Request())
                ad.fullScreenContentDelegate = self
                appOpenAd = ad
                appOpenLoadedAt = Date()
                if let deadline = showAppOpenDeadline, Date() < deadline { showAppOpenAd() }
                showAppOpenDeadline = nil
            } catch {
                showAppOpenDeadline = nil
                print("[Ads] App Open load failed: \(error.localizedDescription)")
            }
        }
    }

    private func showAppOpenAd() {
        guard let ad = appOpenAd, !isShowingFullScreenAd else { return }
        appOpenAd = nil
        isShowingFullScreenAd = true
        lastAppOpenShownAt = Date()
        ad.present(from: Self.topViewController())
    }

    // MARK: - Helpers

    func recordBannerImpression() {
        prefs.incrementAdsViewed()
    }

    /// Full-screen ads must be presented from the top-most controller or they fail while a sheet is open.
    static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive } ?? UIApplication.shared.connectedScenes.first as? UIWindowScene
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}

// MARK: - NativeAdLoaderDelegate

extension AdsManager: NativeAdLoaderDelegate, NativeAdDelegate {
    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        nativeAd.delegate = self
        if adLoader === eventListAdLoader {
            pendingEventListAds.append(nativeAd)
            return
        }
        self.nativeAd = nativeAd
        nativeAdLoadedAt = Date()
        self.adLoader = nil
    }

    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: any Error) {
        print("[Ads] Native load failed: \(error.localizedDescription)")
        if adLoader === eventListAdLoader {
            finishEventListLoad()
        } else {
            self.adLoader = nil
        }
    }

    func adLoaderDidFinishLoading(_ adLoader: AdLoader) {
        if adLoader === eventListAdLoader { finishEventListLoad() }
    }

    private func finishEventListLoad() {
        if !pendingEventListAds.isEmpty {
            eventListAds = pendingEventListAds
            eventListAdsLoadedAt = Date()
        }
        pendingEventListAds = []
        eventListAdLoader = nil
    }

    func nativeAdDidRecordImpression(_ nativeAd: NativeAd) {
        prefs.incrementAdsViewed()
    }
}

// MARK: - FullScreenContentDelegate

extension AdsManager: FullScreenContentDelegate {
    func adDidRecordImpression(_ ad: any FullScreenPresentingAd) {
        prefs.incrementAdsViewed()
    }

    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        isShowingFullScreenAd = false
        if ad is RewardedAd {
            advanceRewardedSession()
        } else if ad is AppOpenAd {
            loadAppOpenAd()
        }
    }

    func ad(_ ad: any FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: any Error) {
        print("[Ads] Present failed: \(error.localizedDescription)")
        isShowingFullScreenAd = false
        if ad is RewardedAd {
            rewardedSession?.phase = .failed
        } else if ad is AppOpenAd {
            loadAppOpenAd()
        }
    }

    private func advanceRewardedSession() {
        guard var session = rewardedSession else { return }
        session.watched += 1
        if session.watched < session.total {
            session.phase = .between
            preloadNextRewardedAd()
        } else {
            session.phase = .finished
        }
        rewardedSession = session
    }
}
