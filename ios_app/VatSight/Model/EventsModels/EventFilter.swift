//
//  EventFilter.swift
//  VatSight
//
//  The Events tab filter. Persisted in UserPreferencesModel via PreferencesManager.eventFilter.
//

import Foundation

struct EventFilter: Equatable {
    /// Empty means all types.
    var types: Set<VatsimEventType> = []
    /// Region ID, e.g. "EMEA".
    var region: String? = nil
    /// Division ID, e.g. "EUD".
    var division: String? = nil
    var vatsimOrganisedOnly = false

    var isActive: Bool {
        !types.isEmpty || region != nil || division != nil || vatsimOrganisedOnly
    }

    func matches(_ event: VatsimEvent) -> Bool {
        if !types.isEmpty, !types.contains(event.type) { return false }
        if let region, !event.organisers.contains(where: { $0.region == region }) { return false }
        if let division, !event.organisers.contains(where: { $0.division == division }) { return false }
        if vatsimOrganisedOnly, !event.isOrganisedByVatsim { return false }
        return true
    }
}
