//
//  MapViewModel.swift
//  VatSight
//
//  Created by Marcel Marzec on 09/05/2026.
//

import Foundation
import Combine
import MapboxMaps
import UIKit

class MapViewModel: ObservableObject {
    
    @Published var pilots: [Pilot] = []
    
    private let service = VatsimService()
    private var timer: Timer?
    
    func startAutoRefresh() {
        loadPilots()
        
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.loadPilots()
        }
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
}
