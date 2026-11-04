//
//  SupportView.swift
//  VatSight
//

import SwiftUI
import SwiftData

struct SupportView: View {
    @Environment(PreferencesManager.self) private var prefsManager
    @Environment(AdsManager.self) private var adsManager
    @ScaledMetric private var iconSize: CGFloat = 24

    private let sponsorURL = URL(string: "https://github.com/sponsors/MarcelMarzec")

    private var prefs: UserPreferencesModel { prefsManager.userPrefs }
    private var adsOn: Bool { prefs.adsEnabled && AdsManager.isConfigured }
    private var hapticsEnabled: Bool { prefs.hapticFeedbackEnabled }

    var body: some View {
        List {
            thankYouSection
            masterToggleSection
            sponsorSection

            Group {
                adTypesSection
                watchAdsSection
            }
            .disabled(!adsOn || adsManager.isEnabling)
            .opacity(adsOn ? 1 : 0.5)

            statsSection
        }
        .navigationTitle("Support VatSight")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private var thankYouSection: some View {
        Section {
            VStack(spacing: 10) {
                Image(systemName: "heart.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.pink)
                Text("Thank you!")
                    .font(.title3.bold())
                Text("VatSight is free and open source, built in my spare time. Choosing to see a few ads helps cover its running costs and keeps development going for everyone. Thank you for supporting me and the project. It means a lot.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private var masterToggleSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { adsOn },
                set: { newValue in
                    HapticManager.impact(prefsEnabled: hapticsEnabled)
                    if newValue {
                        Task { await adsManager.enable() }
                    } else {
                        adsManager.disable()
                    }
                }
            )) {
                HStack {
                    Image(systemName: "megaphone.fill")
                        .frame(width: iconSize)
                    Text("Enable Optional Ads")
                    if adsManager.isEnabling {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(!AdsManager.isConfigured)
        } footer: {
            if AdsManager.isConfigured {
                Text("Ads are off by default and never unlock or lock any feature. Turning them on may show Google's consent form and Apple's tracking prompt.")
            } else {
                Text("Ads aren't available in this build.")
            }
        }
    }

    private var adTypesSection: some View {
        Section {
            adTypeToggle(
                "Settings Banner",
                detail: "A small ad at the top of Settings.",
                icon: "rectangle.on.rectangle",
                isOn: prefs.nativeAdsEnabled,
                update: prefsManager.updateNativeAdsEnabled
            )
            adTypeToggle(
                "Watch Ads On Demand",
                detail: "Only when you tap a button below.",
                icon: "play.rectangle.fill",
                isOn: prefs.rewardedAdsEnabled,
                update: prefsManager.updateRewardedAdsEnabled
            )
            adTypeToggle(
                "Ad on App Launch",
                detail: "On launch, and at most every 4 hours when returning to the app.",
                icon: "app.badge",
                isOn: prefs.appOpenAdsEnabled,
                update: prefsManager.updateAppOpenAdsEnabled
            )
        } header: {
            Text("Ad Types")
        }
    }

    private func adTypeToggle(_ title: String, detail: String, icon: String, isOn: Bool, update: @escaping (Bool) -> Void) -> some View {
        Toggle(isOn: Binding(
            get: { isOn },
            set: { newValue in
                HapticManager.impact(prefsEnabled: hapticsEnabled)
                update(newValue)
                adsManager.applyAdTypeSettings()
            }
        )) {
            HStack {
                Image(systemName: icon)
                    .frame(width: iconSize)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var watchAdsSection: some View {
        Section {
            if let session = adsManager.rewardedSession {
                sessionStatus(session)
            } else {
                HStack(spacing: 10) {
                    ForEach([1, 2, 5], id: \.self) { count in
                        Button {
                            HapticManager.impact(prefsEnabled: hapticsEnabled)
                            adsManager.startRewardedSession(count: count)
                        } label: {
                            Text(count == 1 ? "1 Ad" : "\(count) Ads")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .disabled(!prefs.rewardedAdsEnabled || !adsManager.isReady)
            }
        } header: {
            Text("Watch Ads")
        } footer: {
            Text("Ads play back to back. You can stop between ads, and close each one once its close button appears.")
        }
    }

    @ViewBuilder
    private func sessionStatus(_ session: AdsManager.RewardedSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ProgressView(value: Double(session.watched), total: Double(session.total))

            switch session.phase {
            case .loading, .showing:
                HStack {
                    ProgressView()
                    Text("Loading ad \(session.watched + 1) of \(session.total)…")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Stop", role: .cancel) { adsManager.endRewardedSession() }
                }
            case .between:
                Text("\(session.watched) of \(session.total) watched")
                HStack {
                    Button("Stop", role: .cancel) { adsManager.endRewardedSession() }
                        .buttonStyle(.bordered)
                    Spacer()
                    Button("Next Ad") { adsManager.continueRewardedSession() }
                        .buttonStyle(.borderedProminent)
                }
            case .finished:
                Text("Thank you for watching \(session.total == 1 ? "an ad" : "\(session.total) ads")!")
                    .font(.headline)
                Button("Done") { adsManager.endRewardedSession() }
            case .failed:
                Text("No ad is available right now. Please try again later. Thanks anyway!")
                    .foregroundStyle(.secondary)
                Button("Close") { adsManager.endRewardedSession() }
            }
        }
        .buttonStyle(.borderless)
        .padding(.vertical, 4)
    }

    private var statsSection: some View {
        Section {
            LabeledContent {
                Text(prefs.adsViewedCount, format: .number)
                    .contentTransition(.numericText())
            } label: {
                HStack {
                    Image(systemName: "eye.fill")
                        .frame(width: iconSize)
                    Text("Ads Viewed")
                }
            }
        }
    }

    private var sponsorSection: some View {
        Section {
            if let sponsorURL {
                Link(destination: sponsorURL) {
                    HStack {
                        Image("githubLogo")
                            .resizable()
                            .frame(width: iconSize, height: iconSize)
                        Text("Sponsor on GitHub")
                        Spacer()
                        Image(systemName: "chevron.right").imageScale(.small).foregroundColor(.secondary)
                    }
                    .foregroundColor(.primary)
                }
            }
            if adsManager.privacyOptionsRequired {
                Button {
                    Task { await adsManager.presentPrivacyOptions() }
                } label: {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                            .frame(width: iconSize)
                        Text("Ad Privacy Choices")
                    }
                    .foregroundColor(.primary)
                }
            }
        } footer: {
            Text("Prefer not to see ads? Sponsoring on GitHub supports the project directly.")
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserPreferencesModel.self, configurations: config)
    let prefs = PreferencesManager(context: ModelContext(container))

    NavigationStack {
        SupportView()
            .environment(prefs)
            .environment(AdsManager(prefs: prefs))
    }
}
