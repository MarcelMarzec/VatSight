//
//  RadarViewModel.swift
//  VatSight
//

import Foundation
import Combine

final class RadarViewModel: ObservableObject {

    @Published var pilots: [Pilot] = []
    @Published var selectedPilot: Pilot?

    private let service = VatsimService()
    private var timer: Timer?

    func startAutoRefresh() {
        guard timer == nil else { return }

        loadPilots()

        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.loadPilots()
        }
    }

    func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
    }

    func loadPilots() {
        service.fetchPilots { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let pilots):
                    self?.pilots = pilots
                case .failure(let error):
                    print("Error fetching pilots:", error)
                }
            }
        }
    }

    func selectPilot(cid: Int) {
        selectedPilot = pilots.first { $0.cid == cid }
    }
}
