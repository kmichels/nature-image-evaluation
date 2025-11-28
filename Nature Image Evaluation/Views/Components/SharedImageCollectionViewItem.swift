//
//  SharedImageCollectionViewItem.swift
//  Nature Image Evaluation
//
//  Created by Claude on 11/27/25.
//  Shared collection view item for consistent display across all gallery views
//

import AppKit
import CoreData

/// Shared collection view item used by all gallery views for consistent display
class SharedImageCollectionViewItem: NSCollectionViewItem {
    // MARK: - UI Components
    private var thumbnailImageView: NSImageView!
    private var titleLabel: NSTextField!
    private var placementLabel: NSTextField!  // Shows PORTFOLIO/STORE/BOTH
    private var commercialScoreLabel: NSTextField!
    private var artisticScoreLabel: NSTextField!
    private var statusIndicator: NSProgressIndicator!
    private var selectionOverlay: NSView!
    private var statusBadge: NSTextField!  // For evaluated/not evaluated status

    // MARK: - Data
    private var currentImageURL: URL?
    private var currentImageEvaluation: ImageEvaluation?

    // MARK: - Configuration
    struct Configuration {
        let imageURL: URL?
        let imageEvaluation: ImageEvaluation?
        let evaluationResult: EvaluationResult?
        let thumbnail: NSImage?
        let filename: String
        let isProcessing: Bool
        let isInQueue: Bool
        let isSelected: Bool
    }

    // MARK: - Initialization
    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - View Lifecycle
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 175, height: 200))
        view.wantsLayer = true
        setupSubviews()
    }

    private func setupSubviews() {
        // Thumbnail image (main area)
        thumbnailImageView = NSImageView(frame: NSRect(x: 0, y: 40, width: 175, height: 140))
        thumbnailImageView.imageScaling = .scaleProportionallyUpOrDown
        thumbnailImageView.wantsLayer = true
        thumbnailImageView.layer?.cornerRadius = 8
        thumbnailImageView.layer?.masksToBounds = true
        thumbnailImageView.layer?.borderWidth = 1
        thumbnailImageView.layer?.borderColor = NSColor.separatorColor.cgColor
        view.addSubview(thumbnailImageView)

        // Title label (filename)
        titleLabel = NSTextField(labelWithString: "")
        titleLabel.frame = NSRect(x: 0, y: 22, width: 175, height: 18)
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.font = .systemFont(ofSize: 10)
        view.addSubview(titleLabel)

        // Commercial score label (left side)
        commercialScoreLabel = NSTextField(labelWithString: "")
        commercialScoreLabel.frame = NSRect(x: 5, y: 4, width: 55, height: 16)
        commercialScoreLabel.alignment = .left
        commercialScoreLabel.font = .systemFont(ofSize: 9, weight: .semibold)
        commercialScoreLabel.textColor = .secondaryLabelColor
        view.addSubview(commercialScoreLabel)

        // Artistic score label (right side)
        artisticScoreLabel = NSTextField(labelWithString: "")
        artisticScoreLabel.frame = NSRect(x: 115, y: 4, width: 55, height: 16)
        artisticScoreLabel.alignment = .right
        artisticScoreLabel.font = .systemFont(ofSize: 9, weight: .semibold)
        artisticScoreLabel.textColor = .secondaryLabelColor
        view.addSubview(artisticScoreLabel)

        // Placement label (center, below scores)
        placementLabel = NSTextField(labelWithString: "")
        placementLabel.frame = NSRect(x: 60, y: 4, width: 55, height: 16)
        placementLabel.alignment = .center
        placementLabel.font = .systemFont(ofSize: 8)
        placementLabel.textColor = .tertiaryLabelColor
        view.addSubview(placementLabel)

        // Status indicator (for processing)
        statusIndicator = NSProgressIndicator(frame: NSRect(x: 77, y: 100, width: 20, height: 20))
        statusIndicator.style = .spinning
        statusIndicator.isDisplayedWhenStopped = false
        statusIndicator.controlSize = .small
        view.addSubview(statusIndicator)

        // Status badge (for folder view - evaluated/not evaluated)
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

    // MARK: - Configuration
    func configure(with config: Configuration) {
        // Store current data
        currentImageURL = config.imageURL
        currentImageEvaluation = config.imageEvaluation

        // Set filename
        titleLabel.stringValue = config.filename

        // Set thumbnail
        if let thumbnail = config.thumbnail {
            thumbnailImageView.image = thumbnail
        } else {
            thumbnailImageView.image = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
        }

        // Handle processing state
        if config.isProcessing {
            statusIndicator.startAnimation(nil)
            hideAllScores()
        } else {
            statusIndicator.stopAnimation(nil)

            // Set scores and placement if available
            if let evalResult = config.evaluationResult {
                displayScores(evalResult)
            } else {
                hideAllScores()

                // Show status badge for folder items without evaluation
                if config.imageEvaluation != nil {
                    // Image is in database but not evaluated
                    statusBadge.stringValue = "!"
                    statusBadge.backgroundColor = NSColor.systemOrange
                    statusBadge.isHidden = false
                }
            }
        }

        // Update selection state
        self.isSelected = config.isSelected
    }

    private func displayScores(_ evalResult: EvaluationResult) {
        let commercialScore = evalResult.sellabilityScore
        let artisticScore = evalResult.artisticScore
        let placement = evalResult.primaryPlacement ?? "UNKNOWN"

        // Commercial score (Store)
        commercialScoreLabel.stringValue = String(format: "Store: %.1f", commercialScore)
        commercialScoreLabel.textColor = colorForScore(commercialScore)
        commercialScoreLabel.isHidden = false

        // Artistic score (Portfolio)
        artisticScoreLabel.stringValue = String(format: "Art: %.1f", artisticScore)
        artisticScoreLabel.textColor = colorForScore(artisticScore)
        artisticScoreLabel.isHidden = false

        // Placement label
        placementLabel.stringValue = placement
        placementLabel.textColor = .tertiaryLabelColor
        placementLabel.isHidden = false

        // Status badge (for folder view)
        statusBadge.stringValue = "✓"
        statusBadge.backgroundColor = NSColor.systemGreen
        statusBadge.isHidden = false
    }

    private func hideAllScores() {
        commercialScoreLabel.isHidden = true
        artisticScoreLabel.isHidden = true
        placementLabel.isHidden = true
        statusBadge.isHidden = true
    }

    private func colorForScore(_ score: Double) -> NSColor {
        if score >= 8.0 {
            return .systemGreen
        } else if score >= 6.0 {
            return .systemYellow
        } else {
            return .systemRed
        }
    }

    // MARK: - Selection
    override var isSelected: Bool {
        didSet {
            selectionOverlay.isHidden = !isSelected
            thumbnailImageView.layer?.borderColor = isSelected ?
                NSColor.controlAccentColor.cgColor :
                NSColor.separatorColor.cgColor
            thumbnailImageView.layer?.borderWidth = isSelected ? 2 : 1
        }
    }

    // MARK: - Reuse
    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImageView.image = nil
        titleLabel.stringValue = ""
        hideAllScores()
        statusIndicator.stopAnimation(nil)
        selectionOverlay.isHidden = true
        currentImageURL = nil
        currentImageEvaluation = nil
    }

    // MARK: - Helpers
    func getImageURL() -> URL? {
        return currentImageURL
    }

    func getImageEvaluation() -> ImageEvaluation? {
        return currentImageEvaluation
    }
}