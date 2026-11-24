//
//  EventTimelineView.swift
//  VatSight
//
//  One day at a time on a 24-hour timeline. Every event of the day is drawn: overlapping
//  events cascade on top of each other, each one indented a step further so all of them stay
//  visible and tappable. Events of 24 hours or more sit in a strip above the timeline.
//  Only events are shown (no ATC bookings). Not scrollable itself: it sits inside the Events
//  page's scroll view, whose toolbar also has a day menu (`EventDayMenu`).
//

import SwiftUI

struct EventTimelineView: View {
    let events: [VatsimEvent]
    let timeDisplay: EventTimeDisplay
    /// Start of the selected day; nil follows today. Shared with the day menu in the page's toolbar.
    @Binding var selectedDay: Date?
    /// Scrolls the Events page to a content offset; used to bring the day's first relevant hour into view.
    var onScrollTo: ((CGFloat) -> Void)?
    let onSelect: (VatsimEvent) -> Void

    /// The day the page was last scrolled for, so it only happens once per day shown.
    @State private var scrolledDay: Date?
    @State private var scrolledAt = Date.distantPast

    @ScaledMetric(relativeTo: .caption) private var hourHeight: CGFloat = 64
    @ScaledMetric(relativeTo: .caption2) private var rulerWidth: CGFloat = 50
    @Environment(PreferencesManager.self) private var prefsManager

    private static let longEventThreshold: TimeInterval = 24 * 3600

    private var calendar: Calendar { EventTimeFormatting.calendar(for: timeDisplay) }

    var body: some View {
        let today = calendar.startOfDay(for: Date())
        let days = Self.availableDays(events: events, today: today, calendar: calendar)
        let day = Self.resolvedDay(selectedDay, days: days, today: today)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        let dayEvents = events.filter { $0.overlaps(day, dayEnd) }
        let longEvents = dayEvents.filter { $0.duration >= Self.longEventThreshold }
        let timedEvents = dayEvents.filter { $0.duration < Self.longEventThreshold }

        VStack(spacing: 0) {
            DayStrip(
                days: days,
                selected: day,
                today: today,
                calendar: calendar,
                display: timeDisplay,
                counts: Self.eventCounts(events: events, days: days, calendar: calendar)
            ) { newDay in
                Self.select(newDay, in: $selectedDay, calendar: calendar, haptics: prefsManager.userPrefs.hapticFeedbackEnabled)
            }

            if !longEvents.isEmpty {
                LongEventStrip(events: longEvents, timeDisplay: timeDisplay, onSelect: onSelect)
            }

            Divider()

            if timedEvents.isEmpty && longEvents.isEmpty {
                ContentUnavailableView {
                    Label("No Events", systemImage: "calendar")
                } description: {
                    Text("Nothing scheduled on \(EventTimeFormatting.longDate(day, display: timeDisplay)).")
                }
                .padding(.vertical, 32)
            } else {
                timeline(day: day, dayEnd: dayEnd, events: timedEvents, isToday: day == today)
                    .id(day) // re-runs the scroll to the day's first hour
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    let dx = value.translation.width
                    let dy = value.translation.height
                    guard abs(dx) > 70, abs(dx) > abs(dy) * 2,
                          let index = days.firstIndex(of: day) else { return }
                    let next = dx < 0 ? index + 1 : index - 1
                    guard days.indices.contains(next) else { return }
                    Self.select(days[next], in: $selectedDay, calendar: calendar, haptics: prefsManager.userPrefs.hapticFeedbackEnabled)
                }
        )
    }

    // MARK: - Days

    static func select(_ day: Date, in selection: Binding<Date?>, calendar: Calendar, haptics: Bool) {
        guard day != selection.wrappedValue else { return }
        HapticManager.impact(prefsEnabled: haptics)
        withAnimation(.snappy) {
            selection.wrappedValue = day == calendar.startOfDay(for: Date()) ? nil : day
        }
    }

    /// The selected day if it still has events, otherwise today.
    static func resolvedDay(_ selected: Date?, days: [Date], today: Date) -> Date {
        selected.flatMap { days.contains($0) ? $0 : nil } ?? today
    }

