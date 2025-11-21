//
//  PhotoGroupsViewModel.swift
//  PhotoGroupingCaseStudy
//
//  Created by Ömer Uyanık on 20.11.2025.
//

import Foundation
import Photos
import Combine

@MainActor
class PhotoGroupsViewModel: ObservableObject {

    @Published var groups: [(PhotoGroup, Int)] = []
    @Published var othersCount: Int = 0
    @Published var isLoaded = false

    private let scanner = PhotoScannerService()

    func startScanning() {
        scanner.scanAndGroupAllPhotos(
            progress: { _, _ in },
            completion: { [weak self] result in
                guard let self = self else { return }

                var temp: [(PhotoGroup, Int)] = []

                for group in PhotoGroup.allCases {
                    let count = result.groups[group]?.count ?? 0
                    if count > 0 {
                        temp.append((group, count))
                    }
                }

                self.groups = temp
                self.othersCount = result.others.count
                self.isLoaded = true
            }
        )
    }
}
