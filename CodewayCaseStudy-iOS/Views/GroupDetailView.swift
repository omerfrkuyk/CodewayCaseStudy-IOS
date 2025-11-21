//
//  GroupDetailView.swift
//  PhotoGroupingCaseStudy
//
//  Created by Ömer Uyanık on 21.11.2025.
//

import SwiftUI
import Photos

struct GroupDetailView: View {
    let title: String
    let assets: [PHAsset]

    var body: some View {
        VStack {
            if assets.isEmpty {
                Text("No photos found")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(assets, id: \.localIdentifier) { asset in
                            PhotoThumbnail(asset: asset)
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(title)
    }
}
