//
//  VatglassesCacheManager.swift
//  VatSight
//

import Foundation

// MARK: - Cache and Network
extension VatglassesService {

    func loadCachedDataFromDisk() {
        guard FileManager.default.fileExists(atPath: cacheFileURL.path) else { return }

        // Load synchronously — this is called once at init time on whatever thread
        // constructs VatglassesService (always the main thread via RadarViewModel).
        // Keeping it synchronous ensures cachedData is populated before the first
        // fetchSectorData() call, preventing the race where the async disk load finishes
        // after fetchCommitInfo fails and completion is never called.
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

        // Encode on the calling thread (main) to avoid passing VatglassesData across
        // isolation boundaries, then write the raw bytes on a background thread.
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let encoded = try? encoder.encode(dataToSave) else { return }

        let url = cacheFileURL
        DispatchQueue.global(qos: .utility).async {
            try? encoded.write(to: url, options: .atomic)
        }
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

    func downloadAndParseSectors(commitSHA: String, commitDate: Date? = nil, completion: @escaping (Result<VatglassesData, Error>) -> Void) {
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
                    commitDate: commitDate,
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
