//
//  BannerAdCard.swift
//  VatSight
//

import SwiftUI
import GoogleMobileAds

/// An inline banner ad in a card. Takes no space until an ad has loaded, or when the placement is off.
struct BannerAdCard: View {
    let placement: AdsManager.BannerPlacement
    var cornerRadius: CGFloat = 16

    @Environment(AdsManager.self) private var adsManager
    @State private var width: CGFloat = 0
    @State private var adHeight: CGFloat = 0

    private static let maxHeight: CGFloat = 60

    var body: some View {
        if let adUnitID = adsManager.bannerAdUnitID(for: placement) {
            ZStack {
                if width > 0 {
                    // The SDK rejects a zero-sized view, so the banner keeps its full size and the card clips it.
                    BannerAdView(adUnitID: adUnitID, width: width, maxHeight: Self.maxHeight, height: $adHeight) {
                        adsManager.recordBannerImpression()
                    }
                    .frame(width: width, height: adHeight > 0 ? adHeight : Self.maxHeight)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: adHeight, alignment: .top)
            .clipped()
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .padding(.horizontal, 8)
            .padding(.vertical, adHeight > 0 ? 8 : 0)
            .background {
                if adHeight > 0 {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                }
            }
        }
    }
}

private struct BannerAdView: UIViewRepresentable {
    let adUnitID: String
    let width: CGFloat
    let maxHeight: CGFloat
    @Binding var height: CGFloat
    let onImpression: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(height: $height, onImpression: onImpression)
    }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: inlineAdaptiveBanner(width: width, maxHeight: maxHeight))
        banner.adUnitID = adUnitID
        banner.rootViewController = AdsManager.topViewController()
        banner.delegate = context.coordinator
        banner.load(Request())
        return banner
    }

    // Loaded once at its first width; a fresh card is created when the screen is reopened.
    func updateUIView(_ banner: BannerView, context: Context) {}

    final class Coordinator: NSObject, BannerViewDelegate {
        @Binding var height: CGFloat
        let onImpression: () -> Void

        init(height: Binding<CGFloat>, onImpression: @escaping () -> Void) {
            _height = height
            self.onImpression = onImpression
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            height = bannerView.adSize.size.height > 0 ? bannerView.adSize.size.height : 50
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: any Error) {
            print("[Ads] Banner load failed: \(error.localizedDescription)")
            height = 0
        }

        func bannerViewDidRecordImpression(_ bannerView: BannerView) {
            onImpression()
        }
    }
}