    /// Today plus every day that has an event, in order.
    static func availableDays(events: [VatsimEvent], today: Date, calendar: Calendar) -> [Date] {
        var days: Set<Date> = [today]
        for event in events {
            var cursor = max(calendar.startOfDay(for: event.startTime), today)
            let last = calendar.startOfDay(for: event.endTime > event.startTime ? event.endTime.addingTimeInterval(-1) : event.endTime)
            // Cap the walk so a malformed multi-week event can't flood the strip.
            var steps = 0
            while cursor <= last && steps < 14 {
                days.insert(cursor)
                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
                steps += 1
            }
        }
        return days.sorted()
    }

    static func eventCounts(events: [VatsimEvent], days: [Date], calendar: Calendar) -> [Date: Int] {
        var counts: [Date: Int] = [:]
        for day in days {
            let end = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            counts[day] = events.reduce(0) { $0 + ($1.overlaps(day, end) ? 1 : 0) }
        }
        return counts
    }

    // MARK: - Timeline

    private func timeline(day: Date, dayEnd: Date, events: [VatsimEvent], isToday: Bool) -> some View {
        let totalHeight = hourHeight * 24
        let layout = TimelinePacking.layout(
            events.map { TimelineItem(id: $0.id, start: $0.startTime, end: $0.endTime) },
            dayStart: day,
            dayEnd: dayEnd,
            minimumDuration: 45 * 60
        )
        let lookup = Dictionary(events.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let firstHour = events.map { max($0.startTime, day) }.min().map { calendar.component(.hour, from: $0) } ?? 8
        let scrollHour = isToday ? max(0, calendar.component(.hour, from: Date()) - 1) : max(0, firstHour - 1)

        return HStack(alignment: .top, spacing: 0) {
            HourRuler(hourHeight: hourHeight, width: rulerWidth, timeDisplay: timeDisplay)

            CascadeLayout(totalHeight: totalHeight, minimumBlockHeight: max(46, hourHeight * 0.72)) {
                // Lower levels first so each indented event draws over the one it overlaps.
                ForEach(layout.placements.sorted { $0.column < $1.column }, id: \.id) { placement in
                    if let event = lookup[placement.id] {
                        TimelineEventBlock(event: event, timeDisplay: timeDisplay, isIndented: placement.column > 0)
                            .layoutValue(key: CascadeSlotKey.self, value: CascadeSlot(
                                start: placement.startFraction,
                                end: placement.endFraction,
                                level: placement.column,
                                levels: placement.columnCount
                            ))
                            .zIndex(Double(placement.column))
                            .onTapGesture { onSelect(event) }
                            .accessibilityAction(.default) { onSelect(event) }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: totalHeight)
            .padding(.trailing, 12)
            .overlay(alignment: .top) {
                if isToday {
                    NowLine(dayStart: day, dayEnd: dayEnd, totalHeight: totalHeight)
                }
            }
        }
        .frame(height: totalHeight)
        .background(alignment: .topLeading) {
            HourGrid(hourHeight: hourHeight)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                .padding(.leading, rulerWidth)
        }
        // Measured in page coordinates: the hour sits in a lazy section, out of reach of ScrollViewReader.
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.frame(in: .named(EventsView.pageCoordinateSpace)).minY
        } action: { top in
            // Layout may still be animating (e.g. switching from List), so follow it briefly.
            let isSettling = Date().timeIntervalSince(scrolledAt) < 0.6
            guard scrolledDay != day || isSettling else { return }
            if scrolledDay != day {
                scrolledDay = day
                scrolledAt = Date()
            }
            onScrollTo?(max(0, top + hourHeight * CGFloat(scrollHour) - 8))
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Day Strip

/// Toolbar menu for jumping to a timeline day, so the day stays reachable once the strip scrolls away.
struct EventDayMenu: View {
    let events: [VatsimEvent]
    let timeDisplay: EventTimeDisplay
    @Binding var selectedDay: Date?
    @Environment(PreferencesManager.self) private var prefsManager

    var body: some View {
        let calendar = EventTimeFormatting.calendar(for: timeDisplay)
        let today = calendar.startOfDay(for: Date())
        let days = EventTimelineView.availableDays(events: events, today: today, calendar: calendar)
        let counts = EventTimelineView.eventCounts(events: events, days: days, calendar: calendar)
        Menu {
            Picker("Day", selection: Binding(
                get: { EventTimelineView.resolvedDay(selectedDay, days: days, today: today) },
                set: { EventTimelineView.select($0, in: $selectedDay, calendar: calendar, haptics: prefsManager.userPrefs.hapticFeedbackEnabled) }
            )) {
                ForEach(days, id: \.self) { day in
                    Text("\(Self.title(day, today: today, calendar: calendar, display: timeDisplay)) (\(counts[day] ?? 0))")
                        .tag(day)
                }
            }
        } label: {
            Label("Day", systemImage: "calendar")
        }
    }

    /// "Today", "Tomorrow" or "Mon 23 Nov".
    static func title(_ day: Date, today: Date, calendar: Calendar, display: EventTimeDisplay) -> String {
        if day == today { return "Today" }
        if day == calendar.date(byAdding: .day, value: 1, to: today) { return "Tomorrow" }
        return EventTimeFormatting.shortDate(day, display: display)
    }

    /// Subtitle for the selected day.
    static func subtitle(events: [VatsimEvent], selectedDay: Date?, display: EventTimeDisplay) -> String {
        let calendar = EventTimeFormatting.calendar(for: display)
        let today = calendar.startOfDay(for: Date())
        let days = EventTimelineView.availableDays(events: events, today: today, calendar: calendar)
        let day = EventTimelineView.resolvedDay(selectedDay, days: days, today: today)
        return title(day, today: today, calendar: calendar, display: display)
    }
}

private struct DayStrip: View {
    let days: [Date]
    let selected: Date
    let today: Date
    let calendar: Calendar
    let display: EventTimeDisplay
    let counts: [Date: Int]
    let onSelect: (Date) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 8) {
                    ForEach(days, id: \.self) { day in
                        let isSelected = day == selected
                        Button {
                            onSelect(day)
                        } label: {
                            VStack(spacing: 2) {
                                Text(day == today ? "TODAY" : weekday(day))
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                                Text("\(calendar.component(.day, from: day))")
                                    .font(.title3.weight(.bold).monospacedDigit())
                                Text(month(day))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("\(counts[day] ?? 0)")
                                    .font(.caption2.weight(.semibold).monospacedDigit())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Color.primary.opacity(isSelected ? 0.2 : 0.08), in: Capsule())
                            }
                            .frame(width: 58)
                            .padding(.vertical, 8)
                            .background(
                                isSelected ? Color.primary.opacity(0.16) : Color.primary.opacity(0.05),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                            .overlay {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.3), lineWidth: 1)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .id(day)
                        .accessibilityLabel("\(EventTimeFormatting.longDate(day, display: display)), \(counts[day] ?? 0) events")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
            .onAppear { proxy.scrollTo(selected, anchor: .center) }
            .onChange(of: selected) { _, day in
                withAnimation(.snappy) { proxy.scrollTo(day, anchor: .center) }
            }
        }
        .frame(height: 104)
    }

    private func weekday(_ day: Date) -> String {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let index = calendar.component(.weekday, from: day) - 1
        return symbols.indices.contains(index) ? symbols[index].uppercased() : ""
    }

    private func month(_ day: Date) -> String {
        let symbols = calendar.shortStandaloneMonthSymbols
        let index = calendar.component(.month, from: day) - 1
        return symbols.indices.contains(index) ? symbols[index] : ""
    }
}

// MARK: - Long Events

private struct LongEventStrip: View {
    let events: [VatsimEvent]
    let timeDisplay: EventTimeDisplay
    let onSelect: (VatsimEvent) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(events) { event in
                    Button {
                        onSelect(event)
                    } label: {
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(event.type.tint)
                                .frame(width: 4)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.name)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text(EventTimeFormatting.dateLine(start: event.startTime, end: event.endTime, display: timeDisplay))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: 260, alignment: .leading)
                        .vatSightCard(cornerRadius: 12)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(event.accessibilitySummary(display: timeDisplay))
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Blocks

private struct TimelineEventBlock: View {
    let event: VatsimEvent
    let timeDisplay: EventTimeDisplay
    let isIndented: Bool

    var body: some View {
        let tint = event.type.tint
        let range = EventTimeFormatting.range(start: event.startTime, end: event.endTime, display: timeDisplay)
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(event.name)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(2)
                Spacer(minLength: 4)
                TimelineView(.everyMinute) { context in
                    if context.date >= event.startTime && context.date < event.endTime {
                        Text("LIVE")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.red, in: Capsule())
                    }
                }
            }
            Text(range.primary)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if !event.allICAOs.isEmpty {
                Text(event.allICAOs.joined(separator: " · "))
                    .font(.caption2.monospaced().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Opaque base so a cascaded event cleanly covers the one beneath it.
        .background(Color(.secondarySystemBackground))
        .overlay { tint.opacity(0.14).allowsHitTesting(false) }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(tint)
                .frame(width: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(tint.opacity(isIndented ? 0.7 : 0.4), lineWidth: 1)
        }
        .shadow(color: .black.opacity(isIndented ? 0.3 : 0.12), radius: isIndented ? 6 : 2, x: -2, y: 2)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(event.accessibilitySummary(display: timeDisplay))
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Layout

private struct CascadeSlot: Equatable {
    var start: Double
    var end: Double
    /// 0 for the first event in an overlap group, 1 for the next, …
    var level: Int
    /// Number of levels in this overlap group.
    var levels: Int
}

private struct CascadeSlotKey: LayoutValueKey {
    static let defaultValue = CascadeSlot(start: 0, end: 0, level: 0, levels: 1)
}

/// Places each event at its time; overlapping events are indented by their level instead of
/// sharing the width, so every block stays wide enough to read.
private struct CascadeLayout: Layout {
    let totalHeight: CGFloat
    var minimumBlockHeight: CGFloat = 46
    /// Indent per level, shrunk when a group is deep so the last block keeps half the width.
    var maximumIndent: CGFloat = 26

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: proposal.width ?? 200, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            let slot = subview[CascadeSlotKey.self]
            let deepest = CGFloat(max(slot.levels - 1, 1))
            let indent = min(maximumIndent, bounds.width * 0.5 / deepest)
            let x = bounds.minX + 6 + indent * CGFloat(slot.level)
            let y = bounds.minY + bounds.height * slot.start
            var height = max(minimumBlockHeight, bounds.height * (slot.end - slot.start))
            height = min(height, bounds.maxY - y)
            subview.place(
                at: CGPoint(x: x, y: y + 1),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: max(bounds.maxX - x, 40), height: max(height - 2, 1))
            )
        }
    }
}

private struct HourRuler: View {
    let hourHeight: CGFloat
    let width: CGFloat
    let timeDisplay: EventTimeDisplay

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                Text(label(hour))
                    .font(.caption2.monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: width - 8, height: hourHeight, alignment: .topTrailing)
                    .padding(.trailing, 8)
                    .offset(y: -6)
            }
        }
        .accessibilityHidden(true)
    }

    private func label(_ hour: Int) -> String {
        timeDisplay == .local ? String(format: "%02d:00", hour) : String(format: "%02d00Z", hour)
    }
}

private struct HourGrid: Shape {
    let hourHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for hour in 0...24 {
            let y = rect.minY + CGFloat(hour) * hourHeight
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return path
    }
}

private struct NowLine: View {
    let dayStart: Date
    let dayEnd: Date
    let totalHeight: CGFloat

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            if now >= dayStart && now < dayEnd {
                let fraction = now.timeIntervalSince(dayStart) / dayEnd.timeIntervalSince(dayStart)
                HStack(spacing: 0) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Rectangle()
                        .fill(Color.red)
                        .frame(height: 2)
                }
                .offset(x: -4, y: totalHeight * fraction - 4)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
    }
}
