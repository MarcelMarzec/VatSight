//
//  EventComponents.swift
//  VatSight
//
//  Small building blocks shared by the event list, calendar, detail and airport sheet.
//

import SwiftUI

// MARK: - Colours

extension VatsimEventType {
    var tint: Color {
        switch self {
        case .event: return .purple
        case .controllerExamination: return .orange
        case .vasopsEvent: return .teal
        case .other: return .gray
        }
    }
}

extension AtcBookingType {
    var tint: Color {
        switch self {
        case .booking: return .cyan
        case .event: return .purple
        case .exam: return .orange
        case .training: return .indigo
        case .other: return .gray
        }
    }
}

// MARK: - Badges

struct EventTypeBadge: View {
    let type: VatsimEventType

    var body: some View {
        Label(type.displayName, systemImage: type.systemImage)
            .font(.caption.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .modifier(EventBadgeBackground(tint: type.tint))
    }
}

struct VatsimOrganisedBadge: View {
    var body: some View {
        Label("VATSIM", systemImage: "checkmark.seal.fill")
            .font(.caption.weight(.semibold))
            .modifier(EventBadgeBackground(tint: .blue))
            .accessibilityLabel("Organised by VATSIM")
    }
}

/// Tinted capsule normally; Liquid Glass with white text when drawn over a banner.
private struct EventBadgeBackground: ViewModifier {
    let tint: Color
    @Environment(\.eventBadgesOnGlass) private var onGlass

    func body(content: Content) -> some View {
        if onGlass {
            content
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .glassEffect(.regular.tint(tint.opacity(0.45)), in: .capsule)
        } else {
            content
                .foregroundStyle(tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(tint.opacity(0.15), in: Capsule())
        }
    }
}

/// "LIVE" / "in 3h" pill that updates once a minute.
struct EventStatusPill: View {
    let start: Date
    let end: Date
    @Environment(\.eventBadgesOnGlass) private var onGlass

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            if now >= start && now < end {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.white)
                        .frame(width: 6, height: 6)
                    Text("LIVE")
                }
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red, in: Capsule())
                .accessibilityLabel("Live now")
            } else if now < start {
                let soon = start.timeIntervalSince(now) < 3600
                let label = Text(EventTimeFormatting.compactCountdown(to: start, now: now).capitalizedFirst)
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                if onGlass {
                    label
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .glassEffect(.regular.tint((soon ? Color.orange : Color.black).opacity(0.35)), in: .capsule)
                        .accessibilityLabel(EventTimeFormatting.relativeStatus(start: start, end: end, now: now))
                } else {
                    label
                        .foregroundStyle(soon ? Color.orange : Color.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((soon ? Color.orange : Color.secondary).opacity(0.15), in: Capsule())
                        .accessibilityLabel(EventTimeFormatting.relativeStatus(start: start, end: end, now: now))
                }
            }
        }
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

// MARK: - Time

/// Date line and time range for an event, following the UTC / Local / Both setting.
struct EventTimeSummary: View {
    let start: Date
    let end: Date
    let display: EventTimeDisplay
    var showsDuration = true

    var body: some View {
        let range = EventTimeFormatting.range(start: start, end: end, display: display)
        VStack(alignment: .leading, spacing: 3) {
            Label {
                Text(EventTimeFormatting.dateLine(start: start, end: end, display: display))
            } icon: {
                Image(systemName: "calendar")
            }
            Label {
                HStack(spacing: 6) {
                    Text(range.primary)
                        .monospacedDigit()
                    if showsDuration {
                        Text("· \(EventTimeFormatting.duration(end.timeIntervalSince(start)))")
                            .foregroundStyle(.secondary)
                    }
                }
            } icon: {
                Image(systemName: "clock")
            }
            if let secondary = range.secondary {
                Label {
                    Text(secondary)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "location")
                        .hidden()
                }
            }
        }
        .font(.subheadline)
        .labelStyle(EventSummaryLabelStyle())
    }
}

private struct EventSummaryLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            ScaledIcon { configuration.icon }
            configuration.title
        }
    }
}

/// Fixed-width icon column that grows with Dynamic Type so the titles stay aligned.
private struct ScaledIcon<Icon: View>: View {
    @ScaledMetric(relativeTo: .subheadline) private var width: CGFloat = 18
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        icon()
            .foregroundStyle(.secondary)
            .frame(width: width)
    }
}

// MARK: - Airports

struct AirportChip: View {
    let icao: String

