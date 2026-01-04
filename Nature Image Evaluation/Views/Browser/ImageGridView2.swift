//
//  ImageGridView2.swift
//  Nature Image Evaluation
//
//  Polished grid layout with better visual feedback
//

import SwiftUI

struct ImageGridView2: View {
    @Bindable var viewModel: BrowserViewModel
    @Environment(EvaluationManager.self) private var evaluationManager
    @FocusState private var isFocused: Bool

    // Layout configuration for floating UI
    var sidebarWidth: CGFloat = 0
    private let toolbarHeight: CGFloat = 36 // Height for toolbar pills area (close to top)

    // Detail view state
    @State private var showingDetail = false
    @State private var detailURL: URL?

    private let columnCount = 5
    private let spacing: CGFloat = 8
    private let padding: CGFloat = 16

    var body: some View {
        GeometryReader { geometry in
            // Calculate available width accounting for floating sidebar
            let availableWidth = geometry.size.width - sidebarWidth
            let thumbnailSize = calculateThumbnailSize(for: availableWidth)

            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(thumbnailSize), spacing: spacing), count: columnCount),
                    spacing: spacing
                ) {
                    ForEach(viewModel.displayedURLs, id: \.self) { url in
                        LetterboxThumbnail(
                            url: url,
                            size: thumbnailSize,
                            isSelected: viewModel.selectedURLs.contains(url),
                            viewModel: viewModel
                        )
                        .onTapGesture {
                            handleTap(on: url)
                        }
                        .simultaneousGesture(
                            TapGesture(count: 2).onEnded {
                                handleDoubleTap(on: url)
                            }
                        )
                        .contextMenu {
                            contextMenuItems(for: url)
                        }
                    }
                }
                .padding(.top, toolbarHeight + padding) // Clear floating toolbar
                .padding(.leading, sidebarWidth + padding) // Clear floating sidebar
                .padding(.trailing, padding)
                .padding(.bottom, padding)
            }
            .focusable()
            .focused($isFocused)
            .onKeyPress(phases: .down) { press in
                handleKeyPress(press)
            }
        }
        .sheet(isPresented: $showingDetail) {
            if let url = detailURL {
                EvaluationDetailView(
                    url: url,
                    evaluation: viewModel.getEvaluation(for: url)
                )
            }
        }
    }

    // MARK: - Layout Calculation

    private func calculateThumbnailSize(for width: CGFloat) -> CGFloat {
        // Available width = total width - left padding - right padding
        let availableWidth = width - (padding * 2)
        // Total spacing between columns
        let totalSpacing = spacing * CGFloat(columnCount - 1)
        // Size per thumbnail
        let size = (availableWidth - totalSpacing) / CGFloat(columnCount)
        return max(80, size) // Minimum size of 80
    }

    // MARK: - Interaction Handlers

    private func handleTap(on url: URL) {
        let modifiers = NSEvent.modifierFlags
        var swiftUIModifiers = EventModifiers()

        if modifiers.contains(.command) {
            swiftUIModifiers.insert(.command)
        }
        if modifiers.contains(.shift) {
            swiftUIModifiers.insert(.shift)
        }

        viewModel.handleSelection(of: url, modifiers: swiftUIModifiers)
    }

    private func handleDoubleTap(on url: URL) {
        // Show evaluation detail view
        detailURL = url
        showingDetail = true
    }

    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .upArrow:
            viewModel.navigateSelection(direction: .up)
            return .handled
        case .downArrow:
            viewModel.navigateSelection(direction: .down)
            return .handled
        case .leftArrow:
            viewModel.navigateSelection(direction: .left)
            return .handled
        case .rightArrow:
            viewModel.navigateSelection(direction: .right)
            return .handled
        case "a" where press.modifiers.contains(.command):
            viewModel.selectAll()
            return .handled
        case .escape:
            viewModel.deselectAll()
            return .handled
        case .space:
            // Preview selected items
            if let first = viewModel.selectedURLs.first {
                NSWorkspace.shared.open(first)
            }
            return .handled
        default:
            return .ignored
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuItems(for url: URL) -> some View {
        Button("View Details") {
            detailURL = url
            showingDetail = true
        }

        Button("Open in Preview") {
            NSWorkspace.shared.open(url)
        }

        Button("Show in Finder") {
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
        }

        Divider()

        Button("Get Info") {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }

        Divider()

        // Show evaluation status or evaluate option
        if let score = viewModel.getEvaluationScore(for: url) {
            let placement = viewModel.getEvaluationPlacement(for: url) ?? "Unknown"
            Text("Score: \(String(format: "%.1f", score)) - \(placement)")
                .font(.caption)

            Button("Re-evaluate with AI") {
                evaluateImages([url])
            }
            .disabled(evaluationManager.isProcessing)
        } else {
            Button("Evaluate with AI") {
                evaluateImages([url])
            }
            .disabled(evaluationManager.isProcessing)
        }

        if viewModel.selectedURLs.count > 1 {
            Divider()

            Button("Evaluate All Selected (\(viewModel.selectedURLs.count))") {
                evaluateImages(Array(viewModel.selectedURLs))
            }
            .disabled(evaluationManager.isProcessing)

            Text("\(viewModel.selectedURLs.count) items selected")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Evaluation

    private func evaluateImages(_ urls: [URL]) {
        Task {
            await evaluationManager.addImages(urls: urls)
            do {
                try await evaluationManager.startEvaluation()
                viewModel.refreshEvaluationCache()
            } catch {
                print("Evaluation error: \(error)")
            }
        }
    }
}

// MARK: - Letterbox Thumbnail (Apple Photos style)

struct LetterboxThumbnail: View {
    let url: URL
    let size: CGFloat
    let isSelected: Bool
    let viewModel: BrowserViewModel

    @State private var thumbnail: NSImage?
    @State private var isLoading = true
    @State private var isHovered = false

    // Computed evaluation properties
    private var artisticScore: Double? {
        viewModel.getArtisticScore(for: url)
    }

    private var commercialScore: Double? {
        viewModel.getCommercialScore(for: url)
    }

    private var hasEvaluation: Bool {
        artisticScore != nil || commercialScore != nil
    }

    var body: some View {
        VStack(spacing: 4) {
            // Fixed square container with letterboxed image
            ZStack {
                // Dark background for letterboxing
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.darkGray).opacity(0.3))

                // Image scaled to fit (letterboxed)
                if let thumbnail = thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else if isLoading {
                    Image(systemName: "photo")
                        .font(.system(size: size * 0.15))
                        .foregroundColor(Color(NSColor.tertiaryLabelColor))
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: size * 0.2))
                        .foregroundColor(Color(NSColor.tertiaryLabelColor))
                }

                // Selection overlay
                if isSelected {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.accentColor, lineWidth: 3)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentColor.opacity(0.15))
                        )

                    // Checkmark badge (top-right)
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                                .background(
                                    Circle()
                                        .fill(Color.accentColor)
                                        .frame(width: 20, height: 20)
                                )
                                .padding(4)
                        }
                        Spacer()
                    }
                }

                // Evaluation score badges (bottom-left)
                if hasEvaluation {
                    VStack {
                        Spacer()
                        HStack(spacing: 3) {
                            if let artistic = artisticScore {
                                HStack(spacing: 2) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 7))
                                    Text(String(format: "%.1f", artistic))
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(scoreColor(artistic)))
                            }

                            if let commercial = commercialScore {
                                HStack(spacing: 2) {
                                    Image(systemName: "cart.fill")
                                        .font(.system(size: 7))
                                    Text(String(format: "%.1f", commercial))
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(scoreColor(commercial)))
                            }

                            Spacer()
                        }
                        .padding(4)
                    }
                }
            }
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(isHovered ? 0.25 : 0.1), radius: isHovered ? 6 : 3, y: 2)
            .scaleEffect(isHovered && !isSelected ? 1.03 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .animation(.easeInOut(duration: 0.15), value: isSelected)

            // Filename
            Text(url.lastPathComponent)
                .font(.caption2)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(width: size)
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        if let cached = viewModel.thumbnail(for: url) {
            thumbnail = cached
            isLoading = false
            return
        }

        isLoading = true

        await Task.detached(priority: .userInitiated) {
            guard let image = NSImage(contentsOf: url) else {
                await MainActor.run { self.isLoading = false }
                return
            }

            // Create square thumbnail at 2x for retina
            let targetSize = NSSize(width: size * 2, height: size * 2)
            let thumb = NSImage(size: targetSize)

            thumb.lockFocus()
            NSGraphicsContext.current?.imageInterpolation = .high

            // Calculate letterbox positioning
            let imageAspect = image.size.width / image.size.height
            var drawRect: NSRect

            if imageAspect > 1 {
                // Landscape - letterbox top/bottom
                let drawHeight = targetSize.width / imageAspect
                let yOffset = (targetSize.height - drawHeight) / 2
                drawRect = NSRect(x: 0, y: yOffset, width: targetSize.width, height: drawHeight)
            } else {
                // Portrait - letterbox left/right
                let drawWidth = targetSize.height * imageAspect
                let xOffset = (targetSize.width - drawWidth) / 2
                drawRect = NSRect(x: xOffset, y: 0, width: drawWidth, height: targetSize.height)
            }

            image.draw(in: drawRect, from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1.0)
            thumb.unlockFocus()

            await MainActor.run {
                self.thumbnail = thumb
                self.isLoading = false
                viewModel.cacheThumbnail(thumb, for: url)
            }
        }.value
    }
}
