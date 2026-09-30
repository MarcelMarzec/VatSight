//
//  SettingsView.swift
//  VatSight
//
//  Created by Marcel Marzec on 12/05/2026.
//

import SwiftUI
import SwiftData
import SafariServices

struct SettingsView: View {
    @Environment(PreferencesManager.self) private var prefsManager
    @EnvironmentObject private var radarViewModel: RadarViewModel
    @State private var cidInputText = ""
    @State private var showPrivacyPolicy = false
    @State private var showWebsite = false
    @State private var showContactForm = false
    @FocusState private var cidFieldFocused: Bool
    private var vatsimDataRefreshRates = ["15s", "30s", "1min"]

    private var displayedCID: String {
        let cid = prefsManager.userPrefs.vatsimCID
        return cid > 0 ? String(cid) : "ENTER"
    }
    
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
                        FriendsView()
                    } label: {
                        Label("Friends", systemImage: "person.2.badge.gearshape").foregroundColor(.primary)
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
                        Label("VATGlasses Sector Data", systemImage: "sunglasses").foregroundColor(.primary)
                    }
                    NavigationLink(value: "vatsimdata") {
                        Label("VATSIM User Data", systemImage: "airplane.path.dotted").foregroundColor(.primary)
                    }
                }
                
                Section {
                    Button {
                        showContactForm = true
                    } label: {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .frame(width: 24)
                                .foregroundColor(.primary)
                            VStack(alignment: .leading) {
                                Text("Get in Contact")
                                Text("Send an email to the developer about any issues, queries or feedback!").font(.subheadline).foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").imageScale(.small).foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    .sheet(isPresented: $showContactForm) {
                        ContactFormView()
                    }
                    
                    Button {
                        showWebsite = true
                    } label: {
                        HStack {
                            Image(systemName: "globe")
                                .frame(width: 24)
                                .foregroundColor(.primary)
                            VStack(alignment: .leading) {
                                Text("VatSight Website")
                            }
                            Spacer()
                            Image(systemName: "chevron.right").imageScale(.small).foregroundColor(.secondary)
                        }.foregroundColor(.primary)
                    }
                    .sheet(isPresented: $showWebsite) {
                        if let url = URL(string: "https://vatsight.com") {
                            SafariView(url: url)
                                .ignoresSafeArea()
                        }
                    }

                    if let githubURL = URL(string: "https://github.com/MarcelMarzec/VatSight") {
                        Link(destination: githubURL) {
                            HStack {
                                Image("githubLogo")
                                    .resizable()
                                    .foregroundStyle(.primary)
                                    .frame(width: 24, height: 24)
                                VStack(alignment: .leading) {
                                    Text("VatSight Github Repository")
                                }
                                Spacer()
                                Image(systemName: "chevron.right").imageScale(.small).foregroundColor(.secondary)
                            }.foregroundColor(.primary)
                        }
                    }

                    Button {
                        showPrivacyPolicy = true
                    } label: {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                                .frame(width: 24)
                                .foregroundColor(.primary)
                            VStack(alignment: .leading) {
                                Text("Privacy Policy")
                            }
                            Spacer()
                            Image(systemName: "chevron.right").imageScale(.small).foregroundColor(.secondary)
                        }.foregroundColor(.primary)
                    }
                    .sheet(isPresented: $showPrivacyPolicy) {
                        if let url = URL(string: "https://vatsight.com/ios_privacy_policy.html") {
                            SafariView(url: url)
                                .ignoresSafeArea()
                        }
                    }
                } header: {
                    Text("About")
                }

                Section {
                    NavigationLink {
                        RoadmapView()
                    } label: {
                        HStack {
                            Image(systemName: "map.fill")
                                .frame(width: 24)
                                .foregroundColor(.primary)
                            VStack(alignment: .leading) {
                                Text("Roadmap & Beta Program")
                                Text("What's coming next and how to join the beta").font(.subheadline).foregroundColor(.secondary)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }

                Section {
                    NavigationLink {
                        DeveloperView()
                    } label: {
                        Label("Sector Maintainers", systemImage: "hammer.fill").foregroundColor(.primary)
                    }
                    if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
                       let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
                        LabeledContent("Version", value: "\(version) (\(build))")
                            .foregroundStyle(.secondary)
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

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserPreferencesModel.self, configurations: config)
    let context = ModelContext(container)
    
    return SettingsView()
        .environment(PreferencesManager(context: context))
}
