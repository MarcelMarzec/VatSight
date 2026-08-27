//
//  DeveloperView.swift
//  VatSight
//
//  Created by Marcel Marzec on 12/05/2026.
//

import SwiftUI
import SwiftData

struct DeveloperView: View {
    @Environment(PreferencesManager.self) private var prefsManager
    @EnvironmentObject private var radarViewModel: RadarViewModel

    // Local draft of the repo slug while the user is typing
    @State private var repoSlugDraft: String = ""
    @State private var showRepoAppliedBanner = false
    @FocusState private var repoFieldFocused: Bool

    var body: some View {
        List {
            // MARK: - Developer Mode toggle
            Section {
                Toggle(isOn: Binding(
                    get: { prefsManager.userPrefs.developerModeEnabled },
                    set: { newValue in
                        prefsManager.updateDeveloperMode(newValue)
                        if newValue {
                            // Restore saved custom slug (may be empty = default)
                            let saved = prefsManager.userPrefs.vatglassesCustomRepoSlug
                            radarViewModel.applyVatglassesCustomRepo(saved)
                        } else {
                            // Dev mode off — revert to default repo
                            radarViewModel.applyVatglassesCustomRepo("")
                        }
                    }
                )) {
                    Label("Developer Mode", systemImage: "hammer.fill")
                }

                if prefsManager.userPrefs.developerModeEnabled {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                        Text("Sector debug panel enabled on the map.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // MARK: - Developer-only settings (visible only when dev mode is on)
            if prefsManager.userPrefs.developerModeEnabled {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom Vatglasses GitHub Repo")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Text("Override the default data source with any public GitHub repository that uses the same format.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField(
                            "owner/repo",
                            text: $repoSlugDraft
                        )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .focused($repoFieldFocused)
                        .padding(8)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        HStack(spacing: 8) {
                            Button {
                                applyCustomRepo()
                            } label: {
                                Text("Apply")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(repoSlugDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            if prefsManager.isUsingCustomVatglassesRepo {
                                Button(role: .destructive) {
                                    clearCustomRepo()
                                } label: {
                                    Text("Reset to Default")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                        }

                        if showRepoAppliedBanner {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Custom repo applied. Redownloading data…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Vatglasses Data Source")
                } footer: {
                    if prefsManager.isUsingCustomVatglassesRepo {
                        Text("Currently using: \(prefsManager.userPrefs.vatglassesCustomRepoSlug)")
                    } else {
                        Text("Currently using the default Vatglasses repository.")
                    }
                }
            }
        }
        .navigationTitle("Developer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { repoFieldFocused = false }
            }
        }
        .onAppear {
            repoSlugDraft = prefsManager.userPrefs.vatglassesCustomRepoSlug
        }
    }

    private func applyCustomRepo() {
        let slug = repoSlugDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !slug.isEmpty else { return }
        repoFieldFocused = false
        prefsManager.updateVatglassesCustomRepo(slug)
        radarViewModel.applyVatglassesCustomRepo(slug)
        withAnimation {
            showRepoAppliedBanner = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { showRepoAppliedBanner = false }
        }
    }

    private func clearCustomRepo() {
        repoSlugDraft = ""
        prefsManager.updateVatglassesCustomRepo("")
        radarViewModel.applyVatglassesCustomRepo("")
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserPreferencesModel.self, configurations: config)
    let context = ModelContext(container)

    return NavigationStack {
        DeveloperView()
            .environment(PreferencesManager(context: context))
            .environmentObject(RadarViewModel())
    }
}
