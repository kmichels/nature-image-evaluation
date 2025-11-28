//
//  NativeFolderCollectionView.swift
//  Nature Image Evaluation
//
//  Created by Claude on 11/19/25.
//

import SwiftUI
import AppKit
import CoreData

/// Native NSCollectionView wrapper for folder-based image collections
struct NativeFolderCollectionView: NSViewRepresentable {
    let imageURLs: [URL]
    @Binding var selection: Set<URL>
    let existingEvaluations: [URL: ImageEvaluation]
    let thumbnailCache: [URL: NSImage]
    let onDoubleClick: (ImageEvaluation?) -> Void
    let onThumbnailLoaded: (URL, NSImage) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let collectionView = NSCollectionView()

        scrollView.documentView = collectionView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear

        // Configure collection view
        collectionView.delegate = context.coordinator
        collectionView.dataSource = context.coordinator
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = true
        collectionView.allowsEmptySelection = true
        collectionView.backgroundColors = [.clear]

        // Note: We don't register the item class - we'll create items directly in the data source

        // Configure flow layout
        let flowLayout = NSCollectionViewFlowLayout()
        flowLayout.minimumLineSpacing = 20
        flowLayout.minimumInteritemSpacing = 20
        flowLayout.itemSize = NSSize(width: 175, height: 200)
        flowLayout.sectionInset = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        collectionView.collectionViewLayout = flowLayout

        // Set up double-click gesture recognizer
        let clickGesture = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleClick(_:)))
        clickGesture.numberOfClicksRequired = 2
        collectionView.addGestureRecognizer(clickGesture)

        // Store reference for coordinator
        context.coordinator.collectionView = collectionView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let collectionView = scrollView.documentView as? NSCollectionView else { return }

        // Update data
        context.coordinator.imageURLs = imageURLs
        context.coordinator.existingEvaluations = existingEvaluations
        context.coordinator.thumbnailCache = thumbnailCache
        collectionView.reloadData()

        // Update selection
        let currentSelection = collectionView.selectionIndexPaths
        let newSelection = indexPaths(for: selection, in: imageURLs)

        if currentSelection != newSelection {
            collectionView.selectionIndexPaths = newSelection
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            imageURLs: imageURLs,
            selection: $selection,
            existingEvaluations: existingEvaluations,
            thumbnailCache: thumbnailCache,
            onDoubleClick: onDoubleClick,
            onThumbnailLoaded: onThumbnailLoaded
        )
    }

    private func indexPaths(for selection: Set<URL>, in urls: [URL]) -> Set<IndexPath> {
        var paths = Set<IndexPath>()
        for (index, url) in urls.enumerated() {
            if selection.contains(url) {
                paths.insert(IndexPath(item: index, section: 0))
            }
        }
        return paths
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSCollectionViewDataSource, NSCollectionViewDelegate {
        var imageURLs: [URL]
        var selection: Binding<Set<URL>>
        var existingEvaluations: [URL: ImageEvaluation]
        var thumbnailCache: [URL: NSImage]
        let onDoubleClick: (ImageEvaluation?) -> Void
        let onThumbnailLoaded: (URL, NSImage) -> Void
        weak var collectionView: NSCollectionView?

        init(imageURLs: [URL],
             selection: Binding<Set<URL>>,
             existingEvaluations: [URL: ImageEvaluation],
             thumbnailCache: [URL: NSImage],
             onDoubleClick: @escaping (ImageEvaluation?) -> Void,
             onThumbnailLoaded: @escaping (URL, NSImage) -> Void) {
            self.imageURLs = imageURLs
            self.selection = selection
            self.existingEvaluations = existingEvaluations
            self.thumbnailCache = thumbnailCache
            self.onDoubleClick = onDoubleClick
            self.onThumbnailLoaded = onThumbnailLoaded
            super.init()
        }

        // MARK: - NSCollectionViewDataSource

        func numberOfSections(in collectionView: NSCollectionView) -> Int {
            return 1
        }

        func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
            return imageURLs.count
        }

        func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
            // Create shared item
            let item = SharedImageCollectionViewItem()

            // Force loadView to be called by accessing the view
            _ = item.view

            let url = imageURLs[indexPath.item]
            let evaluation = existingEvaluations[url]
            let thumbnail = thumbnailCache[url]

            // Configure with shared configuration
            let config = SharedImageCollectionViewItem.Configuration(
                imageURL: url,
                imageEvaluation: evaluation,
                evaluationResult: evaluation?.currentEvaluation,
                thumbnail: thumbnail,
                filename: url.lastPathComponent,
                isProcessing: false,  // Folder view doesn't show processing state
                isInQueue: false,
                isSelected: selection.wrappedValue.contains(url)
            )

            item.configure(with: config)

            // Handle thumbnail loading if needed
            if thumbnail == nil {
                Task { @MainActor in
                    guard let image = NSImage(contentsOf: url) else { return }

                    // Create thumbnail
                    let targetSize = NSSize(width: 175, height: 140)
                    let thumbnailImage = NSImage(size: targetSize)

                    thumbnailImage.lockFocus()
                    image.draw(in: NSRect(origin: .zero, size: targetSize),
                              from: NSRect(origin: .zero, size: image.size),
                              operation: .copy,
                              fraction: 1.0)
                    thumbnailImage.unlockFocus()

                    // Notify parent to cache the thumbnail
                    onThumbnailLoaded(url, thumbnailImage)

                    // Update the item if it's still visible
                    if let visibleItem = collectionView.item(at: indexPath) as? SharedImageCollectionViewItem {
                        let updatedConfig = SharedImageCollectionViewItem.Configuration(
                            imageURL: url,
                            imageEvaluation: evaluation,
                            evaluationResult: evaluation?.currentEvaluation,
                            thumbnail: thumbnailImage,
                            filename: url.lastPathComponent,
                            isProcessing: false,
                            isInQueue: false,
                            isSelected: selection.wrappedValue.contains(url)
                        )
                        visibleItem.configure(with: updatedConfig)
                    }
                }
            }

            return item
        }

        // MARK: - NSCollectionViewDelegate

        func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
            updateSelection(from: collectionView)
        }

        func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
            updateSelection(from: collectionView)
        }

        private func updateSelection(from collectionView: NSCollectionView) {
            let selectedIndexPaths = collectionView.selectionIndexPaths
            var selectedURLs = Set<URL>()

            for indexPath in selectedIndexPaths {
                if indexPath.item < imageURLs.count {
                    selectedURLs.insert(imageURLs[indexPath.item])
                }
            }

            selection.wrappedValue = selectedURLs
        }

        // Handle double-click action
        @objc func handleDoubleClick(_ gestureRecognizer: NSClickGestureRecognizer) {
            print("🖱 Double-click gesture triggered in NativeFolderCollectionView")

            guard let collectionView = gestureRecognizer.view as? NSCollectionView else { return }

            // Get the location of the click
            let location = gestureRecognizer.location(in: collectionView)

            // Find which item was double-clicked
            if let indexPath = collectionView.indexPathForItem(at: location),
               indexPath.item < imageURLs.count {
                let url = imageURLs[indexPath.item]
                let evaluation = existingEvaluations[url]
                print("  ✅ Double-click detected on image at index \(indexPath.item)")
                print("  ↳ URL: \(url.lastPathComponent)")
                print("  ↳ Has evaluation: \(evaluation != nil)")
                onDoubleClick(evaluation)
            } else {
                print("  ❌ No item found at click location")
            }
        }
    }
}

