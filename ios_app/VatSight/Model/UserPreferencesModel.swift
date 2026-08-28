//
//  UserPreferencesModel.swift
//  VatSight
//
//  Created by Marcel Marzec on 14/05/2026.
//

import Foundation
import SwiftUI
import SwiftData
import CoreLocation

/// Available Mapbox map styles.
enum MapStyle: String, CaseIterable, Codable {
    /// Follows the device Dark/Light Mode setting automatically (Night for dark OS, Day for light OS).
    case system = "system"
    case night  = "mapbox://styles/marcelm005/cmtcmn6pd001c01s103yaa658"
    case dark   = "mapbox://styles/marcelm005/cmtbcipzx000n01qs9hurffuj"
    case day    = "mapbox://styles/marcelm005/cmsqqh36z015101pd5ugz3r6a"

    var displayName: String {
        switch self {
        case .system: return "System"
        case .night:  return "Night"
        case .dark:   return "Dark"
        case .day:    return "Day"
        }
    }

    /// The Mapbox style URL string for the concrete style,
    /// or nil for system (which must be resolved at the call site with `resolvedURLString(isDark:)`).
    var concreteURLString: String? {
        switch self {
        case .system: return nil
        case .night, .dark, .day: return rawValue
        }
    }

    /// Returns the URL string for the resolved style, picking Night or Day when System is selected.
    func resolvedURLString(isDark: Bool) -> String? {
        switch self {
        case .system: return isDark ? MapStyle.night.rawValue : MapStyle.day.rawValue
        case .night, .dark, .day: return rawValue
        }
    }

    /// The preferred app theme to pair with this map style.
    var preferredAppTheme: AppTheme {
        switch self {
        case .system: return .system
        case .night:  return .dark
        case .dark:   return .dark
        case .day:    return .light
        }
    }
}

/// The app-level color scheme preference.
enum AppTheme: String, CaseIterable, Codable {
    case system = "system"
    case dark   = "dark"
    case light  = "light"

    var displayName: String {
        switch self {
        case .system: return "System"
        case .dark:   return "Dark"
        case .light:  return "Light"
        }
    }

    /// The SwiftUI ColorScheme override for this theme.
    /// Returns `nil` for `.system` so SwiftUI follows the OS preference.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark:   return .dark
        case .light:  return .light
        }
    }
}

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
    var mergeSectors: Bool = false
    var trackedCIDs: [Int] = []
    var hasCompletedOnboarding: Bool = false
    var developerModeEnabled: Bool = false
    /// Custom GitHub repo slug (e.g. "owner/repo") for Vatglasses data. Empty string = use default.
    var vatglassesCustomRepoSlug: String = ""
    /// Raw value of `MapStyle` — stored as String for SwiftData compatibility.
    var mapStyleRaw: String = MapStyle.system.rawValue
    /// Raw value of `AppTheme` — stored as String for SwiftData compatibility.
    var appThemeRaw: String = AppTheme.system.rawValue

    var mapStyle: MapStyle {
        get { MapStyle(rawValue: mapStyleRaw) ?? .system }
        set { mapStyleRaw = newValue.rawValue }
    }

    var appTheme: AppTheme {
        get { AppTheme(rawValue: appThemeRaw) ?? .dark }
        set { appThemeRaw = newValue.rawValue }
    }

    init(
        vatsimCID: Int,
        lastLatitude: Double,
        lastLongitude: Double,
        lastZoom: Double,
        vatsimRefreshRate: String = "15s",
        totalAdsWatched: Int = 0,
        showInactiveSectors: Bool = false,
        showAirports: Bool = false,
        altitudeFilterEnabled: Bool = false,
        mergeSectors: Bool = false,
        trackedCIDs: [Int] = [],
        hasCompletedOnboarding: Bool = false,
        developerModeEnabled: Bool = false,
        vatglassesCustomRepoSlug: String = "",
        mapStyle: MapStyle = .system,
        appTheme: AppTheme = .system
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
        self.mergeSectors = mergeSectors
        self.trackedCIDs = trackedCIDs
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.developerModeEnabled = developerModeEnabled
        self.vatglassesCustomRepoSlug = vatglassesCustomRepoSlug
        self.mapStyleRaw = mapStyle.rawValue
        self.appThemeRaw = appTheme.rawValue
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
