//
//  PhotoThumbnail.swift
//  CodewayCaseStudy-iOS
//
//  Created by Ömer Uyanık on 21.11.2025.
//

import SwiftUI
import Photos
import UIKit

struct PhotoThumbnail: View {
    let asset: PHAsset
    @State private var image: UIImage? = nil

    var body: some View {
        ZStack {
            if let uiImage = image {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
           
                Color.gray.opacity(0.2)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipped()
        .onAppear {
            loadImage()
        }
    }

    private func loadImage() {
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 400, height: 400),
            contentMode: .aspectFill,
            options: nil
        ) { result, info in
         

            guard let result = result else { return }

            DispatchQueue.main.async {
                self.image = result
            }
        }
    }
}
