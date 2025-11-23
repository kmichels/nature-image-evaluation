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

        // Store reference for coordinator
        context.coordinator.collectionView = collectionView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let collectionView = scrollView.documentView as? NSCollectionView else { return }

        // Update data
        context.coordinator.images = images
        context.coordinator.evaluationManager = evaluationManager
        collectionView.reloadData()

        // Update selection
        let currentSelection = collectionView.selectionIndexPaths
        let newSelection = indexPaths(for: selection, in: images)

        if currentSelection != newSelection {
            collectionView.selectionIndexPaths = newSelection
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
            return 1
        }

        func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
            return images.count
        }

        func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
            // Create item directly instead of using makeItem
            let item = ImageCollectionViewItem()

            // Force loadView to be called by accessing the view
            _ = item.view

            let image = images[indexPath.item]
            item.configure(
                with: image,
                evaluationManager: evaluationManager,
                isSelected: selection.wrappedValue.contains(image.objectID)
            )

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
            var selectedIDs = Set<NSManagedObjectID>()

            for indexPath in selectedIndexPaths {
                if indexPath.item < images.count {
                    selectedIDs.insert(images[indexPath.item].objectID)
                }
            }

            selection.wrappedValue = selectedIDs
        }

        // Handle double-click
        func collectionView(_ collectionView: NSCollectionView, didDoubleClickAt indexPath: IndexPath) {
            if indexPath.item < images.count {
                onDoubleClick(images[indexPath.item])
            }
        }
    }
}

// MARK: - Custom Collection View Item

class ImageCollectionViewItem: NSCollectionViewItem {
    private var thumbnailImageView: NSImageView!
    private var titleLabel: NSTextField!
    private var scoreLabel: NSTextField!
    private var statusIndicator: NSProgressIndicator!
    private var selectionOverlay: NSView!

    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 175, height: 200))
        view.wantsLayer = true

        // Thumbnail image
        thumbnailImageView = NSImageView(frame: NSRect(x: 0, y: 40, width: 175, height: 140))
        thumbnailImageView.imageScaling = .scaleProportionallyUpOrDown
        thumbnailImageView.wantsLayer = true
        thumbnailImageView.layer?.cornerRadius = 8
        thumbnailImageView.layer?.masksToBounds = true
        thumbnailImageView.layer?.borderWidth = 1
        thumbnailImageView.layer?.borderColor = NSColor.separatorColor.cgColor
        view.addSubview(thumbnailImageView)

        // Title label
        titleLabel = NSTextField(labelWithString: "")
        titleLabel.frame = NSRect(x: 0, y: 20, width: 175, height: 20)
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.font = .systemFont(ofSize: 11)
        view.addSubview(titleLabel)

        // Score label
        scoreLabel = NSTextField(labelWithString: "")
        scoreLabel.frame = NSRect(x: 0, y: 0, width: 175, height: 20)
        scoreLabel.alignment = .center
        scoreLabel.font = .systemFont(ofSize: 10)
        scoreLabel.textColor = .secondaryLabelColor
        view.addSubview(scoreLabel)

        // Status indicator (for processing)
        statusIndicator = NSProgressIndicator(frame: NSRect(x: 77, y: 100, width: 20, height: 20))
        statusIndicator.style = .spinning
        statusIndicator.isDisplayedWhenStopped = false
        statusIndicator.controlSize = .small
        view.addSubview(statusIndicator)

        // Selection overlay
        selectionOverlay = NSView(frame: thumbnailImageView.frame)
        selectionOverlay.wantsLayer = true
        selectionOverlay.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.3).cgColor
        selectionOverlay.layer?.cornerRadius = 8
        selectionOverlay.layer?.borderWidth = 3
        selectionOverlay.layer?.borderColor = NSColor.controlAccentColor.cgColor
        selectionOverlay.isHidden = true
        view.addSubview(selectionOverlay)
    }

    override var isSelected: Bool {
        didSet {
            selectionOverlay.isHidden = !isSelected
            thumbnailImageView.layer?.borderColor = isSelected ?
                NSColor.controlAccentColor.cgColor :
                NSColor.separatorColor.cgColor
            thumbnailImageView.layer?.borderWidth = isSelected ? 2 : 1
        }
    }

    func configure(with evaluation: ImageEvaluation, evaluationManager: EvaluationManager, isSelected: Bool) {
        // Load thumbnail
        if let thumbnailData = evaluation.thumbnailData,
           let thumbnail = NSImage(data: thumbnailData) {
            thumbnailImageView.image = thumbnail
        } else {
            thumbnailImageView.image = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
        }

        // Set filename
        var filename = "Unknown"
        if let bookmarkData = evaluation.originalFilePath {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale)
                filename = url.lastPathComponent
            } catch {
                // Use fallback
            }
        }
        titleLabel.stringValue = filename

        // Set score if available
        if let score = evaluation.currentEvaluation?.overallWeightedScore {
            scoreLabel.stringValue = String(format: "Score: %.1f", score)
            scoreLabel.isHidden = false
        } else {
            scoreLabel.isHidden = true
        }

        // Check if being evaluated
        let isProcessing = evaluationManager.evaluationQueue.contains(evaluation) &&
                          evaluationManager.isProcessing
        if isProcessing {
            statusIndicator.startAnimation(nil)
        } else {
            statusIndicator.stopAnimation(nil)
        }

        // Update selection state
        self.isSelected = isSelected
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImageView.image = nil
        titleLabel.stringValue = ""
        scoreLabel.stringValue = ""
        scoreLabel.isHidden = true
        statusIndicator.stopAnimation(nil)
        selectionOverlay.isHidden = true
    }

    override func mouseDown(with event: NSEvent) {
        // Let the collection view handle selection
        super.mouseDown(with: event)

        // Check for double-click
        if event.clickCount == 2 {
            if let collectionView = self.collectionView,
               let indexPath = collectionView.indexPath(for: self),
               let coordinator = collectionView.delegate as? NativeImageCollectionView.Coordinator {
                coordinator.collectionView(collectionView, didDoubleClickAt: indexPath)
            }
        }
    }
}