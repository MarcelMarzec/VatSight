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
    @ScaledMetric private var iconSize: CGFloat = 24
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
                        HStack {
                            Image(systemName: "person.2.fill")
                                .frame(width: iconSize)
                                .foregroundColor(.primary)
                            Text("Friends")
                        }
                    }
                    
                    NavigationLink {
                        AppearanceView()
                    } label: {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                                .frame(width: iconSize)
                                .foregroundColor(.primary)
                            Text("Appearance & Accessibility")
                        }
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
                        HStack {
                            Image(systemName: "sunglasses")
                                .frame(width: iconSize)
                                .foregroundColor(.primary)
                            Text("VATGlasses Sector Data")
                        }
                    }
                    NavigationLink(value: "vatsimdata") {
                        HStack {
                            Image(systemName: "airplane.path.dotted")
                                .frame(width: iconSize)
                                .foregroundColor(.primary)
                            Text("VATSIM User Data")
                        }
                    }
                }
                
                Section {
                    Button {
                        showContactForm = true
                    } label: {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .frame(width: iconSize)
                                .foregroundColor(.primary)
                            VStack(alignment: .leading) {
                                Text("Contact Us")
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
                                .frame(width: iconSize)
                                .foregroundColor(.primary)
                            VStack(alignment: .leading) {
                                Text("Website")
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
                                    .frame(width: iconSize, height: iconSize)
                                VStack(alignment: .leading) {
                                    Text("Github Repository")
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
                                .frame(width: iconSize)
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
                            Image(systemName: "list.bullet.clipboard")
                                .frame(width: iconSize)
                                .foregroundColor(.primary)
                            VStack(alignment: .leading) {
                                Text("Roadmap & Beta Program")
                            }
                        }
                    }
                    .foregroundColor(.primary)
                    NavigationLink {
                        DeveloperView()
                    } label: {
                        HStack {
                            Image(systemName: "hammer.fill")
                                .frame(width: iconSize)
                                .foregroundColor(.primary)
                            Text("Sector Maintainers")
                        }
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
