//
//  VatsimService.swift
//  VatSight
//
//  Created by Marcel Marzec on 09/05/2026.
//

import Foundation

final class VatsimService {
    
    private let url = URL(string: "https://data.vatsim.net/v3/vatsim-data.json")!
    
    // MARK: - Cached state (important for performance)
    private var cachedResponse: VatsimResponse?
    
    // MARK: - Date decoding (reuse once)
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        
        let formatterWithFractional = ISO8601DateFormatter()
        formatterWithFractional.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        
        let formatterWithoutFractional = ISO8601DateFormatter()
        formatterWithoutFractional.formatOptions = [.withInternetDateTime]
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            
            if let date = formatterWithFractional.date(from: string) {
                return date
            }
            
            if let date = formatterWithoutFractional.date(from: string) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date format: \(string)"
            )
        }
        
        return decoder
    }()
    
    // MARK: - MAIN FETCH (replaces all partial fetches)
    func fetchPilots(completion: @escaping (Result<[Pilot], Error>) -> Void) {
        fetchAllData { result in
            switch result {
            case .success(let response):
                completion(.success(response.pilots))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - CORE FETCH (NEW)
    func fetchAllData(completion: @escaping (Result<VatsimResponse, Error>) -> Void) {
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                return
            }
            
            do {
                guard let self = self else { return }
                
                let decoded = try self.decoder.decode(VatsimResponse.self, from: data)
                
                // cache it for Mapbox / UI reuse
                self.cachedResponse = decoded
                
                completion(.success(decoded))
                
            } catch {
                completion(.failure(error))
            }
            
        }.resume()
    }
    
    // MARK: - FAST ACCESSORS (NO network call)
    
    func getCachedPilots() -> [Pilot] {
        cachedResponse?.pilots ?? []
    }
    
    func getCachedControllers() -> [Controllers] {
        cachedResponse?.controllers ?? []
    }
    
    func getCachedATIS() -> [ATIS] {
        cachedResponse?.atis ?? []
    }
    
    func getCachedServers() -> [Servers] {
        cachedResponse?.servers ?? []
    }
    
    func getCachedPrefiles() -> [Prefiles] {
        cachedResponse?.prefiles ?? []
    }
    
    func getCachedGeneral() -> General? {
        cachedResponse?.general
    }
}
