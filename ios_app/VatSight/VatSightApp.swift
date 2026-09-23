//
//  VatSightApp.swift
//  VatSight
//
//  Created by Marcel Marzec on 06/05/2026.
//

import SwiftUI
import SwiftData

@main
struct VatSightApp: App {
    let container: ModelContainer
    
    init() {
        // Opt out of Mapbox telemetry. Does not affect the anonymous MAU ping
        // required by Mapbox's ToS (no device/session/IP data in that ping).
        UserDefaults.standard.set(false, forKey: "MGLMapboxMetricsEnabled")

        let schema = Schema([UserPreferencesModel.self])
        let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isPreview)
        
        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            // Migration failed — delete the old store and start fresh.
            if !isPreview {
                let storeURL = URL.applicationSupportDirectory.appending(path: "default.store")
                for ext in ["", "-shm", "-wal"] {
                    try? FileManager.default.removeItem(at: storeURL.appendingPathExtension(ext).deletingPathExtension().appendingPathExtension("store\(ext)"))
                }
                try? FileManager.default.removeItem(at: storeURL)
            }
            // Last resort: in-memory only - prefs won't persist but the app stays functional.
            // try! is safe: an in-memory container has no disk I/O to fail.
            let inMemoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            container = try! ModelContainer(for: schema, configurations: inMemoryConfig)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
