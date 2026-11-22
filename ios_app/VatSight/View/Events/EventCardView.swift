//
//  EventCardView.swift
//  VatSight
//

import SwiftUI

/// Summary card for the events list, styled like VatSight's detail sheets: banner with glass
/// badges, a bold title, a metric strip for the times and monospaced airport chips.
/// Tap opens the detail view; links inside the short description stay tappable on their own.
struct EventCardView: View {
    let event: VatsimEvent
    let timeDisplay: EventTimeDisplay
    /// Organiser line, e.g. "Europe · Germany" (resolved names from the Core API).
    var organiserSummary: String = ""
    var onOpen: () -> Void

    private static let bannerAspectRatio: CGFloat = 16.0 / 9.0
    private let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let banner = event.banner {
                Color.clear
                    .aspectRatio(Self.bannerAspectRatio, contentMode: .fit)
                    .overlay { RemoteImage(url: banner) }
                    .overlay(alignment: .top) {
                        badgeRow
                            .padding(10)
                    }
                    .clipped()
            }

            VStack(alignment: .leading, spacing: 12) {
                if event.banner == nil {
                    badgeRow
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.name)
                        .font(.title3.bold())
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if !organiserSummary.isEmpty {
                        Text(organiserSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                MetricStrip.eventTimes(start: event.startTime, end: event.endTime, display: timeDisplay)

                if !event.allICAOs.isEmpty {
                    EventAirportsRow(event: event)
                }

                if !event.shortDescription.isEmpty {
                    MarkdownPreviewText(event.shortDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vatSightCard()
        .clipShape(shape)
        .contentShape(shape)
        .onTapGesture(perform: onOpen)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(event.accessibilitySummary(display: timeDisplay))
        .accessibilityHint("Shows event details")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, onOpen)
    }

    private var badgeRow: some View {
        HStack(spacing: 6) {
            EventTypeBadge(type: event.type)
            if event.isOrganisedByVatsim {
                VatsimOrganisedBadge()
            }
            Spacer(minLength: 8)
            EventStatusPill(start: event.startTime, end: event.endTime)
        }
        .environment(\.eventBadgesOnGlass, event.banner != nil)
    }
}

// MARK: - Badges on banners

private struct EventBadgesOnGlassKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Badges drawn over a banner get a glass backing so they stay legible on any image.
    var eventBadgesOnGlass: Bool {
        get { self[EventBadgesOnGlassKey.self] }
        set { self[EventBadgesOnGlassKey.self] = newValue }
    }
}
