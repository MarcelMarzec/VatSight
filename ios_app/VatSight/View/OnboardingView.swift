//
//  OnboardingView.swift
//  VatSight
//
//  Created by Marcel Marzec on 24/08/2026.
//

import SwiftUI
import SwiftData

// MARK: - Main View

struct OnboardingView: View {
    @Environment(PreferencesManager.self) private var prefsManager
    @State private var cidInputText = ""
    @State private var currentPage = 0
    @FocusState private var cidFocused: Bool

    // Pages 0–1 are generic, page 2 is the legend, page 3 is tracking + CID entry
    private static let legendPageIndex = 2
    private static let trackingPageIndex = 3
    private static let totalPageCount = 4

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            systemImage: "airplane.departure",
            title: "Welcome to VatSight",
            description: "A live radar for the VATSIM network. Explore active pilots, controllers and airspace sectors in real time using VATGlasses Data."
        ),
        OnboardingPage(
            systemImage: "map",
            title: "Interactive Radar",
            description: "Tap any aircraft to see its flight plan, or tap an airport to see traffic and active controllers. Use the search button to find anything instantly."
        ),
        OnboardingPage(
            systemImage: "person.2.badge.gearshape",
            title: "Track Your Friends",
            description: "Enter your VATSIM CID to highlight your aircraft and controlled airports in green. You can also track other CIDs from Settings."
        )
    ]

    var body: some View {
        ZStack {
            Color("LaunchBackground")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                pageIndicator
                    .padding(.top, 60)

                TabView(selection: $currentPage) {
                    OnboardingPageView(page: pages[0]).tag(0)
                    OnboardingPageView(page: pages[1]).tag(1)
                    OnboardingLegendPageView().tag(Self.legendPageIndex)
                    OnboardingPageView(page: pages[2]).tag(Self.trackingPageIndex)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: .infinity)

                if currentPage == Self.trackingPageIndex {
                    cidEntryField
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.3), value: currentPage)
                        .padding(.bottom, 20)
                }

                nextButton
                    .padding(.bottom, 20)

                skipButton
            }
        }
        .onTapGesture {
            cidFocused = false
        }
    }

    // MARK: - Subviews

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<Self.totalPageCount, id: \.self) { i in
                Capsule()
                    .fill(i == currentPage ? Color.accentColor : Color.primary.opacity(0.2))
                    .frame(width: i == currentPage ? 20 : 8, height: 8)
                    .animation(.spring(duration: 0.35), value: currentPage)
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.35)) { currentPage = i }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
            }
        }
    }

    private var cidEntryField: some View {
        VStack(spacing: 12) {
            Text("Enter your VATSIM CID (optional)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("e.g. 1234567", text: $cidInputText)
                .keyboardType(.numberPad)
                .focused($cidFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                )
                .padding(.horizontal, 32)
        }
    }

    private var nextButton: some View {
        Button {
            if currentPage < Self.totalPageCount - 1 {
                withAnimation(.spring(duration: 0.35)) { currentPage += 1 }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } else {
                finishOnboarding()
            }
        } label: {
            Text(currentPage < Self.totalPageCount - 1 ? "Next" : "Get Started")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 32)
        }
    }

    private var skipButton: some View {
        Group {
            if currentPage < Self.totalPageCount - 1 {
                Button("Skip") {
                    withAnimation(.spring(duration: 0.35)) {
                        currentPage = Self.totalPageCount - 1
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            } else {
                Color.clear
            }
        }
        .frame(height: 40)
        .padding(.bottom, 40)
    }

    // MARK: - Actions

    private func finishOnboarding() {
        if let cid = Int(cidInputText), cid > 0 {
            prefsManager.updateCID(cid)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        prefsManager.markOnboardingComplete()
    }
}

// MARK: - Page Model

private struct OnboardingPage {
    let systemImage: String
    let title: String
    let description: String
}

// MARK: - Generic Page View

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: page.systemImage)
                .font(.system(size: 72, weight: .thin))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 100)

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .padding(.top, 20)
    }
}

// MARK: - Legend Page

private struct OnboardingLegendPageView: View {
    @State private var chevronBounce = false
    @State private var showHint = true

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Map Legend")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)

