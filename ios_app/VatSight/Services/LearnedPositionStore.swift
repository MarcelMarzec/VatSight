//
//  LearnedPositionStore.swift
//  VatSight
//
//  Remembers which VATGlasses positions a callsign actually covered when it was last online.
//  Live controllers are matched to positions by frequency, which bookings don't have, so a
//  booking for a callsign we've seen before can use the real answer instead of a guess.
//  Persisted across launches; entries not seen for a long time are dropped.
//

import Foundation

final class LearnedPositionStore {

    private struct Entry: Codable, Equatable {
        var keys: [String]
        var lastSeen: Date
    }

    private var entries: [String: Entry] = [:]
    private var isDirty = false
    private var lastSave = Date.distantPast

    private static let maxAge: TimeInterval = 120 * 24 * 3600
    private static let saveInterval: TimeInterval = 60
    /// Only refresh `lastSeen` this often so an unchanged entry doesn't mark the store dirty every refresh.
    private static let touchInterval: TimeInterval = 24 * 3600

    private let fileURL: URL = {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "learned_booking_positions.json")
    }()

    init() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) else { return }
        let cutoff = Date().addingTimeInterval(-Self.maxAge)
        entries = decoded.filter { $0.value.lastSeen >= cutoff }
    }

    var count: Int { entries.count }

    /// Position keys last seen for this callsign, if any.
    func keys(for callsign: String) -> [String]? {
        entries[callsign.uppercased()]?.keys
    }

    /// Records live observations: callsign → the position keys it owned this refresh.
    func record(_ observations: [String: Set<String>], now: Date = Date()) {
        for (callsign, keySet) in observations where !keySet.isEmpty {
            let keys = keySet.sorted()
            if let existing = entries[callsign],
               existing.keys == keys,
               now.timeIntervalSince(existing.lastSeen) < Self.touchInterval {
                continue
            }
            entries[callsign] = Entry(keys: keys, lastSeen: now)
            isDirty = true
        }
        saveIfNeeded(now: now)
    }

    /// Writes pending changes now (e.g. when the app moves to the background).
    func flush() {
        saveIfNeeded(now: Date(), force: true)
    }

    func removeAll() {
        entries.removeAll()
        isDirty = true
        saveIfNeeded(now: Date(), force: true)
    }

    private func saveIfNeeded(now: Date, force: Bool = false) {
        guard isDirty, force || now.timeIntervalSince(lastSave) >= Self.saveInterval else { return }
        isDirty = false
        lastSave = now
        guard let data = try? JSONEncoder().encode(entries) else { return }
        let url = fileURL
        Task.detached(priority: .utility) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
