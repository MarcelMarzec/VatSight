//
//  RoadmapView.swift
//  VatSight
//
//  Created by Marcel Marzec on 30/09/2026.
//

import SwiftUI
import SafariServices

struct RoadmapView: View {
    @State private var showNewsletterSignup = false
    @ScaledMetric private var iconSize: CGFloat = 24

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                        Text("VatSight \(appVersion)")
                            .font(.headline)
                    }
                    Text("Thanks for using VatSight! New features are on the way, shaped by feedback from the VATSIM community.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Current Version")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "hammer.fill")
                            .foregroundColor(.orange)
                        Text("v1.1.1 · Events and Bookings Update")
                            .font(.headline)
                    }
                    Text("VATSIM events and ATC bookings, in the app and on the map.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)

                RoadmapFeatureRow(
                    icon: "calendar",
                    title: "Events Tab",
                    description: "Every current and upcoming VATSIM event as a list or a timeline, with filters for type, region and division."
                )

                RoadmapFeatureRow(
                    icon: "doc.text.image",
                    title: "Event Details",
                    description: "Banner, times, airports, routes, organisers and the ATC booked for the event."
                )

                RoadmapFeatureRow(
                    icon: "star.circle.fill",
                    title: "Events on the Map",
                    description: "Live and upcoming event airports stand out on the map."
                )

                RoadmapFeatureRow(
                    icon: "headphones",
                    title: "ATC Bookings",
                    description: "Booked controllers in each airport's details, and booked airspace outlined on the map."
                )

                RoadmapFeatureRow(
                    icon: "map",
                    title: "Map Legend & Focus",
                    description: "A legend for every map symbol, and fading of airports and aircraft that aren't connected to the airport you've selected."
                )
            } header: {
                Text("In Development")
            }

            Section {
                RoadmapFeatureRow(
                    icon: "wind",
                    title: "Metar Decoder / Apt Weather",
                    description: "More detailed visual metar decoder with runway crosswind coefficients."
                )
                
                RoadmapFeatureRow(
                    icon: "airplane",
                    title: "Improved Flight Tracking",
                    description: "Track your own flights, get information on which sector your in and what frequency to expect next."
                )
                
                RoadmapFeatureRow(
                    icon: "bell.fill",
                    title: "Flight Notifications",
                    description: "Get notifications when your flying and ATC logs on / your about to enter controlled airspace."
                )

                RoadmapFeatureRow(
                    icon: "map.fill",
                    title: "Full Navigraph Integration",
                    description: "Seamless integration with Navigraph for up-to-date charts and airport data."
                )
            } header: {
                Text("Planned Features")
            } footer: {
                Text("Planned features may change based on development progress and user feedback.")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Help Test New Features")
                        .font(.headline)
                    Text("Join the newsletter for release news and a chance to help test new features before they're released.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)

                Button {
                    showNewsletterSignup = true
                } label: {
                    HStack {
                        Image(systemName: "airplane.departure")
                            .frame(width: iconSize)
                            .foregroundColor(.primary)
                        Text("Join the Newsletter")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .imageScale(.small)
                            .foregroundColor(.secondary)
                    }
                    .foregroundColor(.primary)
                }
                .sheet(isPresented: $showNewsletterSignup) {
                    if let url = URL(string: "https://vatsight.com/phplist/?p=subscribe&id=1") {
                        SafariView(url: url)
                            .ignoresSafeArea()
                    }
                }
            } header: {
                Text("Stay Updated")
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
    @ScaledMetric private var iconSize: CGFloat = 24

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.primary)
                .frame(width: iconSize)
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
