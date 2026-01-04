//
//  ImageGridView.swift
//  Nature Image Evaluation
//
//  Created on December 2025 during UI rebuild
//  Grid layout using LazyVGrid - testing for hit-testing issues
//

import SwiftUI

struct ImageGridView: View {
    @Bindable var viewModel: BrowserViewModel
    @FocusState private var isFocused: Bool

    private var columns: [GridItem] {
        Array(repeating: GridItem(.fixed(viewModel.thumbnailSize), spacing: 20),
              count: numberOfColumns)
    }

    private var numberOfColumns: Int {
        // Calculate based on available width
        // This is a simple calculation - can be made dynamic
        let availableWidth: CGFloat = 1000 // Will be dynamic based on geometry reader
        let itemTotalWidth = viewModel.thumbnailSize + 20
        return max(1, Int(availableWidth / itemTotalWidth))
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVGrid(columns: adaptiveColumns(for: geometry.size.width), spacing: 20) {
                    ForEach(viewModel.displayedURLs, id: \.self) { url in
                        BrowserImageThumbnail(
                            url: url,
                            size: viewModel.thumbnailSize,
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
                .padding(20)
            }
            .background(Color(NSColor.windowBackgroundColor))
            .focusable()
            .focused($isFocused)
            .onKeyPress(phases: .down) { press in
                handleKeyPress(press)
            }
        }
    }

    // MARK: - Dynamic Columns

    private func adaptiveColumns(for width: CGFloat) -> [GridItem] {
        let itemTotalWidth = viewModel.thumbnailSize + 20
        let count = max(1, Int(width / itemTotalWidth))
        return Array(repeating: GridItem(.fixed(viewModel.thumbnailSize), spacing: 20), count: count)
    }

    // MARK: - Interaction Handlers

    private func handleTap(on url: URL) {
        // Get current event modifiers
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
        // Double-tap opens the image in Quick Look / preview
        NSWorkspace.shared.open(url)
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
        default:
            return .ignored
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuItems(for url: URL) -> some View {
        Button("Show in Finder") {
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
        }

        Button("Get Info") {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }

        Divider()

        Button("Evaluate") {
            // Evaluation is triggered from the main browser view
        }
        .disabled(true)

        if viewModel.selectedURLs.count > 1 {
            Divider()
            Text("\\(viewModel.selectedURLs.count) items selected")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Thumbnail View

struct BrowserImageThumbnail: View {
    let url: URL
    let size: CGFloat
    let isSelected: Bool
    let viewModel: BrowserViewModel

    @State private var thumbnail: NSImage?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(borderColor, lineWidth: borderWidth)
                )

            // Content
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(4)
            } else if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: size * 0.3))
                    .foregroundColor(.secondary)
            }

            // Selection overlay
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.3))
                    .allowsHitTesting(false)
            }

            // Evaluation indicator (placeholder)
            // This will show evaluation status once integrated
        }
        .frame(width: size, height: size)
        .task {
            await loadThumbnail()
        }
    }

    private var borderColor: Color {
        isSelected ? Color.accentColor : Color(NSColor.separatorColor)
    }

    private var borderWidth: CGFloat {
        isSelected ? 2 : 1
    }

    private func loadThumbnail() async {
        // Check cache first
        if let cached = viewModel.thumbnail(for: url) {
            thumbnail = cached
            return
        }

        isLoading = true
        defer { isLoading = false }

        // Load thumbnail asynchronously
        await Task.detached(priority: .userInitiated) {
            guard let image = NSImage(contentsOf: url) else {
                return
            }

            // Create thumbnail
            let targetSize = NSSize(width: size * 2, height: size * 2) // 2x for retina
            let thumbnail = NSImage(size: targetSize)

            thumbnail.lockFocus()
            image.draw(in: NSRect(origin: .zero, size: targetSize),
                       from: NSRect(origin: .zero, size: image.size),
                       operation: .copy,
                       fraction: 1.0)
            thumbnail.unlockFocus()

            await MainActor.run {
                self.thumbnail = thumbnail
                viewModel.cacheThumbnail(thumbnail, for: url)
            }
        }.value
    }
}
