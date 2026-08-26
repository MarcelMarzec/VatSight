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

            VStack(spacing: 16) {
                Image("Vatsight")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)

                Text("VatSight")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color("LaunchText"))

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
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
