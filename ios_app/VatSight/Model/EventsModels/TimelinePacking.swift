//
//  TimelinePacking.swift
//  VatSight
//
//  Lays out overlapping events side by side within a day column, the way Apple Calendar's
//  day/week views do: events that overlap (directly or through a chain) form a cluster,
//  each event takes the first free column in its cluster, and every event in the cluster
//  shares the cluster's column count. O(n log n) per day.
//

import Foundation

nonisolated struct TimelineItem<ID: Hashable & Sendable>: Sendable {
    let id: ID
    let start: Date
    let end: Date
}

nonisolated struct TimelinePlacement<ID: Hashable & Sendable>: Sendable {
    let id: ID
    /// Fractions of the day (0...1).
    let startFraction: Double
    let endFraction: Double
    let column: Int
    let columnCount: Int
}

/// Events hidden because their cluster needed more columns than allowed.
nonisolated struct TimelineOverflow<ID: Hashable & Sendable>: Sendable {
    let hiddenIDs: [ID]
    /// Where to draw the "+N" marker.
    let startFraction: Double
    let column: Int
    let columnCount: Int
}

nonisolated struct TimelineLayoutResult<ID: Hashable & Sendable>: Sendable {
    var placements: [TimelinePlacement<ID>] = []
    var overflows: [TimelineOverflow<ID>] = []
}

nonisolated struct TimelineClippedItem<ID: Hashable & Sendable>: Sendable {
    let id: ID
    let start: Date
    /// Real (clipped) end, used for drawing.
    let end: Date
    /// End padded to the minimum duration, used for overlap detection.
    let layoutEnd: Date
}

nonisolated enum TimelinePacking {

    /// - Parameters:
    ///   - items: Events (any range; they are clipped to the day).
    ///   - dayStart/dayEnd: The day being laid out.
    ///   - minimumDuration: Short events are treated as at least this long so blocks that are
    ///     drawn taller than their duration don't visually overlap a neighbour.
    ///   - maxColumns: Columns beyond this are collapsed into a "+N" overflow marker.
    static func layout<ID: Hashable & Sendable>(
        _ items: [TimelineItem<ID>],
        dayStart: Date,
        dayEnd: Date,
        minimumDuration: TimeInterval = 30 * 60,
        maxColumns: Int = .max
    ) -> TimelineLayoutResult<ID> {
        let dayLength = dayEnd.timeIntervalSince(dayStart)
        guard dayLength > 0 else { return TimelineLayoutResult() }

        typealias Clipped = TimelineClippedItem<ID>

        let clipped: [Clipped] = items.compactMap { item in
            let start = max(item.start, dayStart)
            let end = min(item.end, dayEnd)
            guard end > start || (item.start >= dayStart && item.start < dayEnd) else { return nil }
            let realEnd = max(end, start)
            let layoutEnd = min(max(realEnd, start.addingTimeInterval(minimumDuration)), dayEnd.addingTimeInterval(minimumDuration))
            return Clipped(id: item.id, start: start, end: realEnd, layoutEnd: layoutEnd)
        }
        .sorted { a, b in
            if a.start != b.start { return a.start < b.start }
            return a.layoutEnd > b.layoutEnd // longer first
        }

        let limit = max(1, maxColumns)
        var result = TimelineLayoutResult<ID>()

        var cluster: [(item: Clipped, column: Int)] = []
        var columnEnds: [Date] = []
        var clusterEnd = Date.distantPast

        func fraction(_ date: Date) -> Double {
            min(max(date.timeIntervalSince(dayStart) / dayLength, 0), 1)
        }

        func flushCluster() {
            guard !cluster.isEmpty else { return }
            let columnCount = columnEnds.count
            let visibleCount = min(columnCount, limit)
            let overflowing = columnCount > limit
            // When overflowing, the last visible column is used for the "+N" marker.
            let lastUsableColumn = overflowing ? visibleCount - 1 : visibleCount

            var hidden: [Clipped] = []
            for entry in cluster {
                if entry.column < lastUsableColumn {
                    result.placements.append(TimelinePlacement(
                        id: entry.item.id,
                        startFraction: fraction(entry.item.start),
                        endFraction: fraction(entry.item.end),
                        column: entry.column,
                        columnCount: visibleCount
                    ))
                } else {
                    hidden.append(entry.item)
                }
            }
            if !hidden.isEmpty {
                let earliest = hidden.map(\.start).min() ?? dayStart
                result.overflows.append(TimelineOverflow(
                    hiddenIDs: hidden.map(\.id),
                    startFraction: fraction(earliest),
                    column: max(lastUsableColumn, 0),
                    columnCount: visibleCount
                ))
            }
            cluster.removeAll()
            columnEnds.removeAll()
            clusterEnd = .distantPast
        }

        for item in clipped {
            if item.start >= clusterEnd { flushCluster() }
            if let free = columnEnds.firstIndex(where: { $0 <= item.start }) {
                columnEnds[free] = item.layoutEnd
                cluster.append((item, free))
            } else {
                columnEnds.append(item.layoutEnd)
                cluster.append((item, columnEnds.count - 1))
            }
            clusterEnd = max(clusterEnd, item.layoutEnd)
        }
        flushCluster()
        return result
    }
}
