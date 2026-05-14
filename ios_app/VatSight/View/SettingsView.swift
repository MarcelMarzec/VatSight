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
    @State private var cidText = ""
    @FocusState private var cidFieldFocused: Bool
    
    var body: some View {
        
        NavigationView {
            List {
                Section("Vatsim Settings") {
                    TextField("Enter your CID", text: $cidText)
                        .focused($cidFieldFocused)
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()

                                Button("Done") {
                                    cidFieldFocused = false
                                }
                            }
                        }
                        .onAppear {
                            let cid = prefsManager.userPrefs.vatsimCID
                            cidText = cid == 0 ? "" : String(cid)
                        }
                        .onChange(of: cidText) { oldValue, newValue in
                            let filtered = newValue.filter { $0.isNumber }

                            if filtered != newValue {
                                cidText = filtered
                                return
                            }

                            if let cid = Int(filtered) {
                                prefsManager.updateCID(cid)
                            } else if filtered.isEmpty {
                                prefsManager.updateCID(0)
                            }
                        }
                        .keyboardType(.numberPad)
                }
                Section {
                    Link("Get In Contact", destination: URL(string: "mailto:contact@marcelmarzec.com")!)
                        .foregroundColor(.primary)
                    LabeledContent("IOS Version", value: "26.3")
                    LabeledContent("VatSight Version", value: "0.0")
                } header: {
                    Text("Miscellaneous")
                }
            }.navigationTitle("VatSight")
                .navigationBarTitleDisplayMode(.inline)
        }.onTapGesture {
            cidFieldFocused = false
        }
    }
}

#Preview {
    SettingsView()
        .environment(
            PreferencesManager(
                context: try! ModelContext(
                    ModelContainer(for: UserPreferencesModel.self)
                )
            )
        )
}
