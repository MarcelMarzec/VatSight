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
                let decoder = JSONDecoder()

                let formatterWithFractional = ISO8601DateFormatter()
                formatterWithFractional.formatOptions = [
                    .withInternetDateTime,
                    .withFractionalSeconds
                ]

                let formatterWithoutFractional = ISO8601DateFormatter()
                formatterWithoutFractional.formatOptions = [
                    .withInternetDateTime
                ]

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

                let decoded = try decoder.decode(VatsimResponse.self, from: data)
                completion(.success(decoded.pilots))

            } catch {
                completion(.failure(error))
            }
            
        }.resume()
    }
}
