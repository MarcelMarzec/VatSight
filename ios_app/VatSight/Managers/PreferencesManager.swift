//
//  PreferencesManager.swift
//  VatSight
//
//  Created by Marcel Marzec on 14/05/2026.
//


import SwiftUI
import SwiftData

@Observable
final class PreferencesManager {

    private let context: ModelContext

    var userPrefs: UserPreferencesModel

    init(context: ModelContext) {
        self.context = context

        let descriptor = FetchDescriptor<UserPreferencesModel>()

        do {
            let results = try context.fetch(descriptor)
            
            if let existing = results.first {
                self.userPrefs = existing
                print("✅ Loaded existing preferences - CID: \(existing.vatsimCID), Refresh: \(existing.vatsimRefreshRate)")
                
                // Ensure refresh rate is valid
                if existing.vatsimRefreshRate.isEmpty {
                    existing.vatsimRefreshRate = "15s"
                    try? context.save()
                }
            } else {
                let new = UserPreferencesModel()
                context.insert(new)
                try context.save()
                self.userPrefs = new
                print("✅ Created new preferences")
            }
        } catch {
            print("⚠️ Error fetching preferences: \(error)")
            // Create a new one if fetch fails
            let new = UserPreferencesModel()
            context.insert(new)
            try? context.save()
            self.userPrefs = new
        }
    }

    func updateCID(_ cid: Int) {
        userPrefs.vatsimCID = cid
        do {
            try context.save()
            print("✅ CID saved: \(cid)")
        } catch {
            print("❌ Error saving CID: \(error)")
        }
    }

    func updateLocation(lat: Double, lon: Double) {
        userPrefs.lastLatitude = lat
        userPrefs.lastLongitude = lon
        do {
            try context.save()
            print("✅ Location saved: \(lat), \(lon)")
        } catch {
            print("❌ Error saving location: \(error)")
        }
    }
    
    func updateRefreshRate(_ rate: String) {
        userPrefs.vatsimRefreshRate = rate
        do {
            try context.save()
            print("✅ Refresh rate saved: \(rate)")
        } catch {
            print("❌ Error saving refresh rate: \(error)")
        }
    }
    
    func updateShowInactiveSectors(_ value: Bool) {
        userPrefs.showInactiveSectors = value
        try? context.save()
    }

    func updateShowAirports(_ value: Bool) {
        userPrefs.showAirports = value
        try? context.save()
    }

    func updateAltitudeFilterEnabled(_ value: Bool) {
        userPrefs.altitudeFilterEnabled = value
        try? context.save()
    }

    func incrementAdsWatched(by count: Int = 1) {
        userPrefs.totalAdsWatched += count
        do {
            try context.save()
            print("✅ Total ads watched saved: \(userPrefs.totalAdsWatched)")
        } catch {
            print("❌ Error saving ads watched: \(error)")
        }
    }

    func getRefreshIntervalInSeconds() -> TimeInterval {
        let rateString = userPrefs.vatsimRefreshRate
        
        if rateString.hasSuffix("min") {
            let numberString = rateString.replacingOccurrences(of: "min", with: "")
            let minutes = Int(numberString) ?? 1
            return TimeInterval(minutes * 60)
        } else {
            let numberString = rateString.replacingOccurrences(of: "s", with: "")
            return TimeInterval(Int(numberString) ?? 15)
        }
    }
}
