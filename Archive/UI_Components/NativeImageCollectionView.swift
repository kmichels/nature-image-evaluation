//
//  NativeImageCollectionView.swift
//  Nature Image Evaluation
//
//  Created by Claude on 11/19/25.
//

import SwiftUI
import AppKit
import CoreData

/// Native NSCollectionView wrapper for proper macOS collection behavior
struct NativeImageCollectionView: NSViewRepresentable {
    let images: [ImageEvaluation]
    @Binding var selection: Set<NSManagedObjectID>
    let onDoubleClick: (ImageEvaluation) -> Void
    let evaluationManager: EvaluationManager

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let collectionView = NSCollectionView()

        // Set up scroll view with autoresizing to fill SwiftUI container
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        scrollView.autoresizingMask = [.width, .height]

        // Give it an initial frame (will be resized by SwiftUI)
        scrollView.frame = NSRect(x: 0, y: 0, width: 800, height: 600)

        // Configure collection view BEFORE setting as documentView
        collectionView.backgroundColors = [.clear]
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = true
        collectionView.allowsEmptySelection = true
        collectionView.autoresizingMask = [.width, .height]

        // Set initial frame for collection view
        collectionView.frame = NSRect(x: 0, y: 0, width: 800, height: 600)

        // Configure flow layout
        let flowLayout = NSCollectionViewFlowLayout()
        flowLayout.minimumLineSpacing = 20
        flowLayout.minimumInteritemSpacing = 20
        flowLayout.itemSize = NSSize(width: 175, height: 200)
        flowLayout.sectionInset = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        collectionView.collectionViewLayout = flowLayout

        // Set delegate and data source
        collectionView.delegate = context.coordinator
        collectionView.dataSource = context.coordinator

