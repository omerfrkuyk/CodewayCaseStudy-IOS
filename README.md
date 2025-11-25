
# Codeway iOS Photo Grouping Case Study

This repository contains the full implementation of the Codeway iOS Case Study.  
The app scans all photos on the device, groups them using a hashing strategy, and displays them through a mixed UIKit + SwiftUI architecture.

---

## Features (Required & Completed)

### ✔ 1. Photo Scanning & Grouping
- All photos are fetched using **PHPhotoLibrary**.
- Each asset is assigned a numeric hash (0.0–1.0) using a deterministic SHA256-based function.
- Based on the hash value, each photo is placed into one of the predefined **PhotoGroup** buckets.
- A leftover group **"Others"** collects assets that do not match any defined range.

### ✔ 2. Progressive Results (Real-time Updates)
- As scanning runs in the background, the UI updates progressively:
  - Live progress bar (`UIProgressView`)
  - Live percentage + processed/total count
  - Group counts update progressively (partialUpdate)
- Results appear on the Home Screen as soon as available — no waiting for full scan.

### ✔ 3. Home Screen (UIKit)
- Implemented using `UICollectionView` + `UICollectionViewFlowLayout`.
- Each cell shows:
  - Group name (A–T or OTHER)
  - Number of photos dynamically updated during scanning.
- Selecting a cell pushes a SwiftUI `GroupDetailView` using `UIHostingController`.

---

##  Screens

### ✔ Home Screen (UIKit)
- Displays all groups with non‑zero counts.
- Provides a **Rescan** button.
- Supports progressive updates.

### ✔ Group Detail Screen (SwiftUI)
- Shows a 3-column grid of thumbnails (`LazyVGrid`).
- Uses `PhotoThumbnail` to request optimized thumbnails from Photos.
- Tapping a thumbnail opens the Image Detail screen.

### ✔ Image Detail Screen (SwiftUI)
- Full-screen image viewer.
- Implemented using:
  - `TabView` for horizontal swiping
  - `ZoomablePhoto` view (pinch to zoom)
- Supports:
  - Smooth swiping between all images in group
  - High-quality progressive image loading
  - Simultaneous handling of simulator/device edge cases

---

##  Persistence (Bonus Implementations)

### ✔ Persisting Scan Results
- Final grouped result saved as JSON:
  - Only `localIdentifier` values are stored.
  - Reconstructed on app launch using `PHAsset.fetchAssets`.
- Allows app to reopen **without rescanning**.

### ✔ Persisting Scan Progress (Resume Scan)
- The scanning progress is saved every 10 items:
  - processed count
  - total count
  - partial group states
- If the app is terminated:
  - On next launch, scanning resumes from the last processed photo.
- Fully implemented using JSON persistence.

---

##  Architecture

### Mixed UIKit + SwiftUI Setup
- **UIKit**:
  - Home screen
  - Navigation stack
  - Collection view
- **SwiftUI**:
  - Group detail grid
  - Image detail viewer
  - Thumbnail + zoom logic
- Connected with `UIViewControllerRepresentable` & `UIHostingController`.

### Services
- `PhotoScannerService`
  - Photo fetching
  - Hashing & grouping
  - Progress callbacks
  - Persistence for result & progress

---

##  Technical Highlights

### PHAsset Handling
- All persistence uses `localIdentifier` instead of keeping PHAsset references.
- Assets are always reconstructed correctly after app restart.
- Uses:
  - `PHImageManager`
  - `PHCachingImageManager`
  - `requestImageData` fallback for full compatibility

### Optimized Thumbnail Loading
- Thumbnails requested at 400x400 for performance.
- Full-resolution images use a safe, device-agnostic target size (no deprecated API usage).

### Avoiding Deprecated APIs
- No `UIScreen.main`
- No deprecated scaling APIs
- All UI built to support iOS 26+ environment.

---

##  Project Structure

```
CodewayCaseStudy-iOS/
│
├── Models/
├── Services/
│   └── PhotoScannerService.swift
├── Utils/
│   └── (hash extension, helpers)
├── Views/
│   ├── HomeViewController.swift
│   ├── GroupDetailView.swift
│   ├── ImageDetailView.swift
│   └── PhotoThumbnail.swift
├── ViewModels/ (unused; MVVM not required)
├── CodewayCaseStudyApp.swift
└── ContentView.swift
```

---

##  Rescanning Behavior

- **Rescan button** always performs a fresh scan (ignores saved progress).
- UI keeps old group counts visible until updated.
- New progress and partial results progressively replace the old values.

---

##  Final Notes

This implementation satisfies all core requirements and implements bonuses:

### ✔ Required
- Scanning  
- Grouping  
- Progressive UI  
- Home screen  
- Group detail screen  
- Image detail (zoom + swipe)

### ✔ Bonus
- Persisting final scan result  
- Persisting scan progress  
- Resume scan  
- Full swipe-based photo viewer  
- Handling PHAsset edge cases  

---

##  License
This project is developed for a Codeway recruitment case study. 
