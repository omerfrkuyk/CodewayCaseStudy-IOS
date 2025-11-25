//
//  PhotoScannerService.swift
//  CodewayCaseStudy-iOS
//
//  Created by Ömer Uyanık on 20.11.2025.
//

import Foundation
import Photos

struct ScanResult {
    let groups: [PhotoGroup: [PHAsset]]
    let others: [PHAsset]
}


private struct PersistedScanResult: Codable {
    let groups: [String: [String]]
    let others: [String]
}

/// Devam edebilmek için tarama esnasındaki progress takibi
private struct PersistedScanProgress: Codable {
    let processedCount: Int
    let totalCount: Int
    let groups: [String: [String]]   // groupKey -> [assetID]
    let others: [String]             // [assetID]
}

class PhotoScannerService {

    

    func requestPhotoAccess(completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized || status == .limited)
            }
        }
    }

    func fetchAllPhotoAssets() -> [PHAsset] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: true)
        ]

        let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)

        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }

        return assets
    }

    /// Bütün fotoları tarar ve gruplar.
    ///
    /// - resumeIfPossible: true ise, daha önce yarım kalmış bir tarama varsa kaldığı yerden devam etmeye çalışır.
    /// - progress: adet bazlı ilerleme (progress bar için)
    /// - partialUpdate: o ana kadarki grup + others  (listeyi canlı güncellemek için)
    /// - completion:  sonuç
    func scanAndGroupAllPhotos(
        resumeIfPossible: Bool,
        progress: @escaping (_ processed: Int, _ total: Int) -> Void,
        partialUpdate: @escaping (_ groups: [PhotoGroup: [PHAsset]], _ others: [PHAsset]) -> Void,
        completion: @escaping (ScanResult) -> Void
    ) {
        let assets = fetchAllPhotoAssets()
        let total = assets.count

        var groups: [PhotoGroup: [PHAsset]] = [:]
        for group in PhotoGroup.allCases {
            groups[group] = []
        }
        var others: [PHAsset] = []

        var startIndex = 0

        // Progress varsa devam ettirme
        if resumeIfPossible,
           let stored = loadPersistedScanProgress(),
           stored.totalCount == total {

            groups = stored.groups
            others = stored.others
            startIndex = stored.processedCount

            let processed = stored.processedCount
            if processed > 0 {
                DispatchQueue.main.async {
                    progress(processed, total)
                    partialUpdate(groups, others)
                }
            }
        } else {
            // Yeni tarama başlarsa eski progressi silme
            clearScanProgress()
        }

        // foto yoksa bitir
        if total == 0 {
            let result = ScanResult(groups: groups, others: others)
            DispatchQueue.main.async {
                self.clearScanProgress()
                completion(result)
            }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Eğer startIndex zaten total'e eşitse,demek ki daha önce bitmiş
            if startIndex >= total {
                let result = ScanResult(groups: groups, others: others)
                DispatchQueue.main.async {
                    self.clearScanProgress()
                    completion(result)
                }
                return
            }

            for index in startIndex..<assets.count {
                let asset = assets[index]

                
                let hashValue = asset.reliableHash()

                if let group = PhotoGroup.group(for: hashValue) {
                    groups[group]?.append(asset)
                } else {
                    others.append(asset)
                }

                let processed = index + 1

                // Her 10 fotoda bir progressi UI'a gönderme
                if processed % 10 == 0 || processed == total {
                    let snapshotGroups = groups
                    let snapshotOthers = others

                    self.saveScanProgress(
                        processedCount: processed,
                        totalCount: total,
                        groups: groups,
                        others: others
                    )

                    DispatchQueue.main.async {
                        progress(processed, total)
                        partialUpdate(snapshotGroups, snapshotOthers)
                    }
                }
            }

            let result = ScanResult(groups: groups, others: others)

            DispatchQueue.main.async {
                
                self.clearScanProgress()
                completion(result)
            }
        }
    }

    // MARK: - Persisting Scan Results (final state)

    func saveScanResult(_ result: ScanResult) {
        var dict: [String: [String]] = [:]

        for (group, assets) in result.groups {
            let ids = assets.map { $0.localIdentifier }
            dict[group.rawValue] = ids
        }

        let othersIds = result.others.map { $0.localIdentifier }

        let persisted = PersistedScanResult(groups: dict, others: othersIds)

        do {
            let data = try JSONEncoder().encode(persisted)
            try data.write(to: scanResultFileURL(), options: [.atomic])
        } catch {
            print("Persist DEBUG: failed to save scan result → \(error)")
        }
    }

    func loadPersistedScanResult() -> ScanResult? {
        let url = scanResultFileURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let persisted = try JSONDecoder().decode(PersistedScanResult.self, from: data)

            var groups: [PhotoGroup: [PHAsset]] = [:]
            let fetchOptions = PHFetchOptions()

            for (key, idList) in persisted.groups {
                guard let group = PhotoGroup(rawValue: key) else { continue }

                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: idList, options: fetchOptions)
                var assets: [PHAsset] = []
                assets.reserveCapacity(fetchResult.count)

                fetchResult.enumerateObjects { asset, _, _ in
                    assets.append(asset)
                }

                groups[group] = assets
            }

            let othersFetch = PHAsset.fetchAssets(withLocalIdentifiers: persisted.others, options: fetchOptions)
            var othersAssets: [PHAsset] = []
            othersAssets.reserveCapacity(othersFetch.count)
            othersFetch.enumerateObjects { asset, _, _ in
                othersAssets.append(asset)
            }

            return ScanResult(groups: groups, others: othersAssets)

        } catch {
            print("Persist DEBUG: failed to load scan result → \(error)")
            return nil
        }
    }

    // MARK: - Persisting Scan Progress (kaldığı yerden devam)

    private func saveScanProgress(
        processedCount: Int,
        totalCount: Int,
        groups: [PhotoGroup: [PHAsset]],
        others: [PHAsset]
    ) {
        var dict: [String: [String]] = [:]

        for (group, assets) in groups {
            let ids = assets.map { $0.localIdentifier }
            dict[group.rawValue] = ids
        }

        let othersIds = others.map { $0.localIdentifier }

        let persisted = PersistedScanProgress(
            processedCount: processedCount,
            totalCount: totalCount,
            groups: dict,
            others: othersIds
        )

        do {
            let data = try JSONEncoder().encode(persisted)
            try data.write(to: scanProgressFileURL(), options: [.atomic])
        } catch {
            print("Persist DEBUG: failed to save scan progress → \(error)")
        }
    }

    private func loadPersistedScanProgress() -> (
        processedCount: Int,
        totalCount: Int,
        groups: [PhotoGroup: [PHAsset]],
        others: [PHAsset]
    )? {
        let url = scanProgressFileURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let persisted = try JSONDecoder().decode(PersistedScanProgress.self, from: data)

            var groups: [PhotoGroup: [PHAsset]] = [:]
            let fetchOptions = PHFetchOptions()

            for (key, idList) in persisted.groups {
                guard let group = PhotoGroup(rawValue: key) else { continue }

                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: idList, options: fetchOptions)
                var assets: [PHAsset] = []
                assets.reserveCapacity(fetchResult.count)

                fetchResult.enumerateObjects { asset, _, _ in
                    assets.append(asset)
                }

                groups[group] = assets
            }

            let othersFetch = PHAsset.fetchAssets(withLocalIdentifiers: persisted.others, options: fetchOptions)
            var othersAssets: [PHAsset] = []
            othersAssets.reserveCapacity(othersFetch.count)
            othersFetch.enumerateObjects { asset, _, _ in
                othersAssets.append(asset)
            }

            return (
                processedCount: persisted.processedCount,
                totalCount: persisted.totalCount,
                groups: groups,
                others: othersAssets
            )

        } catch {
            print("Persist DEBUG: failed to load scan progress → \(error)")
            return nil
        }
    }

    private func clearScanProgress() {
        let url = scanProgressFileURL()
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    

    private func scanResultFileURL() -> URL {
        let fm = FileManager.default
        let dir = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("scanResult.json")
    }

    private func scanProgressFileURL() -> URL {
        let fm = FileManager.default
        let dir = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("scanProgress.json")
    }

    /// Yarım kalan tarama kontrol
    func hasPendingScanProgress() -> Bool {
        let url = scanProgressFileURL()
        return FileManager.default.fileExists(atPath: url.path)
    }
}
