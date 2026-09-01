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

    // Unmatched controller filter pills — all true = filtered out (hidden) by default
    @State private var hideObservers = true   // frequency 199.998
    @State private var hideGND = true
    @State private var hideDEL = true
    @State private var hideSUP = true
    @State private var hideOBS = true

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
            
            // MARK: Vatglasses Data Source (dev mode only)
            if prefsManager.userPrefs.developerModeEnabled {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom Vatglasses GitHub Repo")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Text("Have your own fork of VATGlasses? Test it on live traffic in real time. Make sure the repo is public then set the custom repo slug below.")
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
            } // end dev mode if (Vatglasses Data Source)

            // MARK: - Diagnostics (dev mode only)
            if prefsManager.userPrefs.developerModeEnabled {
                // MARK: Diagnostics — Unmatched Controllers
                Section {
                    // Filter pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterPill(label: "OBS Freq", isFiltered: $hideObservers)
                            FilterPill(label: "_GND", isFiltered: $hideGND)
                            FilterPill(label: "_DEL", isFiltered: $hideDEL)
                            FilterPill(label: "_SUP", isFiltered: $hideSUP)
                            FilterPill(label: "_OBS", isFiltered: $hideOBS)
                        }
                        .padding(.vertical, 4)
                    }

                    let unmatched = filteredUnmatched
                    if unmatched.isEmpty {
                        Label("All controllers matched", systemImage: "checkmark.circle")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(unmatched) { controller in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(controller.callsign)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                HStack(spacing: 8) {
                                    Text(controller.frequency)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("CID \(controller.cid)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if !controller.name.isEmpty {
                                        Text(controller.name)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Unmatched Controllers")
                        Spacer()
                        let count = filteredUnmatched.count
                        if count > 0 {
                            Text("\(count)")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .foregroundStyle(.orange)
                                .clipShape(Capsule())
                        }
                    }
                } footer: {
                    Text("Controllers online on VATSIM that could not be matched to any Vatglasses sector or position.")
                }
                
                // MARK: Diagnostics — Parse Errors
                Section {
                    let errors = radarViewModel.vatglassesDiagnostics.parseErrors
                    if errors.isEmpty {
                        Label("No parse errors", systemImage: "checkmark.circle")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(errors) { error in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(error.source)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.red)
                                Text(error.message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Parse Errors")
                        Spacer()
                        let count = radarViewModel.vatglassesDiagnostics.parseErrors.count
                        if count > 0 {
                            Text("\(count)")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.2))
                                .foregroundStyle(.red)
                                .clipShape(Capsule())
                        }
                    }
                } footer: {
                    let date = radarViewModel.vatglassesDiagnostics.lastUpdated
                    if date > .distantPast {
                        Text("Last updated \(date.formatted(.relative(presentation: .named)))")
                    } else {
                        Text("Errors from files or directories that failed to decode during the last Vatglasses data load.")
                    }
                }

                // MARK: Diagnostics — Invalid Airports
                Section {
                    let invalid = radarViewModel.vatglassesDiagnostics.invalidAirports
                    if invalid.isEmpty {
                        Label("All airport coordinates valid", systemImage: "checkmark.circle")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(invalid) { airport in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(airport.icao)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.orange)
                                    if !airport.name.isEmpty {
                                        Text(airport.name)
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                    }
                                }
                                Text(airport.reason)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Invalid Airport Coordinates")
                        Spacer()
                        let count = radarViewModel.vatglassesDiagnostics.invalidAirports.count
                        if count > 0 {
                            Text("\(count)")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .foregroundStyle(.orange)
                                .clipShape(Capsule())
                        }
                    }
                } footer: {
                    Text("Airports whose latitude or longitude fell outside valid WGS-84 ranges after parsing. These may render incorrectly on the map.")
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

    private var filteredUnmatched: [UnmatchedController] {
        radarViewModel.vatglassesDiagnostics.unmatchedControllers.filter { c in
            let callsign = c.callsign.uppercased()
            if hideObservers && c.frequency == "199.998" { return false }
            if hideGND && callsign.hasSuffix("_GND") { return false }
            if hideDEL && callsign.hasSuffix("_DEL") { return false }
            if hideSUP && callsign.hasSuffix("_SUP") { return false }
            if hideOBS && callsign.hasSuffix("_OBS") { return false }
            return true
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

private struct FilterPill: View {
    let label: String
    @Binding var isFiltered: Bool   // true = this category is hidden

    var body: some View {
        Button {
            isFiltered.toggle()
        } label: {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isFiltered ? Color.secondary.opacity(0.15) : Color.orange.opacity(0.2))
                .foregroundStyle(isFiltered ? Color.secondary : Color.orange)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(isFiltered ? Color.secondary.opacity(0.3) : Color.orange.opacity(0.5), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
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
