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

                    NavigationLink("Track Vatsim CIDs") {
                        VatsimTrackedView()
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
                
                Section("External Data Sets"){
                    NavigationLink(value: "vatglasses") {
                        Image(systemName: "globe")
                        Text("Vatglasses Sector Data")
                    }
                    NavigationLink(value: "vatsim") {
                        Image(systemName: "globe")
                        Text("Vatsim API")
                    }
                }
                
                Section{
                    Link(destination: URL(string: "mailto:contact@marcelmarzec.com?subject=VatSight App Feedback / Support")!) {
                        HStack{
                            Image(systemName: "envelope.fill").foregroundColor(.blue)
                            Text("Get in Contact")
                            Spacer()
                            Image(systemName: "chevron.right").imageScale(.small).foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    
                    NavigationLink{
                        AdView()
                    } label: {
                        HStack(spacing: 20) {
                            Image(systemName: "dollarsign").foregroundColor(.green)
                            VStack(alignment: .leading){
                                Text("Support my work for Free")
                                Text("Vatsight is free, support me by volontarily watching an advert").font(.subheadline).foregroundColor(.secondary)
                            }
                        }
                    }
                
                    Link(destination: URL(string: "https://github.com/MarcelMarzec/VatSight")!) {
                        HStack {
                            Image("githubLogo")
                                .resizable()
                                .foregroundStyle(.primary)
                                .frame(width: 25, height: 25)
                            VStack(alignment: .leading) {
                                Text("VatSight Github Repository")
                                Text("This project is open source and free for you to view and contribute! Any help is greatly appreciated!").font(.subheadline).foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").imageScale(.small).foregroundColor(.secondary)
                        }.foregroundColor(.primary)
                    }
                } header: {
                    Text("Misc")
                }

            }
            .navigationDestination(for: String.self) { _ in
                AirspaceDataView(viewModel: RadarViewModel())
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
