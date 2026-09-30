//
//  RoadmapView.swift
//  VatSight
//
//  Created by Marcel Marzec on 30/09/2026.
//

import SwiftUI
import SafariServices

struct RoadmapView: View {
    @State private var showTestFlightSignup = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                        Text("V0.5 Public Beta – TestFlight")
                            .font(.headline)
                    }
                    Text("You're using the current beta release. Thanks for helping test VatSight before the full launch!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Current Version")
            }

            Section {
                RoadmapFeatureRow(
                    icon: "star.fill",
                    title: "V1.0 - Full Release",
                    description: "The first full public release of VatSight on the App Store."
                )
                
                RoadmapFeatureRow(
                    icon: "fireworks",
                    title: "Vatsim Events",
                    description: "See whats going on in the community and where the biggest events are!"
                )
                
                RoadmapFeatureRow(
                    icon: "airplane",
                    title: "Improved Flight Tracking",
                    description: "Track your own flights, get information on which sector your in and what frequency to expect next."
                )

                RoadmapFeatureRow(
                    icon: "map.fill",
                    title: "Full Navigraph Integration",
                    description: "Seamless integration with Navigraph for up-to-date charts and navigation data."
                )
            } header: {
                Text("Planned Features")
            } footer: {
                Text("Planned features may change based on development progress and user feedback.")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Join the TestFlight Beta")
                        .font(.headline)
                    Text("Get early access to new features before they're publicly released. Beta testers help shape the future of VatSight — sign up to join the program.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)

                Button {
                    showTestFlightSignup = true
                } label: {
                    HStack {
                        Image(systemName: "airplane.departure")
                            .foregroundColor(.primary)
                        Text("Sign Up for TestFlight Beta")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .imageScale(.small)
                            .foregroundColor(.secondary)
                    }
                    .foregroundColor(.primary)
                }
                .sheet(isPresented: $showTestFlightSignup) {
                    if let url = URL(string: "https://vatsight.com/phplist/?p=subscribe&id=1") {
                        SafariView(url: url)
                            .ignoresSafeArea()
                    }
                }
            } header: {
                Text("Beta Program")
            }
        }
        .navigationTitle("Roadmap")
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct RoadmapFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.primary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        RoadmapView()
    }
}
