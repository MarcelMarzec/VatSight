//
//  AddToCalendarView.swift
//  VatSight
//
//  System "New Event" sheet prefilled with a VATSIM event. Since iOS 17 this runs out of
//  process and needs no calendar permission.
//

import SwiftUI
import EventKit
import EventKitUI

struct AddToCalendarView: UIViewControllerRepresentable {
    let event: VatsimEvent

    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()
        let calendarEvent = EKEvent(eventStore: store)
        calendarEvent.title = event.name
        calendarEvent.startDate = event.startTime
        calendarEvent.endDate = event.endTime
        calendarEvent.url = event.link
        if !event.allICAOs.isEmpty {
            calendarEvent.location = event.allICAOs.joined(separator: ", ")
        }

        var notes: [String] = []
        let summary = MarkdownParser.plainText(from: event.shortDescription.isEmpty ? event.description : event.shortDescription)
        if !summary.isEmpty { notes.append(summary) }
        if !event.routes.isEmpty {
            notes.append(event.routes.map { route in
                route.route.isEmpty ? "\(route.departure) → \(route.arrival)" : "\(route.departure) → \(route.arrival): \(route.route)"
            }.joined(separator: "\n"))
        }
        if let link = event.link { notes.append(link.absoluteString) }
        calendarEvent.notes = notes.joined(separator: "\n\n")

        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.event = calendarEvent
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: EKEventEditViewController, context: Context) {}

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        private let dismiss: DismissAction

        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            dismiss()
        }
    }
}
