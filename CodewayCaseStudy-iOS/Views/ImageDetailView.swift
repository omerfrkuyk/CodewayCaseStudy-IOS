//
//  ImageDetailView.swift
//  CodewayCaseStudy-iOS
//
//  Created by Ömer Uyanık on 23.11.2025.
//

import SwiftUI
import Photos

struct ImageDetailView: View {

    let assets: [PHAsset]
    @State var index: Int

    var body: some View {
        TabView(selection: $index) {
            ForEach(assets.indices, id: \.self) { i in
                ZoomablePhoto(asset: assets[i])
                    .tag(i)
            }
        }
        .tabViewStyle(.page)
        .background(Color.black)
        .ignoresSafeArea()
    }
}


// MARK: - Zoomable photo

struct ZoomablePhoto: View {

    let asset: PHAsset

    @State private var uiImage: UIImage?
    @State private var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            if let img = uiImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in scale = value }
                            .onEnded { _ in
                                withAnimation { scale = 1.0 }
                            }
                    )
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .background(Color.black)
        .onAppear {
            loadImage()
        }
    }

    /// Thumbnail’de çalışanla aynı mantık, sadece daha büyük hedef boyut.
    private func loadImage() {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        // Thumbnail 400x400'dü; burada daha yüksek çözünürlük istiyoruz.
        let targetSize = CGSize(width: 1200, height: 1200)

        manager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { result, _ in
            guard let result = result else {
                print("Detail DEBUG: failed to load full image for asset \(asset.localIdentifier)")
                return
            }

            DispatchQueue.main.async {
                self.uiImage = result
            }
        }
    }
}
