//
//  VatglassesCacheManager.swift
//  VatSight
//

import Foundation

// MARK: - Cache and Network
extension VatglassesService {

    func loadCachedDataFromDisk() {
        guard FileManager.default.fileExists(atPath: cacheFileURL.path) else { return }

        do {
            let data = try Data(contentsOf: cacheFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode(VatglassesData.self, from: data)
            guard decoded.schemaVersion == VatglassesData.currentSchemaVersion else {
                try? FileManager.default.removeItem(at: cacheFileURL)
                return
            }
            cachedData = decoded
        } catch {
            try? FileManager.default.removeItem(at: cacheFileURL)
        }
    }

    func saveCachedDataToDisk() {
        guard let dataToSave = cachedData else { return }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(dataToSave)
            try data.write(to: cacheFileURL, options: .atomic)
        } catch { }
    }

    func fetchCommitInfo(completion: @escaping (Result<VatglassesComitModel, Error>) -> Void) {
        let task = URLSession.shared.dataTask(with: commitURL) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "VatglassesService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data from commit endpoint"])))
                return
            }

            do {
                let commitModel = try JSONDecoder().decode(VatglassesComitModel.self, from: data)
                completion(.success(commitModel))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }

    func downloadAndParseSectors(commitSHA: String, completion: @escaping (Result<VatglassesData, Error>) -> Void) {
        parseErrors = []   // reset diagnostics for this fetch
        let task = URLSession.shared.dataTask(with: repoURL) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                completion(.failure(error))
                return
            }

            guard let zipData = data else {
                completion(.failure(NSError(domain: "VatglassesService", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data from repo endpoint"])))
                return
            }

            do {
                var vatglassesData = try self.extractAndParseSectors(from: zipData)
                vatglassesData = VatglassesData(
                    sectors: vatglassesData.sectors,
                    airports: vatglassesData.airports,
                    allPositions: vatglassesData.allPositions,
                    lastUpdated: Date(),
                    commitSHA: commitSHA,
                    callsignLabels: vatglassesData.callsignLabels
                )

                self.cachedData = vatglassesData
                self.lastFetchDate = Date()
                self.saveCachedDataToDisk()

                completion(.success(vatglassesData))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
}
