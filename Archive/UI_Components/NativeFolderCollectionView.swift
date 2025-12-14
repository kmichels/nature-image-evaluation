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

    // Optional stable ID passed from parent
    var stableViewID: String = "default"

    func makeNSView(context: Context) -> NSScrollView {
        print("🏗️ NativeFolderCollectionView.makeNSView called - Creating new NSScrollView (Stable ID: \(stableViewID))")
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

        // If we have a preserved scroll position, restore it immediately
        if let preservedPosition = context.coordinator.preservedScrollPosition {
            scrollView.contentView.scroll(to: preservedPosition)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }

        let scrollStart = scrollView.visibleRect.origin.y
        print("🔄 NativeFolderCollectionView.updateNSView called (Stable ID: \(stableViewID))")
        print("   URLs: \(imageURLs.count) items, Selection: \(selection.count) items")
        print("   Scroll position: \(scrollStart)")
        if context.coordinator.preservedScrollPosition != nil {
            print("   📍 Forcing preserved scroll position")
        }

        // Check if we actually need to reload data by comparing actual content
        let oldURLs = context.coordinator.imageURLs
        let oldEvaluations = context.coordinator.existingEvaluations

        // Compare URLs by actual content, not array reference
        let urlsChanged = oldURLs.count != imageURLs.count ||
                         !oldURLs.elementsEqual(imageURLs)

        // Compare evaluation dictionaries
        let evaluationsChanged = oldEvaluations.count != existingEvaluations.count ||
                                Set(oldEvaluations.keys) != Set(existingEvaluations.keys)

        let dataChanged = urlsChanged || evaluationsChanged

        if dataChanged {
            print("   📊 Data changed - URLs: \(urlsChanged), Evaluations: \(evaluationsChanged)")
        }

        // Update data
        context.coordinator.imageURLs = imageURLs
        context.coordinator.existingEvaluations = existingEvaluations
        context.coordinator.thumbnailCache = thumbnailCache

        // Only reload if data actually changed (not just selection)
        if dataChanged {
            print("   Performing reload...")
            // Preserve scroll position before reload
            let visibleRect = scrollView.visibleRect
            let wasScrolled = visibleRect.origin.y > 0

            collectionView.reloadData()

            // Restore scroll position after reload if we were scrolled
            if wasScrolled {
                DispatchQueue.main.async {
                    scrollView.contentView.scroll(to: NSPoint(x: 0, y: visibleRect.origin.y))
                    scrollView.reflectScrolledClipView(scrollView.contentView)
                }
            }
        } else {
            print("   ✅ Data unchanged - skipping reload")
        }

        // Update selection only if not from user interaction
        if !context.coordinator.isUpdatingSelectionFromUser {
            let currentSelection = collectionView.selectionIndexPaths
            let newSelection = indexPaths(for: selection, in: imageURLs)

            if currentSelection != newSelection {
                print("📍 Selection update needed - current: \(currentSelection.count), new: \(newSelection.count)")
                print("   User interaction flag: \(context.coordinator.isUpdatingSelectionFromUser)")
                print("   Scroll position: \(scrollView.visibleRect.origin.y)")

                // Preserve scroll position before changing selection
                let visibleRect = scrollView.visibleRect

                // Update selection without scrolling
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                collectionView.selectionIndexPaths = newSelection
                CATransaction.commit()

                // Always maintain scroll position (negative values are normal when scrolled down)
                scrollView.contentView.scroll(to: visibleRect.origin)
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
        } else {
            print("⏭️ Skipping selection update - user interaction in progress")
        }

        // Check if scroll position changed significantly during this update
        let scrollEnd = scrollView.visibleRect.origin.y
        let scrollDelta = abs(scrollEnd - scrollStart)
        if scrollDelta > 10 {  // Only log significant changes
            print("   ⚠️ Significant scroll change during updateNSView: \(scrollStart) -> \(scrollEnd) (delta: \(scrollDelta))")
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
        var isUpdatingSelectionFromUser = false  // Track user-initiated selection changes
        var preservedScrollPosition: NSPoint? = nil  // Store scroll position to forcibly maintain it

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
                // Capture necessary values for the async task
                let currentUrl = url
                let currentEvaluation = evaluation
                let currentFilename = url.lastPathComponent
                let currentIndexPath = indexPath
                let isCurrentlySelected = selection.wrappedValue.contains(url)
                let thumbnailCallback = self.onThumbnailLoaded  // Capture the callback
                weak var weakCollectionView = collectionView  // Weak reference to collection view

                // Load thumbnail asynchronously on background queue
                Task.detached(priority: .userInitiated) {
                    // Load image on background thread
                    guard let image = NSImage(contentsOf: currentUrl) else { return }

                    // Create thumbnail on background thread
                    let targetSize = NSSize(width: 175, height: 140)
                    let thumbnailImage = NSImage(size: targetSize)

                    thumbnailImage.lockFocus()
                    image.draw(in: NSRect(origin: .zero, size: targetSize),
                              from: NSRect(origin: .zero, size: image.size),
                              operation: .copy,
                              fraction: 1.0)
                    thumbnailImage.unlockFocus()

                    // Update UI on main thread
                    await MainActor.run {
                        // Notify parent to cache the thumbnail
                        thumbnailCallback(currentUrl, thumbnailImage)

                        // Update the item if it's still visible
                        if let visibleItem = weakCollectionView?.item(at: currentIndexPath) as? SharedImageCollectionViewItem {
                            let updatedConfig = SharedImageCollectionViewItem.Configuration(
                                imageURL: currentUrl,
                                imageEvaluation: currentEvaluation,
                                evaluationResult: currentEvaluation?.currentEvaluation,
                                thumbnail: thumbnailImage,
                                filename: currentFilename,
                                isProcessing: false,
                                isInQueue: false,
                                isSelected: isCurrentlySelected
                            )
                            visibleItem.configure(with: updatedConfig)
                        }
                    }
                }
            }

            return item
        }

        // MARK: - NSCollectionViewDelegate

        func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
            guard let scrollView = collectionView.enclosingScrollView else { return }
            let scrollBefore = scrollView.visibleRect.origin
            print("👆 User selected items at indices: \(indexPaths.map { $0.item })")
            print("   Scroll at selection start: \(scrollBefore)")

            // Preserve scroll position
            preservedScrollPosition = scrollBefore

            // Set flag to prevent programmatic selection updates
            isUpdatingSelectionFromUser = true

            // Update selection (now async internally)
            updateSelection(from: collectionView)

            // Force scroll position to stay the same
            scrollView.contentView.scroll(to: scrollBefore)
            scrollView.reflectScrolledClipView(scrollView.contentView)

            // Keep forcing the scroll position for a bit
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
                scrollView.contentView.scroll(to: scrollBefore)
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }

            // Keep flag set for a longer duration to cover the async update cycle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                let scrollFinal = scrollView.visibleRect.origin.y
                print("   Resetting user interaction flag, scroll now: \(scrollFinal)")
                self?.isUpdatingSelectionFromUser = false
                self?.preservedScrollPosition = nil
            }
        }

        func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
            print("👇 User deselected items at indices: \(indexPaths.map { $0.item })")

            // Set flag to prevent programmatic selection updates
            isUpdatingSelectionFromUser = true

            // Update selection (now async internally)
            updateSelection(from: collectionView)

            // Keep flag set for a longer duration to cover the async update cycle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                print("   Resetting user interaction flag")
                self?.isUpdatingSelectionFromUser = false
            }
        }

        private func updateSelection(from collectionView: NSCollectionView) {
            let selectedIndexPaths = collectionView.selectionIndexPaths
            var selectedURLs = Set<URL>()

            for indexPath in selectedIndexPaths {
                if indexPath.item < imageURLs.count {
                    selectedURLs.insert(imageURLs[indexPath.item])
                }
            }

            print("   📝 Updating selection binding with \(selectedURLs.count) URLs")

            // Update binding asynchronously to break potential update cycles
            // This is crucial based on Apple's documentation for NSViewRepresentable
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.selection.wrappedValue = selectedURLs
                print("   ✅ Selection binding updated asynchronously")
            }
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

