//
//  VatsimService.swift
//  VatSight
//
//  Created by Marcel Marzec on 09/05/2026.
//

import Foundation

class VatsimService {
    
    private let url = URL(string: "https://data.vatsim.net/v3/vatsim-data.json")!
    
    func fetchPilots(completion: @escaping (Result<[Pilot], Error>) -> Void) {
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else { return }
            
            do {
                let decoded = try JSONDecoder().decode(VatsimResponse.self, from: data)
                completion(.success(decoded.pilots))
            } catch {
                completion(.failure(error))
            }
            
        }.resume()
    }
}
