//
//  SupportPromptView.swift
//  VatSight
//

import SwiftUI
import SwiftData

/// Occasional sheet asking users with ads off to support VatSight by choosing which ads they're happy to see.
struct SupportPromptView: View {
    @Environment(PreferencesManager.self) private var prefsManager
    @Environment(AdsManager.self) private var adsManager
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric private var iconSize: CGFloat = 24

    @State private var didEnable = false

    private var prefs: UserPreferencesModel { prefsManager.userPrefs }
    private var hapticsEnabled: Bool { prefs.hapticFeedbackEnabled }
    private var anyTypeSelected: Bool { prefs.nativeAdsEnabled || prefs.rewardedAdsEnabled || prefs.appOpenAdsEnabled }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    if didEnable {
                        thankYou
                    } else {
                        adTypes
                        actions
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .disabled(adsManager.isEnabling)
                }
            }
        }
        .interactiveDismissDisabled(adsManager.isEnabling)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "heart.fill")
                .font(.system(size: 44))
                .foregroundStyle(.pink)
                .symbolEffect(.bounce, value: didEnable)
            Text(didEnable ? "Thank you!" : "Support VatSight")
                .font(.title2.bold())
            Text("VatSight is free and open source, built in my spare time. If you're enjoying it, turning on a few optional ads helps cover its running costs and keeps new features coming.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var adTypes: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose the ads you're happy to see")
                .font(.headline)

            VStack(spacing: 0) {
                adTypeToggle(
                    "Settings Banner",
                    detail: "A small ad at the top of Settings.",
                    icon: "rectangle.on.rectangle",
                    isOn: prefs.nativeAdsEnabled,
                    update: prefsManager.updateNativeAdsEnabled
                )
                Divider().padding(.leading, iconSize + 28)
                adTypeToggle(
                    "Watch Ads On Demand",
                    detail: "Only when you choose to, from Settings → Support VatSight.",
                    icon: "play.rectangle.fill",
                    isOn: prefs.rewardedAdsEnabled,
                    update: prefsManager.updateRewardedAdsEnabled
                )
                Divider().padding(.leading, iconSize + 28)
                adTypeToggle(
                    "Ad on App Launch",
                    detail: "On launch, and at most every 4 hours when returning to the app.",
                    icon: "app.badge",
                    isOn: prefs.appOpenAdsEnabled,
                    update: prefsManager.updateAppOpenAdsEnabled
                )
            }
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))

            Text("Ads never lock or unlock a feature, and you can change this anytime in Settings → Support VatSight.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func adTypeToggle(_ title: String, detail: String, icon: String, isOn: Bool, update: @escaping (Bool) -> Void) -> some View {
        Toggle(isOn: Binding(
            get: { isOn },
            set: { newValue in
                HapticManager.impact(prefsEnabled: hapticsEnabled)
                update(newValue)
            }
        )) {
            HStack(spacing: 12) {
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .disabled(adsManager.isEnabling)
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                HapticManager.impact(prefsEnabled: hapticsEnabled)
                Task {
                    await adsManager.enable()
                    withAnimation { didEnable = prefs.adsEnabled }
                }
            } label: {
                HStack {
                    if adsManager.isEnabling { ProgressView() }
                    Text("Turn On Ads")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!anyTypeSelected || adsManager.isEnabling)

            Button("Not Now") { dismiss() }
                .disabled(adsManager.isEnabling)

            Button("Don't Ask Again") {
                prefsManager.optOutOfSupportPrompt()
                dismiss()
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .disabled(adsManager.isEnabling)
        }
    }

    private var thankYou: some View {
        VStack(spacing: 16) {
            Text("Your support means a lot. You can see how many ads you've helped with, or watch one on demand, in Settings → Support VatSight.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserPreferencesModel.self, configurations: config)
    let prefs = PreferencesManager(context: ModelContext(container))

    Color.clear
        .sheet(isPresented: .constant(true)) {
            SupportPromptView()
                .environment(prefs)
                .environment(AdsManager(prefs: prefs))
                .presentationDetents([.large])
        }
}
