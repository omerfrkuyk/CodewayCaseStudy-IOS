//
//  GroupDetailView.swift
//  CodewayCaseStudy-iOS
//
//  Created by Ömer Uyanık on 21.11.2025.
//

import SwiftUI
import Photos

struct GroupDetailView: View {
    let title: String
    let assets: [PHAsset]

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack {
            if assets.isEmpty {
                Text("No photos found")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(Array(assets.enumerated()), id: \.element.localIdentifier) { index, asset in
                            NavigationLink {
                                ImageDetailView(assets: assets, index: index)
                            } label: {
                                PhotoThumbnail(asset: asset)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(title)
    }
}
