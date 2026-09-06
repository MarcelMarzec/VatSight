//
//  SettingsView.swift
//  VatSight
//
//  Created by Marcel Marzec on 12/05/2026.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(PreferencesManager.self) private var prefsManager
    @EnvironmentObject private var radarViewModel: RadarViewModel
    @State private var cidInputText = ""
    @FocusState private var cidFieldFocused: Bool
    private var vatsimDataRefreshRates = ["15s", "30s", "1min"]

    // Computed property to display CID or "ENTER" prompt
    private var displayedCID: String {
        let cid = prefsManager.userPrefs.vatsimCID
        return cid > 0 ? String(cid) : "ENTER"
    }
    
    // Binding for the refresh rate picker
    private var vatsimRefreshRate: Binding<String> {
        Binding(
            get: { prefsManager.userPrefs.vatsimRefreshRate },
            set: { newValue in
                prefsManager.updateRefreshRate(newValue)
            }
        )
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Settings") {
                    NavigationLink {
                        VatsimTrackedView()
                    } label: {
                        Label("Track Vatsim CIDs", systemImage: "person.2.badge.gearshape").foregroundColor(.primary)
                    }
                    
                    NavigationLink {
                        AppearanceView()
                    } label: {
                        Label("Appearance", systemImage: "slider.horizontal.3").foregroundColor(.primary)
                    }

                    VStack(alignment: .leading){
                        Text("Select Vatsim Data Refresh Rate")
                        Picker("", selection: vatsimRefreshRate) {
                            ForEach(vatsimDataRefreshRates, id: \.self) {
                                Text($0)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                
                Section("External Data"){
                    NavigationLink(value: "vatglasses") {
                        Image(systemName: "sunglasses")
                        Text("VATGlasses Sector Data")
                    }
                    NavigationLink(value: "vatsimdata") {
                        Image(systemName: "airplane.path.dotted")
                        Text("VATSIM User Data")
                    }
                }
                
                Section{
                    Link(destination: URL(string: "mailto:contact@marcelmarzec.com?subject=VatSight App Feedback / Support")!) {
                        HStack{
                            Image(systemName: "envelope.fill").foregroundColor(.blue)
                            VStack(alignment: .leading){
                                Text("Get in Contact")
                                Text("Send an Email to the developer about any issues, queries or feedback!").font(.subheadline).foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").imageScale(.small).foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    
                    /* NavigationLink{
                        AdView()
                    } label: {
                        HStack(spacing: 20) {
                            Image(systemName: "dollarsign").foregroundColor(.green)
                            VStack(alignment: .leading){
                                Text("Support my work for Free")
                                Text("Vatsight is free, support me by volontarily watching an advert").font(.subheadline).foregroundColor(.secondary)
                            }
                        }
                    } */
                
                    Link(destination: URL(string: "https://github.com/MarcelMarzec/VatSight")!) {
                        HStack {
                            Image("githubLogo")
                                .resizable()
                                .foregroundStyle(.primary)
                                .frame(width: 25, height: 25)
                            VStack(alignment: .leading) {
                                Text("VatSight Github Repository")
                                Text("View and Contribute the source code, Any help is greatly appreciated!").font(.subheadline).foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").imageScale(.small).foregroundColor(.secondary)
                        }.foregroundColor(.primary)
                    }

                    Link(destination: URL(string: "https://vatsight.com/ios_privacy_policy.html")!) {
                        HStack {
                            Image(systemName: "hand.raised.fill").foregroundColor(.primary)
                            VStack(alignment: .leading) {
                                Text("Privacy Policy")
                                Text("How VatSight handles your data.").font(.subheadline).foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").imageScale(.small).foregroundColor(.secondary)
                        }.foregroundColor(.primary)
                    }
                } header: {
                    Text("Miscellaneous")
                }

                Section {
                    NavigationLink {
                        DeveloperView()
                    } label: {
                        Label("Developers", systemImage: "hammer.fill").foregroundColor(.primary)
                    }
                }
            }
            .navigationDestination(for: String.self) { destination in
                if destination == "vatsimdata" {
                    VatsimUserDataView()
                } else {
                    VATGlassesDataView()
                }
            }
            .navigationTitle("VatSight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        cidFieldFocused = false
                    }
                }
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserPreferencesModel.self, configurations: config)
    let context = ModelContext(container)
    
    return SettingsView()
        .environment(PreferencesManager(context: context))
}
