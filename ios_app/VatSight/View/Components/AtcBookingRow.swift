//
//  AtcBookingRow.swift
//  VatSight
//
//  One ATC booking in the airport sheet, styled to match the online controller rows.
//

import SwiftUI

struct AtcBookingRow: View {
    let booking: AtcBooking
    var labelResolver: ((String) -> String?)? = nil

    @Environment(PreferencesManager.self) private var prefsManager

    private var timeDisplay: EventTimeDisplay { prefsManager.userPrefs.eventTimeDisplay }

    private var isFriend: Bool { prefsManager.userPrefs.friendCIDs.contains(booking.cid) }
    private var isMe: Bool { prefsManager.myCID > 0 && prefsManager.myCID == booking.cid }

    private var positionLabel: String {
        if let resolved = labelResolver?(booking.callsign) { return resolved }
        switch booking.facilitySuffix {
        case "DEL": return "Delivery"
        case "GND": return "Ground"
        case "TWR": return "Tower"
        case "APP": return "Approach"
        case "DEP": return "Departure"
        case "CTR": return "Centre"
        case "FSS": return "Flight Service"
        case "RMP": return "Apron"
        default: return "Controller"
        }
    }

    var body: some View {
        let range = EventTimeFormatting.range(start: booking.start, end: booking.end, display: timeDisplay)
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(positionLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(booking.callsign)
                    .font(.headline)
                HStack(spacing: 4) {
                    Text(isMe ? "You (\(String(booking.cid)))" : "CID \(String(booking.cid))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if isFriend {
                        Image(systemName: "star.fill")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                            .accessibilityLabel("Friend")
                    }
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(range.primary)
                    .font(.subheadline.monospacedDigit())
                if let secondary = range.secondary {
                    Text(secondary)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    if booking.type != .booking {
                        Label(booking.type.displayName, systemImage: booking.type.systemImage)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(booking.type.tint)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(booking.type.tint.opacity(0.15), in: Capsule())
                    }
                    BookingCountdown(start: booking.start, end: booking.end)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct BookingCountdown: View {
    let start: Date
    let end: Date

    var body: some View {
        TimelineView(.everyMinute) { context in
            if context.date >= start {
                Text("Booked now")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                Text(EventTimeFormatting.compactCountdown(to: start, now: context.date))
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}
