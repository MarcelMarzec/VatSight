//
//  NativeAdBannerView.swift
//  VatSight
//

import SwiftUI
import GoogleMobileAds

struct NativeAdBannerView: UIViewRepresentable {
    let nativeAd: NativeAd

    static let height: CGFloat = 132

    func makeUIView(context: Context) -> NativeAdView {
        let adView = NativeAdView()

        let mediaView = MediaView()
        mediaView.layer.cornerRadius = 8
        mediaView.clipsToBounds = true

        let badge = PaddedLabel()
        badge.text = "Ad"
        badge.font = .preferredFont(forTextStyle: .caption2).bold()
        badge.textColor = .white
        badge.backgroundColor = .systemOrange
        badge.layer.cornerRadius = 4
        badge.clipsToBounds = true

        let headline = UILabel()
        headline.font = .preferredFont(forTextStyle: .subheadline).bold()
        headline.numberOfLines = 2

        let body = UILabel()
        body.font = .preferredFont(forTextStyle: .caption1)
        body.textColor = .secondaryLabel
        body.numberOfLines = 2

        var buttonConfig = UIButton.Configuration.filled()
        buttonConfig.cornerStyle = .capsule
        buttonConfig.buttonSize = .small
        let callToAction = UIButton(configuration: buttonConfig)
        // The SDK handles taps on the whole ad view; the button is only a visual
        callToAction.isUserInteractionEnabled = false

        let headerRow = UIStackView(arrangedSubviews: [badge, headline])
        headerRow.spacing = 6
        headerRow.alignment = .firstBaseline

        let textStack = UIStackView(arrangedSubviews: [headerRow, body, UIView(), callToAction])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.alignment = .leading

        let row = UIStackView(arrangedSubviews: [mediaView, textStack])
        row.spacing = 12
        row.alignment = .fill
        row.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(row)

        badge.setContentHuggingPriority(.required, for: .horizontal)
        badge.setContentCompressionResistancePriority(.required, for: .horizontal)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: adView.topAnchor, constant: 6),
            row.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -6),
            row.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -24), // room for AdChoices
            mediaView.widthAnchor.constraint(equalToConstant: 120), // AdMob minimum for video media
            mediaView.heightAnchor.constraint(equalToConstant: 120)
        ])

        adView.mediaView = mediaView
        adView.headlineView = headline
        adView.bodyView = body
        adView.callToActionView = callToAction
        return adView
    }

    func updateUIView(_ adView: NativeAdView, context: Context) {
        guard adView.nativeAd !== nativeAd else { return }

        (adView.headlineView as? UILabel)?.text = nativeAd.headline
        adView.mediaView?.mediaContent = nativeAd.mediaContent

        (adView.bodyView as? UILabel)?.text = nativeAd.body ?? nativeAd.advertiser
        adView.bodyView?.isHidden = (nativeAd.body ?? nativeAd.advertiser) == nil

        (adView.callToActionView as? UIButton)?.configuration?.title = nativeAd.callToAction
        adView.callToActionView?.isHidden = nativeAd.callToAction == nil

        // Must be assigned last so the SDK registers the populated asset views
        adView.nativeAd = nativeAd
    }
}

private final class PaddedLabel: UILabel {
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.insetBy(dx: 4, dy: 1))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + 8, height: size.height + 2)
    }
}

private extension UIFont {
    func bold() -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(.traitBold) else { return self }
        return UIFont(descriptor: descriptor, size: 0)
    }
}
