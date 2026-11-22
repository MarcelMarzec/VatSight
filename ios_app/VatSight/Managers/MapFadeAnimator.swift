//
//  MapFadeAnimator.swift
//  VatSight
//
//  Drives a 0…1 value over time with a display link. Mapbox animates paint-property changes
//  but not opacity changes caused by feature data, so the map fades "not connected" airports
//  and aircraft by animating a layer-wide fade strength instead.
//

import Foundation
import QuartzCore
import UIKit

final class MapFadeAnimator: NSObject {
    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0
    private var from: Double = 0
    private var to: Double = 0
    private var duration: CFTimeInterval = 0.3
    private var onUpdate: ((Double) -> Void)?
    private var onComplete: (() -> Void)?

    var isRunning: Bool { displayLink != nil }

    /// Animates from `from` to `to` with an ease-in-out curve. A new call replaces any running
    /// animation (its completion is dropped). Reduce Motion makes the change immediate.
    func animate(
        from: Double,
        to: Double,
        duration: CFTimeInterval = 0.3,
        update: @escaping (Double) -> Void,
        completion: (() -> Void)? = nil
    ) {
        stop()
        guard duration > 0, from != to, !UIAccessibility.isReduceMotionEnabled else {
            update(to)
            completion?()
            return
        }
        self.from = from
        self.to = to
        self.duration = duration
        onUpdate = update
        onComplete = completion
        startTime = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        onUpdate = nil
        onComplete = nil
    }

    @objc private func step(_ link: CADisplayLink) {
        let t = min(1, (CACurrentMediaTime() - startTime) / duration)
        let eased = t * t * (3 - 2 * t) // smoothstep
        onUpdate?(from + (to - from) * eased)
        guard t >= 1 else { return }
        let completion = onComplete
        stop()
        completion?()
    }
}
