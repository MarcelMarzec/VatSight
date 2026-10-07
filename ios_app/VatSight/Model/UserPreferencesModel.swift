//
//  UserPreferencesModel.swift
//  VatSight
//

import Foundation
import SwiftUI
import SwiftData
import CoreLocation

enum MapStyle: String, CaseIterable, Codable {
    case system = "system" // follows OS dark/light
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

    /// nil for system — resolve with `resolvedURLString(isDark:)` at the call site.
    var concreteURLString: String? {
        switch self {
        case .system: return nil
        case .night, .dark, .day: return rawValue
        }
    }

    func resolvedURLString(isDark: Bool) -> String? {
        switch self {
        case .system: return isDark ? MapStyle.night.rawValue : MapStyle.day.rawValue
        case .night, .dark, .day: return rawValue
        }
    }

    var preferredAppTheme: AppTheme {
        switch self {
        case .system: return .system
        case .night:  return .dark
        case .dark:   return .dark
        case .day:    return .light
        }
    }
}

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

    /// nil for `.system` — SwiftUI follows OS.
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
    var showInactiveSectors: Bool = false
    var showAirports: Bool = false
    var showPilotsLayer: Bool = true
    var showSectorsLayer: Bool = true
    var showAirportLayer: Bool = true
    var altitudeFilterEnabled: Bool = false
    var mergeSectors: Bool = false
    var friendCIDs: [Int] = []
    var hasCompletedOnboarding: Bool = false
    var developerModeEnabled: Bool = false
    var vatglassesCustomRepoSlug: String = "" // custom "owner/repo"; empty = default
    var mapStyleRaw: String = MapStyle.system.rawValue   // String for SwiftData
    var appThemeRaw: String = AppTheme.system.rawValue   // String for SwiftData
    var planeIconMultiplier: Double = 1.0
    var airportIconMultiplier: Double = 1.0
    var searchSelectedFacilities: [Int] = []
    var searchExcludedFacilities: [Int] = [0] // ID 0 (Observer) excluded by default
    var searchCategoryRaw: String = "ATC"
    var searchShowInactiveAirports: Bool = false
    var swipeToAddFriendHintCount: Int = 0 // hidden after 3 uses
    var hapticFeedbackEnabled: Bool = true

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
        showInactiveSectors: Bool = false,
        showAirports: Bool = false,
        showPilotsLayer: Bool = true,
        showSectorsLayer: Bool = true,
        showAirportLayer: Bool = true,
        altitudeFilterEnabled: Bool = false,
        mergeSectors: Bool = false,
        friendCIDs: [Int] = [],
        hasCompletedOnboarding: Bool = false,
        developerModeEnabled: Bool = false,
        vatglassesCustomRepoSlug: String = "",
        mapStyle: MapStyle = .system,
        appTheme: AppTheme = .system,
        planeIconMultiplier: Double = 1.0,
        airportIconMultiplier: Double = 1.0
    ) {
        self.vatsimCID = vatsimCID
        self.lastLatitude = lastLatitude
        self.lastLongitude = lastLongitude
        self.lastZoom = lastZoom
        self.vatsimRefreshRate = vatsimRefreshRate
        self.showInactiveSectors = showInactiveSectors
        self.showAirports = showAirports
        self.showPilotsLayer = showPilotsLayer
        self.showSectorsLayer = showSectorsLayer
        self.showAirportLayer = showAirportLayer
        self.altitudeFilterEnabled = altitudeFilterEnabled
        self.mergeSectors = mergeSectors
        self.friendCIDs = friendCIDs
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.developerModeEnabled = developerModeEnabled
        self.vatglassesCustomRepoSlug = vatglassesCustomRepoSlug
        self.mapStyleRaw = mapStyle.rawValue
        self.appThemeRaw = appTheme.rawValue
        self.planeIconMultiplier = planeIconMultiplier
        self.airportIconMultiplier = airportIconMultiplier
    }

    convenience init() {
        self.init(
            vatsimCID: 0,
            lastLatitude: 51.5074,
            lastLongitude: -0.1278,
            lastZoom: 3,
            vatsimRefreshRate: "15s"
        )
    }
}
