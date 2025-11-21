//
//  PhotoScannerService.swift
//  PhotoGroupingCaseStudy
//
//  Created by Ömer Uyanık on 20.11.2025.
import Foundation
import Photos


struct ScanResult {
    let groups: [PhotoGroup: [PHAsset]]
    let others: [PHAsset]
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
    
    
    func scanAndGroupAllPhotos(
        progress: @escaping (_ processed: Int, _ total: Int) -> Void,
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
                // 0.0 - 1.0 arası hash değeri
                let hashValue = asset.reliableHash()

                if let group = PhotoGroup.group(for: hashValue) {
                    groups[group]?.append(asset)
                } else {
                    others.append(asset)
                }

                let processed = index + 1

               
                if processed % 10 == 0 || processed == total {
                    DispatchQueue.main.async {
                        progress(processed, total)
                    }
                }
            }

            let result = ScanResult(groups: groups, others: others)

            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

}