                    LegendSection(title: "Aircraft") {
                        LegendRow(label: "Airborne aircraft", description: "Any active VATSIM pilot") {
                            pilotIcon(color: .white)
                        }
                        LegendRow(label: "Your aircraft", description: "Highlighted in gold when your CID is set") {
                            pilotIcon(named: "pilot", color: Color(red: 1.0, green: 0.78, blue: 0.0))
                        }
                        LegendRow(label: "Tracked aircraft", description: "A pilot you are tracking, shown in green") {
                            pilotIcon(named: "friendPilot", color: Color(red: 0.19, green: 0.90, blue: 0.43))
                        }
                        LegendRow(label: "Selected aircraft", description: "The aircraft you have tapped on") {
                            pilotIcon(named: "selectedPilot", color: .red)
                        }
                    }

                    LegendSection(title: "Airports") {
                        LegendRow(label: "Airport", description: "No active ATC coverage") {
                            Circle()
                                .strokeBorder(.primary, lineWidth: 1.5)
                                .frame(width: 10, height: 10)
                        }
                        LegendRow(label: "Staffed airport", description: "Has active ATC — tap to see controllers and traffic") {
                            Circle()
                                .fill(.primary)
                                .frame(width: 10, height: 10)
                        }
                        LegendRow(label: "Friend's airport", description: "Controlled by someone you are tracking") {
                            Circle()
                                .fill(Color(red: 0.19, green: 0.90, blue: 0.43))
                                .frame(width: 10, height: 10)
                        }
                        LegendRow(label: "Service badges", description: "T = Tower · G = Ground · D = Delivery · A = ATIS") {
                            serviceBadges
                        }
                    }

                    LegendSection(title: "Airspace Sectors") {
                        LegendRow(label: "Active sector", description: "Airspace currently controlled — tap to see the controller") {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.accentColor.opacity(0.35))
                                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.accentColor, lineWidth: 1))
                                .frame(width: 22, height: 14)
                        }
                        LegendRow(label: "Inactive sector", description: "Visible when 'Inactive sectors' is turned on") {
                            RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(Color.primary.opacity(0.3), lineWidth: 1)
                                .frame(width: 22, height: 14)
                        }
                    }

                    LegendSection(title: "Toolbar Buttons") {
                        LegendRow(label: "Search", description: "Find any pilot, airport or controller") {
                            Image(systemName: "magnifyingglass")
                        }
                        LegendRow(label: "Layer menu", description: "Toggle sectors, airports and sector merging") {
                            Image(systemName: "ellipsis").rotationEffect(.degrees(90))
                        }
                        LegendRow(label: "Altitude filter", description: "Show only aircraft below a chosen altitude") {
                            Image(systemName: "square.2.layers.3d")
                        }
                        LegendRow(label: "Locate me", description: "Fly the map to your own aircraft (when online)") {
                            Image(systemName: "location")
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
            .mask(
                VStack(spacing: 0) {
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 48)
                }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        // Only treat as a scroll gesture if predominantly vertical
                        if abs(value.translation.height) > abs(value.translation.width), showHint {
                            withAnimation(.easeOut(duration: 0.2)) { showHint = false }
                        }
                    }
            )

            if showHint {
                Image(systemName: "chevron.compact.down")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .offset(y: chevronBounce ? 4 : 0)
                    .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: chevronBounce)
                    .onAppear { chevronBounce = true }
                    .padding(.bottom, 4)
                    .transition(.opacity)
            }
        }
        .frame(maxHeight: 420)
    }

    @ViewBuilder
    private func pilotIcon(named: String = "pilot", color: Color) -> some View {
        Image(named)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(color)
    }

    private var serviceBadges: some View {
        let badges: [(String, Color)] = [
            ("T", Color(red: 0.20, green: 0.60, blue: 1.00)),
            ("G", Color(red: 0.20, green: 0.78, blue: 0.35)),
            ("D", Color(red: 1.00, green: 0.58, blue: 0.00)),
            ("A", Color(red: 0.69, green: 0.32, blue: 0.87))
        ]
        return HStack(spacing: 2) {
            ForEach(badges, id: \.0) { letter, color in
                Text(letter)
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(color, in: RoundedRectangle(cornerRadius: 2))
            }
        }
    }
}

// MARK: - Legend Supporting Views

private struct LegendSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
    }
}

private struct LegendRow<Icon: View>: View {
    let label: String
    let description: String
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            icon()
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline.weight(.medium))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserPreferencesModel.self, configurations: config)
    let context = ModelContext(container)

    OnboardingView()
        .environment(PreferencesManager(context: context))
}
