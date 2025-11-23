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

/// Diskte saklayacağımız sade model (PHAsset yerine sadece localIdentifier string'leri)
private struct PersistedScanResult: Codable {
    let groups: [String: [String]]   // "a", "b", ... -> [assetID]
    let others: [String]             // assetID listesi
}

class PhotoScannerService {

    // MARK: - Public API

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
    /// progress       → adet bazlı ilerleme (progress bar için)
    /// partialUpdate  → o ana kadarki grup + others snapshot'ı (listeyi canlı güncellemek için)
    /// completion     → final sonuç
    func scanAndGroupAllPhotos(
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

        DispatchQueue.global(qos: .userInitiated).async {
            for (index, asset) in assets.enumerated() {
                // 0.0 - 1.0 arası hash
                let hashValue = asset.reliableHash()

                if let group = PhotoGroup.group(for: hashValue) {
                    groups[group]?.append(asset)
                } else {
                    others.append(asset)
                }

                let processed = index + 1

                // Her 10 fotoda bir (ve son fotoda) UI'ya progress + snapshot gönder
                if processed % 10 == 0 || processed == total {
                    let snapshotGroups = groups
                    let snapshotOthers = others

                    DispatchQueue.main.async {
                        progress(processed, total)
                        partialUpdate(snapshotGroups, snapshotOthers)
                    }
                }
            }

            let result = ScanResult(groups: groups, others: others)

            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    // MARK: - Persisting Scan Results (JSON)

    /// Son tarama sonucunu diske JSON olarak kaydeder.
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

    /// Diskten en son kaydedilmiş sonucu yükler ve tekrar PHAsset'lere çevirir.
    /// YOKSA → nil döner.
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

    // MARK: - Helpers

    private func scanResultFileURL() -> URL {
        let fm = FileManager.default
        let dir = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("scanResult.json")
    }
}
