//
//  UserPreferencesModel.swift
//  VatSight
//
//  Created by Marcel Marzec on 14/05/2026.
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class UserPreferencesModel {
    var vatsimCID: Int
    var lastLatitude: Double
    var lastLongitude: Double
    var lastZoom: Double
    var vatsimRefreshRate: String
    var totalAdsWatched: Int
    var showInactiveSectors: Bool = false
    var showAirports: Bool = false
    var altitudeFilterEnabled: Bool = false

    init(
        vatsimCID: Int,
        lastLatitude: Double,
        lastLongitude: Double,
        lastZoom: Double,
        vatsimRefreshRate: String = "15s",
        totalAdsWatched: Int = 0,
        showInactiveSectors: Bool = false,
        showAirports: Bool = false,
        altitudeFilterEnabled: Bool = false
    ) {
        self.vatsimCID = vatsimCID
        self.lastLatitude = lastLatitude
        self.lastLongitude = lastLongitude
        self.lastZoom = lastZoom
        self.vatsimRefreshRate = vatsimRefreshRate
        self.totalAdsWatched = totalAdsWatched
        self.showInactiveSectors = showInactiveSectors
        self.showAirports = showAirports
        self.altitudeFilterEnabled = altitudeFilterEnabled
    }

    convenience init() {
        self.init(
            vatsimCID: 0,
            lastLatitude: 51.5074,
            lastLongitude: -0.1278,
            lastZoom: 3,
            vatsimRefreshRate: "15s",
            totalAdsWatched: 0
        )
    }
}
