//
//  SplashScreenView.swift
//  VatSight
//
//  Created by Marcel Marzec on 24/08/2026.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Color("LaunchBackground")
                .ignoresSafeArea()

            // Logo + text group positioned to exactly match the launch screen:
            // logo centerY = screenHeight/2 - 30 (same as the storyboard centerY constraint with constant -30)
            GeometryReader { geo in
                VStack(spacing: 0) {
                    Image("Vatsight")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 200)

                    Text("VatSight")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Color("LaunchText"))
                        .padding(.top, 4)
                }
                .frame(width: geo.size.width)
                .position(x: geo.size.width / 2, y: geo.size.height / 2 - 30)
            }

            // Spinner pinned to bottom
            VStack {
                Spacer()
                Image("loadingArrow")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(rotation))
                    .onAppear {
                        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                            rotation = 360
                        }
                    }
                    .padding(.bottom, 60)
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
