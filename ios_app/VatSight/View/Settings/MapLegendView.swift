//
//  MapLegendView.swift
//  VatSight
//
//  What every symbol and colour on the map means. Samples are drawn with the same colours
//  as the map layers (see RadarStyleManager, AirportStyleManager, SectorStyleManager,
//  FlightRouteStyleManager and BookedSectorStyleManager).
//

import SwiftUI

struct MapLegendView: View {
    var body: some View {
        List {
            Section {
                MapLegendRow(title: "Aircraft", detail: "Points the way it's heading. On the ground, shown from zoom 10") {
                    PlaneSample(color: .primary)
                }
                MapLegendRow(title: "Selected Aircraft", detail: "The aircraft whose details are open") {
                    PlaneSample(color: MapLegendColors.selected)
                }
                MapLegendRow(title: "Friend", detail: "Someone on your Friends list") {
                    PlaneSample(color: MapLegendColors.friend)
                }
                MapLegendRow(title: "You", detail: "Your own CID, set in Settings") {
                    PlaneSample(color: MapLegendColors.me)
                }
                MapLegendRow(title: "Not Connected", detail: "Faded while an airport is selected: not flying to or from it") {
                    PlaneSample(color: .primary)
                        .opacity(0.2)
                }
            } header: {
                Label("Aircraft", systemImage: "airplane")
            }

            Section {
                MapLegendRow(title: "Towards Departure", detail: "From the selected aircraft back to where it departed") {
                    LineSample(color: MapLegendColors.selected)
                }
                MapLegendRow(title: "Towards Arrival", detail: "From the selected aircraft to its destination") {
                    LineSample(color: MapLegendColors.arrival)
                }
                MapLegendRow(title: "Towards Alternate", detail: "The selected aircraft's alternate airport") {
                    LineSample(color: .gray, dashed: true)
                }
                MapLegendRow(title: "Airport Traffic", detail: "With an airport selected: red to its departures, green to its arrivals") {
                    HStack(spacing: 3) {
                        LineSample(color: MapLegendColors.selected, width: 11)
                        LineSample(color: MapLegendColors.arrival, width: 11)
                    }
                }
            } header: {
                Label("Routes", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
            }

            Section {
                MapLegendRow(title: "Active Airport", detail: "ATC online, or flights departing or arriving") {
                    AirportDotSample(ring: .primary, fill: .primary)
                }
                MapLegendRow(title: "Inactive Airport", detail: "Shown with All Airports turned on in the layer menu") {
                    AirportDotSample(ring: .primary, fill: .clear, size: 7)
                }
                MapLegendRow(title: "Selected Airport", detail: "The airport whose details are open") {
                    AirportDotSample(ring: MapLegendColors.selected, fill: MapLegendColors.selected)
                }
                MapLegendRow(title: "Friend Controlling", detail: "A friend is controlling here") {
                    AirportDotSample(ring: MapLegendColors.friend, fill: MapLegendColors.friend)
                }
                MapLegendRow(title: AirportHighlight.activeEvent.displayName, detail: "Larger dot, purple ring and glow, label shown from further out") {
                    AirportDotSample(ring: MapLegendColors.event, fill: .primary, glow: true, outerRing: true)
                }
                MapLegendRow(title: AirportHighlight.upcomingEvent.displayName, detail: "Purple ring, within your upcoming events window") {
                    AirportDotSample(ring: MapLegendColors.event, fill: .clear)
                }
                MapLegendRow(title: AirportHighlight.upcomingBooking.displayName, detail: "Cyan ring: ATC booked, not online yet") {
                    AirportDotSample(ring: MapLegendColors.booking, fill: .clear)
                }
                MapLegendRow(title: "Not Connected", detail: "Faded while an airport is selected: no traffic to or from it") {
                    AirportDotSample(ring: .primary, fill: .primary)
                        .opacity(0.25)
                }
            } header: {
                Label("Airports", systemImage: "mappin.circle")
            }

            Section {
                MapLegendRow(title: "Tower · Ground · Delivery · ATIS", detail: "Positions online at the airport") {
                    HStack(spacing: 2) {
                        BadgeSample(text: "T", color: MapLegendColors.tower)
                        BadgeSample(text: "G", color: MapLegendColors.ground)
                        BadgeSample(text: "D", color: MapLegendColors.delivery)
                        BadgeSample(text: "A", color: MapLegendColors.atis)
                    }
                }
                MapLegendRow(title: "Event", detail: "★ now, calendar when upcoming") {
                    HStack(spacing: 2) {
                        BadgeSample(symbol: "star.fill", color: MapLegendColors.eventBadge)
                        BadgeSample(symbol: "calendar", color: MapLegendColors.upcomingBadge)
                    }
                }
                MapLegendRow(title: "Booked ATC", detail: "A controller has booked a position here") {
                    BadgeSample(symbol: "headphones", color: MapLegendColors.bookingBadge)
                }
            } header: {
                Label("Airport Badges", systemImage: "tag")
            } footer: {
                Text("Badges appear next to the airport's ICAO code from zoom 5.")
            }

            Section {
                MapLegendRow(title: "Active Sector", detail: "Staffed airspace, in the controller's VATGlasses colour") {
                    SectorSample(color: .blue)
                }
                MapLegendRow(title: "Inactive Sector", detail: "Shown with Inactive Sectors turned on in the layer menu") {
                    SectorSample(color: .gray, fillOpacity: 0.05)
                }
                MapLegendRow(title: "Basic Data Only", detail: "No detailed VATGlasses airspace: an outline of the whole area") {
                    SectorSample(color: MapLegendColors.basic, dashed: true, fillOpacity: 0.1)
                }
                MapLegendRow(title: "Approach Circle", detail: "Approach online without VATGlasses airspace: a 15 nm circle") {
                    Circle()
                        .strokeBorder(Color.blue, lineWidth: 1.5)
                        .background(Circle().fill(Color.blue.opacity(0.1)))
                        .frame(width: 18, height: 18)
                }
                MapLegendRow(title: "Booked Sector", detail: "Dashed cyan: airspace a booked controller will cover.") {
                    SectorSample(color: MapLegendColors.booking, dashed: true, fillOpacity: 0.06)
                }
                MapLegendRow(title: "Selected Sector", detail: "The sector whose details are open") {
                    SectorSample(color: MapLegendColors.selected)
                }
            } header: {
                Label("Sectors", systemImage: "square.dashed")
            }

            Section {
                MapLegendRow(title: "Controller", detail: "Callsign, then frequency from zoom 7") {
                    PillSample(color: MapLegendColors.pillDefault)
                }
                MapLegendRow(title: "Selected", detail: "") {
                    PillSample(color: MapLegendColors.selected)
                }
                MapLegendRow(title: "Friend", detail: "") {
                    PillSample(color: MapLegendColors.friend)
                }
                MapLegendRow(title: "You", detail: "") {
                    PillSample(color: MapLegendColors.me)
                }
            } header: {
                Label("Sector Labels", systemImage: "text.bubble")
            } footer: {
                Text("Below zoom 5 each label is shown as a small square in the same colour.")
            }
        }
        .navigationTitle("Map Legend")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Colours

/// The map layers' colours (dark theme values; they read well in both themes here).
enum MapLegendColors {
    static let selected = Color(red: 1.00, green: 0.23, blue: 0.19)
    static let friend = Color(red: 0.19, green: 0.90, blue: 0.43)
    static let me = Color(red: 1.00, green: 0.78, blue: 0.00)
    static let arrival = Color(red: 0.20, green: 0.78, blue: 0.35)
    static let event = Color(red: 0.75, green: 0.35, blue: 0.95)
    static let booking = Color(red: 0.39, green: 0.82, blue: 1.00)
    static let basic = Color(red: 1.00, green: 0.71, blue: 0.00)
    static let tower = Color(red: 0.20, green: 0.60, blue: 1.00)
    static let ground = Color(red: 0.20, green: 0.78, blue: 0.35)
    static let delivery = Color(red: 1.00, green: 0.58, blue: 0.00)
    static let atis = Color(red: 0.69, green: 0.32, blue: 0.87)
    static let eventBadge = Color(red: 0.69, green: 0.32, blue: 0.87)
    static let upcomingBadge = Color(red: 0.55, green: 0.30, blue: 0.72)
    static let bookingBadge = Color(red: 0.00, green: 0.55, blue: 0.75)
    static let pillDefault = Color(red: 0.05, green: 0.15, blue: 0.40)
}

// MARK: - Rows & Samples

struct MapLegendRow<Symbol: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let symbol: () -> Symbol
    @ScaledMetric private var symbolWidth: CGFloat = 40

    var body: some View {
        HStack(spacing: 12) {
            symbol()
                .frame(width: symbolWidth)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct AirportDotSample: View {
    let ring: Color
    let fill: Color
    var glow = false
    var outerRing = false
    var size: CGFloat = 10

    var body: some View {
        ZStack {
            if glow {
                Circle()
                    .fill(ring.opacity(0.35))
                    .frame(width: 26, height: 26)
                    .blur(radius: 2.5)
            }
            if outerRing {
                Circle()
                    .strokeBorder(ring.opacity(0.9), lineWidth: 1.5)
                    .frame(width: 19, height: 19)
            }
            Circle()
                .fill(fill)
                .frame(width: size, height: size)
            Circle()
                .strokeBorder(ring, lineWidth: 2)
                .frame(width: size, height: size)
        }
        .accessibilityHidden(true)
    }
}

private struct PlaneSample: View {
    let color: Color

    var body: some View {
        Image(systemName: "airplane")
            .font(.title3)
            .rotationEffect(.degrees(-45))
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }
}

private struct LineSample: View {
    let color: Color
    var dashed = false
    var width: CGFloat = 26

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 6))
            path.addLine(to: CGPoint(x: width, y: 6))
        }
        .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: dashed ? [4, 4] : []))
        .frame(width: width, height: 12)
        .accessibilityHidden(true)
    }
}

