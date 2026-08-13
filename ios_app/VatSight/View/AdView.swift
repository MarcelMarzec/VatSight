//
//  AdView.swift
//  VatSight
//
//  Created by Marcel Marzec on 30/07/2026.
//

import SwiftUI

// MARK: - Ad Provider Protocol
// Implement this protocol to swap in a real ad SDK (e.g. Google AdMob rewarded ads)
protocol AdProvider {
    /// Returns true if a rewarded ad is ready to show
    var isAdReady: Bool { get }
    /// Load an ad in preparation for showing it
    func loadAd() async
    /// Show a rewarded ad. Calls onRewarded when the user earns the reward.
    func showAd(onRewarded: @escaping () -> Void) async
}

// MARK: - Simulated Ad Provider
// Replace this class with a real AdMob / other SDK implementation
final class SimulatedAdProvider: AdProvider {
    var isAdReady: Bool = true

    func loadAd() async {
        // Simulate network fetch delay
        try? await Task.sleep(for: .seconds(1))
        isAdReady = true
    }

    func showAd(onRewarded: @escaping () -> Void) async {
        // Simulate a 5-second ad playback
        try? await Task.sleep(for: .seconds(5))
        onRewarded()
    }
}

// MARK: - Ad Count Option
enum AdCount: Int, CaseIterable, Identifiable {
    case one = 1
    case two = 2
    case five = 5

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .one:  return "Watch 1 Ad"
        case .two:  return "Watch 2 Ads"
        case .five: return "Watch 5 Ads"
        }
    }

    var icon: String {
        switch self {
        case .one:  return "play.circle"
        case .two:  return "play.circle.fill"
        case .five: return "star.circle.fill"
        }
    }

    var description: String {
        switch self {
        case .one:  return "A quick way to show your support"
        case .two:  return "Double the support, double the thanks!"
        case .five: return "You're a VatSight superstar!"
        }
    }
}

// MARK: - Playback State
private enum PlaybackState {
    case idle
    case playing
    case betweenAds   // shown after each ad except the last, offering exit or continue
    case finished     // shown after all ads in the batch are done
}

// MARK: - AdView
struct AdView: View {
    @Environment(PreferencesManager.self) private var prefsManager

    // Swap SimulatedAdProvider() for your real SDK provider here
    private let adProvider: AdProvider = SimulatedAdProvider()

    @State private var playbackState: PlaybackState = .idle
    @State private var adsWatchedThisSession = 0
    @State private var totalAdsToWatch = 0
    @State private var currentAdProgress: Double = 0
    @State private var adTask: Task<Void, Never>? = nil
    @State private var progressTimer: Timer? = nil

    // Duration must match SimulatedAdProvider.showAd sleep duration
    private let adDurationSeconds: Double = 5

    var body: some View {
        Group {
            switch playbackState {
            case .idle:
                selectionView
            case .playing:
                adPlaybackView
            case .betweenAds:
                betweenAdsView
            case .finished:
                thankYouView
            }
        }
        .navigationTitle("Support for Free")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Selection View
    private var selectionView: some View {
        List {
            // Hero section
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.pink)
                    Text("Support VatSight")
                        .font(.title2.bold())
                    Text("VatSight is free to use. You can support the developer by voluntarily watching a short advert — no cost to you!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }

            // All-time total counter
            Section {
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.yellow)
                    Text("Total ads watched")
                    Spacer()
                    Text("\(prefsManager.userPrefs.totalAdsWatched)")
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
            }

            // Watch options
            Section("Choose how many ads to watch") {
                ForEach(AdCount.allCases) { option in
                    Button {
                        startWatching(count: option.rawValue)
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: option.icon)
                                .font(.title2)
                                .foregroundColor(.green)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.label)
                                    .foregroundColor(.primary)
                                Text(option.description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    // MARK: - Ad Playback View
    private var adPlaybackView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Ad placeholder card
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    VStack(spacing: 16) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.secondary)
                        Text("Ad \(adsWatchedThisSession + 1) of \(totalAdsToWatch)")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Please wait…")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                )
                .frame(height: 220)
                .padding(.horizontal, 24)

            // Progress bar
            VStack(spacing: 8) {
                ProgressView(value: currentAdProgress)
                    .progressViewStyle(.linear)
                    .padding(.horizontal, 24)
                Text("\(Int((adDurationSeconds - currentAdProgress * adDurationSeconds).rounded(.up)))s remaining")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Exit is only offered between ads (more than 1 total), not mid-ad.
            // If watching a single ad there's nothing to exit early.
            if totalAdsToWatch > 1 {
                Text("You can exit after the current ad finishes.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 24)
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Between Ads View
    private var betweenAdsView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("\(adsWatchedThisSession) of \(totalAdsToWatch) ads watched")
                .font(.title3.bold())

            Text("Thanks so much! Want to keep going?")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 12) {
                Button {
                    playNextAd()
                } label: {
                    Label("Continue watching", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(role: .cancel) {
                    finishSession()
                } label: {
                    Text("Stop here — that's enough!")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Thank You View
    private var thankYouView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundColor(.green)

            Text("Thank You!")
                .font(.largeTitle.bold())

            Text(adsWatchedThisSession == 1
                 ? "You watched 1 ad — that means a lot!"
                 : "You watched \(adsWatchedThisSession) ads — you're amazing!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(.yellow)
                Text("All-time total: \(prefsManager.userPrefs.totalAdsWatched) ads")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    // Keep watching — go straight back to selection
                    adsWatchedThisSession = 0
                    playbackState = .idle
                } label: {
                    Label("Keep watching ads", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(role: .cancel) {
                    reset()
                } label: {
                    Text("Done")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Helpers
    private func startWatching(count: Int) {
        totalAdsToWatch = count
        adsWatchedThisSession = 0
        playbackState = .playing
        playNextAd()
    }

    private func playNextAd() {
        currentAdProgress = 0
        playbackState = .playing
        startProgressTimer()

        adTask = Task {
            await adProvider.showAd {
                DispatchQueue.main.async {
                    guard !Task.isCancelled else { return }
                    stopProgressTimer()
                    adsWatchedThisSession += 1
                    prefsManager.incrementAdsWatched()

                    if adsWatchedThisSession < totalAdsToWatch {
                        // Offer exit or continue between ads
                        playbackState = .betweenAds
                    } else {
                        playbackState = .finished
                    }
                }
            }
        }
    }

    /// Called when the user taps "Stop here" between ads
    private func finishSession() {
        adTask?.cancel()
        adTask = nil
        stopProgressTimer()
        playbackState = .finished
    }

    private func startProgressTimer() {
        stopProgressTimer()
        let interval = 0.05
        let increment = interval / adDurationSeconds
        progressTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            currentAdProgress = min(currentAdProgress + increment, 1.0)
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func reset() {
        adTask?.cancel()
        adTask = nil
        stopProgressTimer()
        playbackState = .idle
        adsWatchedThisSession = 0
        totalAdsToWatch = 0
        currentAdProgress = 0
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserPreferencesModel.self, configurations: config)
    let context = ModelContext(container)

    return NavigationStack {
        AdView()
    }
    .environment(PreferencesManager(context: context))
}
