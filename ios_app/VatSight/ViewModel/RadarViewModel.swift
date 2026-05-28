//
//  RadarViewModel.swift
//  VatSight
//

import Foundation
import Combine

final class RadarViewModel: ObservableObject {
    
    @Published var pilots: [Pilot] = []
    @Published var selectedCID: Int?
    @Published var isShowingPilotSheet = false
    
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
        service.fetchAllData { [weak self] result in
            switch result {
            case .success(let response):
                DispatchQueue.main.async {
                    self?.pilots = response.pilots
                }
            case .failure(let error):
                print("Failed to fetch data: \(error)")
            }
        }
    }
    
    var selectedPilot: Pilot? {
        pilots.first { $0.cid == selectedCID }
    }
    
    func selectPilot(cid: Int) {
        selectedCID = cid
        
        if !isShowingPilotSheet {
            isShowingPilotSheet = true
        }
    }
    
    func dismissPilotSheet() {
        isShowingPilotSheet = false
        selectedCID = nil
    }
}
