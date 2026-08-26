//
//  OnboardingView.swift
//  VatSight
//
//  Created by Marcel Marzec on 24/08/2026.
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(PreferencesManager.self) private var prefsManager
    @State private var cidInputText = ""
    @State private var currentPage = 0
    @FocusState private var cidFocused: Bool

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
            // Background gradient
            Color("LaunchBackground")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Page indicator dots
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Capsule()
                            .fill(i == currentPage ? Color.accentColor : Color.primary.opacity(0.2))
                            .frame(width: i == currentPage ? 20 : 8, height: 8)
                            .animation(.spring(duration: 0.35), value: currentPage)
                    }
                }
                .padding(.top, 60)
                .padding(.bottom, 12)

                // Pages
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        OnboardingPageView(page: pages[i])
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: 420)

                // CID entry — only visible on the last page
                if currentPage == pages.count - 1 {
                    VStack(spacing: 12) {
                        Text("Enter your VATSIM CID (optional)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack {
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
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal, 32)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: currentPage)
                    .padding(.top, 8)
                }

                Spacer()

                // Next / Get Started button
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation(.spring(duration: 0.35)) {
                            currentPage += 1
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } else {
                        finishOnboarding()
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 32)
                }
                .padding(.bottom, 20)

                // Skip button (not on last page)
                if currentPage < pages.count - 1 {
                    Button("Skip") {
                        withAnimation(.spring(duration: 0.35)) {
                            currentPage = pages.count - 1
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 40)
                } else {
                    Color.clear.frame(height: 40)
                }
            }
        }
        .onTapGesture {
            cidFocused = false
        }
    }

    private func finishOnboarding() {
        // Save CID if entered
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

// MARK: - Page View

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

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserPreferencesModel.self, configurations: config)
    let context = ModelContext(container)

    OnboardingView()
        .environment(PreferencesManager(context: context))
}
