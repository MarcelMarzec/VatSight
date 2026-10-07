//
//  HapticManager.swift
//  VatSight
//

import UIKit

enum HapticManager {

    // MARK: - Private helpers

    private static func shouldFire(prefsEnabled: Bool) -> Bool {
        guard prefsEnabled else { return false }
        // respects system Reduce Motion setting
        guard !UIAccessibility.isReduceMotionEnabled else { return false }
        return true
    }

    // MARK: - Public API

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light,
                       intensity: CGFloat = 1.0,
                       prefsEnabled: Bool) {
        guard shouldFire(prefsEnabled: prefsEnabled) else { return }
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.impactOccurred(intensity: intensity)
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType,
                             prefsEnabled: Bool) {
        guard shouldFire(prefsEnabled: prefsEnabled) else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}
