//
//  ContentView.swift
//  PhotoGroupingCaseStudy
//
//  Created by Ömer Uyanık on 20.11.2025.
import SwiftUI
import Photos

struct ContentView: View {
    @State private var hasPermission = false
    @State private var permissionChecked = false

    @State private var isScanning = false
    @State private var processedCount: Int = 0
    @State private var totalCount: Int = 0

    @State private var groupCounts: [(String, Int)] = []

    private let scanner = PhotoScannerService()

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                if !permissionChecked {
                    ProgressView()
                    Text("Requesting photo access...")
                        .font(.headline)
                } else if !hasPermission {
                    Text("Permission denied")
                        .font(.title2)
                    Text("Uygulamayı kullanabilmek için izin gerekli.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else {
                   
                    if isScanning {
                        if totalCount > 0 {
                            Text("Scanning photos: \(processedCount) / \(totalCount)")
                                .font(.headline)

                            let percent = Int(
                                (Double(processedCount) / Double(totalCount)) * 100
                            )

                            Text("%\(percent)")
                                .font(.subheadline)

                            ProgressView(value: Double(processedCount),
                                         total: Double(totalCount))
                                .padding(.horizontal)
                        } else {
                            Text("Preparing scan...")
                        }
                    } else {
                        if groupCounts.isEmpty {
                            Text("No photos found or scan result is empty.")
                                .font(.subheadline)
                        } else {
                            List(groupCounts, id: \.0) { item in
                                HStack {
                                    Text(item.0)
                                    Spacer()
                                    Text("\(item.1)")
                                }
                            }
                        }

                        Button {
                            startScan()
                        } label: {
                            Text("Scan Again")
                                .padding()
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.horizontal)
                    }
                }
            }
            .padding()
            .navigationTitle("Photo Groups")
        }
        .onAppear {
            requestPermissionIfNeeded()
        }
    }

    // MARK: - Logic

    private func requestPermissionIfNeeded() {
        scanner.requestPhotoAccess { granted in
            self.hasPermission = granted
            self.permissionChecked = true

            if granted {
                startScan()
            }
        }
    }

    private func startScan() {
        isScanning = true
        processedCount = 0
        totalCount = 0
        groupCounts = []

        scanner.scanAndGroupAllPhotos(
            progress: { processed, total in
                self.processedCount = processed
                self.totalCount = total
            },
            completion: { result in
                self.isScanning = false

                var temp: [(String, Int)] = []

                // her gruptaki fotoğraf sayıları
                for group in PhotoGroup.allCases {
                    let count = result.groups[group]?.count ?? 0
                    if count > 0 {
                        temp.append((group.rawValue.uppercased(), count))
                    }
                }

                // diğerleri
                let otherCount = result.others.count
                if otherCount > 0 {
                    temp.append(("Other", otherCount))
                }

                self.groupCounts = temp
            }
        )
    }
}
