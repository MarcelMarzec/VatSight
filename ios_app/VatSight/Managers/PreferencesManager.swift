import SwiftUI
import SwiftData

@Observable
final class PreferencesManager {

    private let context: ModelContext

    var userPrefs: UserPreferencesModel

    init(context: ModelContext) {
        self.context = context

        // Fetch existing preferences (single-instance pattern)
        let descriptor = FetchDescriptor<UserPreferencesModel>()

        if let existing = try? context.fetch(descriptor).first {
            self.userPrefs = existing
        } else {
            let new = UserPreferencesModel()
            context.insert(new)
            self.userPrefs = new
        }
    }

    // MARK: - Updates

    func updateCID(_ cid: Int) {
        userPrefs.vatsimCID = cid
    }

    func updateTheme(_ theme: String) {
        userPrefs.preferredTheme = theme
    }

    func updateLocation(lat: Double, lon: Double) {
        userPrefs.lastLatitude = lat
        userPrefs.lastLongitude = lon
    }
}