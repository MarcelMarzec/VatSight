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

        if let existing = try? context.fetch(descriptor).first {
            self.userPrefs = existing
        } else {
            let new = UserPreferencesModel()
            context.insert(new)
            self.userPrefs = new
        }
    }

    func updateCID(_ cid: Int) {
        userPrefs.vatsimCID = cid
    }

    func updateLocation(lat: Double, lon: Double) {
        userPrefs.lastLatitude = lat
        userPrefs.lastLongitude = lon
    }
}
