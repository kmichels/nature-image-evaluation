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
            // Create item directly instead of using makeItem
            let item = FolderImageCollectionViewItem()

            // Force loadView to be called by accessing the view
            _ = item.view

            let url = imageURLs[indexPath.item]
            let evaluation = existingEvaluations[url]
            let thumbnail = thumbnailCache[url]

            item.configure(
                with: url,
                evaluation: evaluation,
                thumbnail: thumbnail,
                isSelected: selection.wrappedValue.contains(url),
                onThumbnailLoaded: onThumbnailLoaded
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
            var selectedURLs = Set<URL>()

            for indexPath in selectedIndexPaths {
                if indexPath.item < imageURLs.count {
                    selectedURLs.insert(imageURLs[indexPath.item])
                }
            }

            selection.wrappedValue = selectedURLs
        }

        // Handle double-click
        func collectionView(_ collectionView: NSCollectionView, didDoubleClickAt indexPath: IndexPath) {
            if indexPath.item < imageURLs.count {
                let url = imageURLs[indexPath.item]
                onDoubleClick(existingEvaluations[url])
            }
        }
    }
}

// MARK: - Custom Collection View Item for Folder Images

class FolderImageCollectionViewItem: NSCollectionViewItem {
    private var thumbnailImageView: NSImageView!
    private var titleLabel: NSTextField!
    private var scoreLabel: NSTextField!
    private var statusBadge: NSTextField!
    private var selectionOverlay: NSView!
    private var currentURL: URL?
    private var onThumbnailLoaded: ((URL, NSImage) -> Void)?

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

        // Status badge (evaluated/not evaluated)
        statusBadge = NSTextField(labelWithString: "")
        statusBadge.frame = NSRect(x: 135, y: 160, width: 35, height: 15)
        statusBadge.alignment = .center
        statusBadge.font = .systemFont(ofSize: 9, weight: .medium)
        statusBadge.backgroundColor = NSColor.controlAccentColor
        statusBadge.textColor = .white
        statusBadge.isBordered = false
        statusBadge.wantsLayer = true
        statusBadge.layer?.cornerRadius = 7.5
        statusBadge.layer?.masksToBounds = true
        statusBadge.isHidden = true
        view.addSubview(statusBadge)

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

    func configure(with url: URL,
                  evaluation: ImageEvaluation?,
                  thumbnail: NSImage?,
                  isSelected: Bool,
                  onThumbnailLoaded: @escaping (URL, NSImage) -> Void) {
        self.currentURL = url
        self.onThumbnailLoaded = onThumbnailLoaded

        // Set filename
        titleLabel.stringValue = url.lastPathComponent

        // Load thumbnail
        if let thumbnail = thumbnail {
            thumbnailImageView.image = thumbnail
        } else {
            // Load thumbnail asynchronously
            loadThumbnail(for: url)
        }

        // Show evaluation status
        if let eval = evaluation {
            if let score = eval.currentEvaluation?.overallWeightedScore {
                scoreLabel.stringValue = String(format: "Score: %.1f", score)
                scoreLabel.isHidden = false
                statusBadge.stringValue = "✓"
                statusBadge.backgroundColor = NSColor.systemGreen
            } else {
                scoreLabel.isHidden = true
                statusBadge.stringValue = "!"
                statusBadge.backgroundColor = NSColor.systemOrange
            }
            statusBadge.isHidden = false
        } else {
            scoreLabel.isHidden = true
            statusBadge.isHidden = true
        }

        // Update selection state
        self.isSelected = isSelected
    }

    private func loadThumbnail(for url: URL) {
        Task { @MainActor in
            guard let image = NSImage(contentsOf: url) else { return }

            // Create thumbnail
            let targetSize = NSSize(width: 175, height: 140)
            let thumbnail = NSImage(size: targetSize)

            thumbnail.lockFocus()
            image.draw(in: NSRect(origin: .zero, size: targetSize),
                      from: NSRect(origin: .zero, size: image.size),
                      operation: .copy,
                      fraction: 1.0)
            thumbnail.unlockFocus()

            thumbnailImageView.image = thumbnail

            // Notify parent to cache the thumbnail
            if let currentURL = self.currentURL {
                onThumbnailLoaded?(currentURL, thumbnail)
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImageView.image = nil
        titleLabel.stringValue = ""
        scoreLabel.stringValue = ""
        scoreLabel.isHidden = true
        statusBadge.isHidden = true
        selectionOverlay.isHidden = true
        currentURL = nil
        onThumbnailLoaded = nil
    }

    override func mouseDown(with event: NSEvent) {
        // Let the collection view handle selection
        super.mouseDown(with: event)

        // Check for double-click
        if event.clickCount == 2 {
            if let collectionView = self.collectionView,
               let indexPath = collectionView.indexPath(for: self),
               let coordinator = collectionView.delegate as? NativeFolderCollectionView.Coordinator {
                coordinator.collectionView(collectionView, didDoubleClickAt: indexPath)
            }
        }
    }
}