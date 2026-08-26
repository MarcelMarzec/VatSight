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
        let schema = Schema([UserPreferencesModel.self])
        
        // Check if we're in preview mode or if we should use in-memory storage
        let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isPreview)
        
        do {
            container = try ModelContainer(for: schema, configurations: config)
            print("✅ ModelContainer initialized successfully (isPreview: \(isPreview))")
        } catch {
            // Migration failed — delete the old store and start fresh rather than
            // silently falling back to in-memory (which loses prefs every launch).
            print("⚠️ Failed to initialize ModelContainer: \(error)")
            print("Deleting corrupt store and recreating...")
            if !isPreview {
                let storeURL = URL.applicationSupportDirectory.appending(path: "default.store")
                for ext in ["", "-shm", "-wal"] {
                    try? FileManager.default.removeItem(at: storeURL.appendingPathExtension(ext).deletingPathExtension().appendingPathExtension("store\(ext)"))
                }
                // Also try the plain path
                try? FileManager.default.removeItem(at: storeURL)
            }
            let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isPreview)
            do {
                container = try ModelContainer(for: schema, configurations: fallbackConfig)
                print("✅ Recreated ModelContainer after store deletion")
            } catch {
                fatalError("Failed to initialize ModelContainer after store deletion: \(error)")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
