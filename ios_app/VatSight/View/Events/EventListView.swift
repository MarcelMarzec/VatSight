//
//  EventListView.swift
//  VatSight
//

import SwiftUI
import GoogleMobileAds

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
    /// Native ads placed between cards; empty when list ads are off.
    var ads: [NativeAd] = []
    var onCurrentSectionChange: (String?) -> Void = { _ in }
    let onSelect: (VatsimEvent) -> Void

    @State private var scrolledPastSections: Set<String> = []

    /// Not scrollable itself: it sits inside the Events page's scroll view.
    var body: some View {
        TimelineView(.everyMinute) { context in
            let sections = EventListSection.make(from: events, now: context.date, display: timeDisplay)
            let adSlots = Self.adSlots(for: sections.flatMap(\.events), adCount: ads.count)
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(sections) { section in
                    EventSectionHeader(title: section.title, count: section.events.count)
                        .onGeometryChange(for: Bool.self) { proxy in
                            // Measured from the top of the visible area, below the bars.
                            proxy.frame(in: .scrollView).minY < 0
                        } action: { isPast in
                            var past = scrolledPastSections
                            if isPast { past.insert(section.id) } else { past.remove(section.id) }
                            scrolledPastSections = past
                            onCurrentSectionChange(sections.last { past.contains($0.id) }?.title)
                        }
                    ForEach(section.events) { event in
                        EventCardView(
                            event: event,
                            timeDisplay: timeDisplay,
                            organiserSummary: event.organisers.first.map { orgs.summary(for: $0) } ?? ""
                        ) {
                            onSelect(event)
                        }
                        if let slot = adSlots[event.id] {
                            NativeAdBannerView(nativeAd: ads[slot])
                                .frame(height: NativeAdBannerView.height)
                                .padding(12)
                                .vatSightCard()
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    /// Event ID → ad index for the ad shown after it. Gaps of 5–10 events vary per event but stay
    /// stable across refreshes, so ads don't jump around. Each ad is placed once: the SDK only
    /// tracks a native ad in one view.
    static func adSlots(for events: [VatsimEvent], adCount: Int) -> [Int: Int] {
        guard adCount > 0, let first = events.first else { return [:] }
        func gap(after id: Int) -> Int { 5 + Int(UInt(bitPattern: id &* 2654435761) % 6) }
        var slots: [Int: Int] = [:]
        var remaining = gap(after: first.id)
        for event in events.dropLast() where slots.count < adCount {
            remaining -= 1
            guard remaining == 0 else { continue }
            slots[event.id] = slots.count
            remaining = gap(after: event.id)
        }
        return slots
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
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
