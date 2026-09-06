//
//  VatsimService.swift
//  VatSight
//
//  Created by Marcel Marzec on 09/05/2026.
//

import Foundation

final class VatsimService {
    
    private let url = URL(string: "https://data.vatsim.net/v3/vatsim-data.json")!
    
    private var cachedResponse: VatsimResponseModel?
    
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
    
    func fetchAllData(completion: @escaping (Result<VatsimResponseModel, Error>) -> Void) {
        let decoder = self.decoder
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                return
            }
            
            do {
                let decoded = try decoder.decode(VatsimResponseModel.self, from: data)
                
                self?.cachedResponse = decoded
                
                completion(.success(decoded))
                
            } catch {
                completion(.failure(error))
            }
            
        }.resume()
    }

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