private struct BadgeSample: View {
    var text: String? = nil
    var symbol: String? = nil
    let color: Color

    var body: some View {
        Group {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 7, weight: .bold))
            } else if let text {
                Text(text)
                    .font(.system(size: 9, weight: .bold))
            }
        }
        .foregroundStyle(.white)
        .frame(minWidth: 9)
        .padding(.horizontal, 2.5)
        .padding(.vertical, 1.5)
        .background(color, in: RoundedRectangle(cornerRadius: 2.5))
        .overlay(RoundedRectangle(cornerRadius: 2.5).stroke(Color.black, lineWidth: 0.75))
        .accessibilityHidden(true)
    }
}

private struct SectorSample: View {
    let color: Color
    var dashed = false
    var fillOpacity: Double = 0.12

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(color.opacity(fillOpacity))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(color, style: StrokeStyle(lineWidth: 1.5, dash: dashed ? [4, 3] : []))
            )
            .frame(width: 26, height: 18)
            .accessibilityHidden(true)
    }
}

private struct PillSample: View {
    let color: Color

    var body: some View {
        Text("CTR")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color, in: RoundedRectangle(cornerRadius: 4))
            .accessibilityHidden(true)
    }
}

#Preview {
    NavigationStack {
        MapLegendView()
    }
}