        // Set up double-click gesture recognizer
        let clickGesture = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleClick(_:)))
        clickGesture.numberOfClicksRequired = 2
        collectionView.addGestureRecognizer(clickGesture)

        // Now set as document view
        scrollView.documentView = collectionView

        // Store reference for coordinator
        context.coordinator.collectionView = collectionView

        print("✅ Created NSCollectionView with layout: \(flowLayout)")
        print("  ↳ Initial scroll view frame: \(scrollView.frame)")
        print("  ↳ Initial collection view frame: \(collectionView.frame)")

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let collectionView = scrollView.documentView as? NSCollectionView else { return }

        print("🔄 NativeImageCollectionView.updateNSView called with \(images.count) images")

        // Check if we have a valid frame from SwiftUI
        if let superview = scrollView.superview, superview.frame.size != .zero {
            // Update frame to match superview if needed
            if scrollView.frame.size != superview.frame.size {
                print("  📐 Updating frame to match superview: \(superview.frame.size)")
                scrollView.frame = superview.bounds
                collectionView.frame = NSRect(origin: .zero, size: superview.frame.size)
            }
        } else if scrollView.frame.size == .zero {
            print("  ⚠️ ScrollView has zero frame, waiting for layout...")
            // If we still have zero frame, SwiftUI hasn't laid us out yet
            // Schedule an update for the next run loop
            DispatchQueue.main.async {
                scrollView.needsLayout = true
                collectionView.needsLayout = true
            }
        }

        // Check if we actually need to reload data by comparing actual content
        let oldImages = context.coordinator.images
        let dataChanged = oldImages.count != images.count ||
                         !oldImages.elementsEqual(images, by: { $0.objectID == $1.objectID })

        // Update data
        context.coordinator.images = images
        context.coordinator.evaluationManager = evaluationManager

        // Only reload if data actually changed (not just selection)
        if dataChanged {
            print("  📊 Data actually changed - old count: \(oldImages.count), new count: \(images.count)")

            // Preserve scroll position before reload
            let visibleRect = scrollView.visibleRect
            let wasScrolled = visibleRect.origin.y > 0

            // Force layout invalidation before reload
            collectionView.collectionViewLayout?.invalidateLayout()
            collectionView.reloadData()

            // Force layout update
            collectionView.needsLayout = true

            // Restore scroll position after reload if we were scrolled
            if wasScrolled {
                DispatchQueue.main.async {
                    scrollView.contentView.scroll(to: NSPoint(x: 0, y: visibleRect.origin.y))
                    scrollView.reflectScrolledClipView(scrollView.contentView)
                }
            }

            print("  ↳ Called reloadData on collection view")
        } else {
            print("  ✅ Data unchanged - skipping reload")
        }

        print("  ↳ Collection view frame: \(collectionView.frame)")
        print("  ↳ Scroll view frame: \(scrollView.frame)")
        print("  ↳ Superview frame: \(scrollView.superview?.frame ?? .zero)")

        // Update selection only if not from user interaction
        if !context.coordinator.isUpdatingSelectionFromUser {
            let currentSelection = collectionView.selectionIndexPaths
            let newSelection = indexPaths(for: selection, in: images)

            if currentSelection != newSelection {
                print("  🔄 Programmatic selection update - current: \(currentSelection.count) items, new: \(newSelection.count) items")

                // Preserve scroll position before changing selection
                let visibleRect = scrollView.visibleRect

                // Update selection without scrolling using CATransaction
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                collectionView.selectionIndexPaths = newSelection
                CATransaction.commit()

                // Ensure scroll position is maintained
                if visibleRect.origin.y > 0 {
                    scrollView.contentView.scroll(to: visibleRect.origin)
                    scrollView.reflectScrolledClipView(scrollView.contentView)
                }
            }
        } else {
            print("  ⏭️ Skipping selection update - came from user interaction")
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            images: images,
            selection: $selection,
            onDoubleClick: onDoubleClick,
            evaluationManager: evaluationManager
        )
    }

    private func indexPaths(for selection: Set<NSManagedObjectID>, in images: [ImageEvaluation]) -> Set<IndexPath> {
        var paths = Set<IndexPath>()
        for (index, image) in images.enumerated() {
            if selection.contains(image.objectID) {
                paths.insert(IndexPath(item: index, section: 0))
            }
        }
        return paths
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSCollectionViewDataSource, NSCollectionViewDelegate {
        var images: [ImageEvaluation]
        var selection: Binding<Set<NSManagedObjectID>>
        let onDoubleClick: (ImageEvaluation) -> Void
        var evaluationManager: EvaluationManager
        weak var collectionView: NSCollectionView?
        var isUpdatingSelectionFromUser = false  // Track user-initiated selection changes

        init(images: [ImageEvaluation],
             selection: Binding<Set<NSManagedObjectID>>,
             onDoubleClick: @escaping (ImageEvaluation) -> Void,
             evaluationManager: EvaluationManager) {
            self.images = images
            self.selection = selection
            self.onDoubleClick = onDoubleClick
            self.evaluationManager = evaluationManager
            super.init()
        }

        // MARK: - NSCollectionViewDataSource

        func numberOfSections(in collectionView: NSCollectionView) -> Int {
            print("📊 numberOfSections called - returning 1")
            return 1
        }

        func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
            print("📊 numberOfItemsInSection called - returning \(images.count)")
            return images.count
        }

        func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
            print("📦 Creating/reusing item for index \(indexPath.item)")

            // Create new shared item
            let item = SharedImageCollectionViewItem()
            // Force loadView to be called by accessing the view
            _ = item.view

            let image = images[indexPath.item]

            // Get filename
            var filename = "Unknown"
            if let bookmarkData = image.originalFilePath {
                do {
                    var isStale = false
                    let url = try URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale)
                    filename = url.lastPathComponent
                } catch {
                    // Use fallback
                }
            }

            // Get thumbnail
            var thumbnail: NSImage?
            if let thumbnailData = image.thumbnailData {
                thumbnail = NSImage(data: thumbnailData)
            }

            // Check if being evaluated
            let isProcessing = evaluationManager.evaluationQueue.contains(image) &&
                              evaluationManager.isProcessing &&
                              evaluationManager.evaluationQueue.firstIndex(of: image) == evaluationManager.currentImageIndex - 1

            let isInQueue = evaluationManager.evaluationQueue.contains(image) && !isProcessing

            // Configure with shared configuration
            let config = SharedImageCollectionViewItem.Configuration(
                imageURL: nil,  // Not used for Quick Analysis
                imageEvaluation: image,
                evaluationResult: image.currentEvaluation,
                thumbnail: thumbnail,
                filename: filename,
                isProcessing: isProcessing,
                isInQueue: isInQueue,
                isSelected: selection.wrappedValue.contains(image.objectID)
            )

            item.configure(with: config)

            print("🎯 Configuring item for image: \(image.objectID)")
            print("  - Has evaluation result: \(image.currentEvaluation != nil)")
            if let score = image.currentEvaluation?.overallWeightedScore {
                print("  - Score: \(score)")
            }

            return item
        }

        // MARK: - NSCollectionViewDelegate

        func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
            isUpdatingSelectionFromUser = true
            updateSelection(from: collectionView)
            // Reset flag after a short delay to allow updateNSView to run
            DispatchQueue.main.async { [weak self] in
                self?.isUpdatingSelectionFromUser = false
            }
        }

        func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
            isUpdatingSelectionFromUser = true
            updateSelection(from: collectionView)
            // Reset flag after a short delay to allow updateNSView to run
            DispatchQueue.main.async { [weak self] in
                self?.isUpdatingSelectionFromUser = false
            }
        }

        // Handle double-click action
        @objc func handleDoubleClick(_ gestureRecognizer: NSClickGestureRecognizer) {
            print("🖱 Double-click gesture triggered in NativeImageCollectionView")

            guard let collectionView = gestureRecognizer.view as? NSCollectionView else { return }

            // Get the location of the click
            let location = gestureRecognizer.location(in: collectionView)

            // Find which item was double-clicked
            if let indexPath = collectionView.indexPathForItem(at: location),
               indexPath.item < images.count {
                let image = images[indexPath.item]
                print("  ✅ Double-click detected on image at index \(indexPath.item)")
                print("  ↳ Opening detail view for image: \(image.objectID)")
                onDoubleClick(image)
            } else {
                print("  ❌ No item found at click location")
            }
        }

        private func updateSelection(from collectionView: NSCollectionView) {
            let selectedIndexPaths = collectionView.selectionIndexPaths
            var selectedIDs = Set<NSManagedObjectID>()

            for indexPath in selectedIndexPaths {
                if indexPath.item < images.count {
                    selectedIDs.insert(images[indexPath.item].objectID)
                }
            }

            selection.wrappedValue = selectedIDs
        }

    }
}