    var body: some View {
        Text(icao)
            .font(.caption.monospaced().weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

/// Wrapping row of airport chips; routes are shown as "EGLL → KJFK".
struct EventAirportsRow: View {
    let event: VatsimEvent
    var limit = 8

    var body: some View {
        let routeAirports = Set(event.routes.flatMap { [$0.departure, $0.arrival] })
        let standalone = event.airports.map(\.icao).filter { !routeAirports.contains($0) }
        let routes = Array(event.routes.prefix(limit))
        let chips = Array(standalone.prefix(max(0, limit - routes.count)))
        let hidden = max(0, event.allICAOs.count - chips.count - Set(routes.flatMap { [$0.departure, $0.arrival] }).count)

        FlowLayout(spacing: 6) {
            ForEach(routes.indices, id: \.self) { index in
                let route = routes[index]
                HStack(spacing: 4) {
                    AirportChip(icao: route.departure)
                    Image(systemName: "arrow.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    AirportChip(icao: route.arrival)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(route.departure) to \(route.arrival)")
            }
            ForEach(chips, id: \.self) { icao in
                AirportChip(icao: icao)
            }
            if hidden > 0 {
                Text("+\(hidden)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 3)
            }
        }
    }
}

/// Left-to-right wrapping layout.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat? = nil

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(width: bounds.width, subviews: subviews)
        for row in rows {
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: bounds.minX + item.x, y: bounds.minY + row.y + (row.height - item.size.height) / 2),
                    proposal: ProposedViewSize(item.size)
                )
            }
        }
    }

    private struct Row {
        var items: [(index: Int, x: CGFloat, size: CGSize)] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        let verticalGap = lineSpacing ?? spacing
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let proposedX = current.items.isEmpty ? 0 : current.width + spacing
            if !current.items.isEmpty && proposedX + size.width > maxWidth {
                let nextY = current.y + current.height + verticalGap
                rows.append(current)
                current = Row(y: nextY)
            }
            let x = current.items.isEmpty ? 0 : current.width + spacing
            current.items.append((index, x, size))
            current.width = x + size.width
            current.height = max(current.height, size.height)
        }
        if !current.items.isEmpty { rows.append(current) }
        return rows
    }
}

// MARK: - Accessibility

extension VatsimEvent {
    /// Spoken summary used by cards and calendar blocks.
    func accessibilitySummary(display: EventTimeDisplay, now: Date = Date()) -> String {
        let range = EventTimeFormatting.range(start: startTime, end: endTime, display: display)
        var parts = [
            name,
            type.displayName,
            EventTimeFormatting.dateLine(start: startTime, end: endTime, display: display),
            range.primary.replacingOccurrences(of: "z", with: " UTC")
        ]
        if let secondary = range.secondary { parts.append(secondary) }
        parts.append(EventTimeFormatting.relativeStatus(start: startTime, end: endTime, now: now))
        if !allICAOs.isEmpty { parts.append("Airports: " + allICAOs.joined(separator: ", ")) }
        return parts.joined(separator: ", ")
    }
}

// MARK: - VatSight Styling

/// Card surface used across the Events screens, matching the detail sheets' metric containers.
struct VatSightCard: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension View {
    func vatSightCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(VatSightCard(cornerRadius: cornerRadius))
    }
}

/// Capsule chip in the style of the airport traffic tab picker.
struct VatSightChip<Label: View>: View {
    let isSelected: Bool
    @ViewBuilder let label: () -> Label

    var body: some View {
        label()
            .font(.subheadline.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .background(isSelected ? Color.primary.opacity(0.18) : Color.primary.opacity(0.06), in: Capsule())
            .overlay {
                if isSelected {
                    Capsule().strokeBorder(Color.primary.opacity(0.25), lineWidth: 1)
                }
            }
            .contentShape(Capsule())
    }
}

/// Labelled values separated by dividers, like the pilot sheet's metric container.
struct MetricStrip: View {
    struct Item: Identifiable {
        let title: String
        let value: String
        var secondary: String? = nil
        var id: String { title }
    }

    let items: [Item]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Divider()
                        .padding(.vertical, 8)
                }
                VStack(spacing: 3) {
                    Text(item.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.value)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    if let secondary = item.secondary {
                        Text(secondary)
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .accessibilityElement(children: .combine)
            }
        }
        .background(.background.tertiary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// Date / Start / End / Length for an event, per the time display setting.
    static func eventTimes(start: Date, end: Date, display: EventTimeDisplay) -> MetricStrip {
        let calendar = EventTimeFormatting.calendar(for: display)
        let lastInstant = end > start ? end.addingTimeInterval(-1) : end
        let sameDay = calendar.isDate(start, inSameDayAs: lastInstant)
        let startParts = EventTimeFormatting.timeParts(start, display: display)
        let endParts = EventTimeFormatting.timeParts(end, display: display, withWeekday: !sameDay)
        return MetricStrip(items: [
            Item(title: "Date", value: EventTimeFormatting.shortDate(start, display: display)),
            Item(title: "Start", value: startParts.primary, secondary: startParts.secondary),
            Item(title: "End", value: endParts.primary, secondary: endParts.secondary),
            Item(title: "Length", value: EventTimeFormatting.duration(end.timeIntervalSince(start)))
        ])
    }
}

/// Section heading used in the Events screens (matches the pilot sheet's section titles).
struct EventSectionTitle: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
