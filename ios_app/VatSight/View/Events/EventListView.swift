//
//  EventListView.swift
//  VatSight
//

import SwiftUI

struct EventListSection: Identifiable {
    let id: String
    let title: String
    let events: [VatsimEvent]

    /// "Happening Now", then one section per day ("Today", "Tomorrow", "Sunday 22 November").
    static func make(from events: [VatsimEvent], now: Date, display: EventTimeDisplay) -> [EventListSection] {
        let calendar = EventTimeFormatting.calendar(for: display)
        var live: [VatsimEvent] = []
        var byDay: [Date: [VatsimEvent]] = [:]
        var dayOrder: [Date] = []

        for event in events where event.endTime > now {
            if event.startTime <= now {
                live.append(event)
                continue
            }
            let day = calendar.startOfDay(for: event.startTime)
            if byDay[day] == nil { dayOrder.append(day) }
            byDay[day, default: []].append(event)
        }

        var sections: [EventListSection] = []
        if !live.isEmpty {
            sections.append(EventListSection(id: "live", title: "Happening Now", events: live))
        }
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)
        for day in dayOrder.sorted() {
            let title: String
            if day == today {
                title = "Later Today"
            } else if day == tomorrow {
                title = "Tomorrow"
            } else {
                title = EventTimeFormatting.longDate(day, display: display)
            }
            sections.append(EventListSection(id: "day-\(Int(day.timeIntervalSince1970))", title: title, events: byDay[day] ?? []))
        }
        return sections
    }
}

struct EventListView: View {
    let events: [VatsimEvent]
    let timeDisplay: EventTimeDisplay
    var orgs: VatsimOrgDirectory = .empty
    let onSelect: (VatsimEvent) -> Void

    var body: some View {
        TimelineView(.everyMinute) { context in
            let sections = EventListSection.make(from: events, now: context.date, display: timeDisplay)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14, pinnedViews: [.sectionHeaders]) {
                    ForEach(sections) { section in
                        Section {
                            ForEach(section.events) { event in
                                EventCardView(
                                    event: event,
                                    timeDisplay: timeDisplay,
                                    organiserSummary: event.organisers.first.map { orgs.summary(for: $0) } ?? ""
                                ) {
                                    onSelect(event)
                                }
                            }
                        } header: {
                            EventSectionHeader(title: section.title, count: section.events.count)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(Color(.systemBackground))
        }
    }
}

private struct EventSectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)
            Spacer()
            Text("\(count)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityLabel("\(count) event\(count == 1 ? "" : "s")")
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
