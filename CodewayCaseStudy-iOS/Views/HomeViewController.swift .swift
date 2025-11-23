//
//  HomeViewController.swift
//  CodewayCaseStudy-iOS
//
//  Created by Ömer Uyanık on 20.11.2025.
//

import UIKit
import SwiftUI
import Photos

class HomeViewController: UIViewController {

    // MARK: - UI

    private let progressLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 1
        label.text = "Scanning photos..."
        return label
    }()

    private let progressView: UIProgressView = {
        let view = UIProgressView(progressViewStyle: .default)
        view.progress = 0
        return view
    }()

    private let progressContainer: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill
        stack.distribution = .fill
        stack.isHidden = true
        return stack
    }()

    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        return UICollectionView(frame: .zero, collectionViewLayout: layout)
    }()

    // MARK: - Data

    private let scanner = PhotoScannerService()

    private var scanResult: ScanResult?
    private var displayGroups: [(name: String, count: Int)] = []

    private var isScanning = false
    private var processedCount = 0
    private var totalCount = 0

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Photo Groups"

        setupUI()
        requestPermissionAndStartScan()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard let screen = view.window?.windowScene?.screen,
              let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout
        else { return }

        let width = screen.bounds.width - 40
        let newSize = CGSize(width: width, height: 60)

        if layout.itemSize != newSize {
            layout.itemSize = newSize
        }
    }

    // MARK: - Setup

    private func setupUI() {
        progressContainer.addArrangedSubview(progressLabel)
        progressContainer.addArrangedSubview(progressView)

        view.addSubview(progressContainer)
        view.addSubview(collectionView)

        progressContainer.translatesAutoresizingMaskIntoConstraints = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            progressContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            progressContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            collectionView.topAnchor.constraint(equalTo: progressContainer.bottomAnchor, constant: 12),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        collectionView.dataSource = self
        collectionView.delegate = self

        collectionView.register(UICollectionViewCell.self,
                                forCellWithReuseIdentifier: "cell")

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Rescan",
            style: .plain,
            target: self,
            action: #selector(rescanTapped)
        )
    }

    // MARK: - Scanning

    private func requestPermissionAndStartScan() {
        scanner.requestPhotoAccess { [weak self] granted in
            guard let self = self else { return }

            if granted {
                self.startScan()
            } else {
                self.title = "Permission denied"
                self.progressContainer.isHidden = true
                self.navigationItem.rightBarButtonItem?.isEnabled = false
            }
        }
    }

    @objc private func rescanTapped() {
        startScan()
    }

    private func startScan() {
        guard !isScanning else { return }

        isScanning = true
        scanResult = nil
        displayGroups.removeAll()
        collectionView.reloadData()

        processedCount = 0
        totalCount = 0
        progressView.progress = 0
        progressLabel.text = "Scanning photos..."
        progressContainer.isHidden = false
        navigationItem.rightBarButtonItem?.isEnabled = false

        title = "Scanning..."

        scanner.scanAndGroupAllPhotos(
            progress: { [weak self] processed, total in
                guard let self = self else { return }
                self.processedCount = processed
                self.totalCount = total

                if total > 0 {
                    let fraction = Float(processed) / Float(total)
                    let percent = Int(fraction * 100)
                    self.progressView.progress = fraction
                    self.progressLabel.text = "Scanning photos: \(percent)% (\(processed)/\(total))"
                } else {
                    self.progressLabel.text = "Scanning photos..."
                }
            },
            partialUpdate: { [weak self] groups, others in
                guard let self = self else { return }
                // Her snapshot geldiğinde grupları live olarak güncelle
                self.rebuildDisplayGroups(groups: groups, others: others)
            },
            completion: { [weak self] result in
                guard let self = self else { return }
                self.isScanning = false
                self.title = "Photo Groups"
                self.navigationItem.rightBarButtonItem?.isEnabled = true

                self.scanResult = result
                self.progressContainer.isHidden = true

                // Son hal ile bir kez daha grupları kur
                self.rebuildDisplayGroups(groups: result.groups, others: result.others)
            }
        )
    }

    /// Verilen groups & others snapshot'ına göre displayGroups'u yeniden kurar.
    private func rebuildDisplayGroups(groups: [PhotoGroup: [PHAsset]], others: [PHAsset]) {
        displayGroups.removeAll()

        for group in PhotoGroup.allCases {
            let count = groups[group]?.count ?? 0
            if count > 0 {
                let name = group.rawValue.uppercased()
                displayGroups.append((name: name, count: count))
            }
        }

        let otherCount = others.count
        if otherCount > 0 {
            displayGroups.append((name: "OTHER", count: otherCount))
        }

        collectionView.reloadData()
    }
}

// MARK: - UICollectionViewDataSource & Delegate

extension HomeViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return displayGroups.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
        cell.backgroundColor = .systemGray6
        cell.layer.cornerRadius = 12

        let labelTag = 100
        var label = cell.contentView.viewWithTag(labelTag) as? UILabel

        if label == nil {
            label = UILabel()
            label?.tag = labelTag
            label?.font = .systemFont(ofSize: 18, weight: .medium)
            label?.textColor = .label
            cell.contentView.addSubview(label!)

            label?.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                label!.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                label!.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor)
            ])
        }

        let data = displayGroups[indexPath.row]
        label?.text = "\(data.name) – \(data.count) photos"

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let result = scanResult else { return }

        let data = displayGroups[indexPath.row]
        let groupName = data.name

        let assets: [PHAsset]
        if groupName == "OTHER" {
            assets = result.others
        } else if let group = PhotoGroup(rawValue: groupName.lowercased()) {
            assets = result.groups[group] ?? []
        } else {
            assets = []
        }

        let detailView = GroupDetailView(title: groupName, assets: assets)
        let hosting = UIHostingController(rootView: detailView)
        navigationController?.pushViewController(hosting, animated: true)
    }
}

// MARK: - SwiftUI Wrapper

struct HomeViewControllerWrapper: UIViewControllerRepresentable {

    func makeUIViewController(context: Context) -> UINavigationController {
        let homeVC = HomeViewController()
        let nav = UINavigationController(rootViewController: homeVC)
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}
