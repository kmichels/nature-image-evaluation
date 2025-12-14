//
//  ImageListView.swift
//  Nature Image Evaluation
//
//  Created on December 2025 during UI rebuild
//  List/table layout using SwiftUI Table - simplified version
//

import SwiftUI

struct ImageListView: View {
    @Bindable var viewModel: BrowserViewModel
    @Environment(EvaluationManager.self) private var evaluationManager

    var body: some View {
        // Simple list for now - Table was too complex
        List(viewModel.displayedURLs, id: \.self, selection: $viewModel.selectedURLs) { url in
            ImageListRow(url: url, viewModel: viewModel)
                .contextMenu {
                    contextMenuItems(for: url)
                }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    // MARK: - Context Menus

    @ViewBuilder
    private func contextMenuItems(for url: URL) -> some View {
        Button("Show in Finder") {
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
        }

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

// MARK: - List Row

struct ImageListRow: View {
    let url: URL
    let viewModel: BrowserViewModel

    @State private var thumbnail: NSImage?
    @State private var fileSize: String = ""
    @State private var modifiedDate: Date = Date()

    // Computed evaluation properties
    private var evaluationScore: Double? {
        viewModel.getEvaluationScore(for: url)
    }

    private var evaluationPlacement: String? {
        viewModel.getEvaluationPlacement(for: url)
    }

    private var scoreColor: Color {
        guard let score = evaluationScore else { return .gray }
        switch score {
        case 8.0...: return .green
        case 6.0..<8.0: return .blue
        case 4.0..<6.0: return .orange
        default: return .red
        }
    }

    private var placementIcon: String {
        switch evaluationPlacement {
        case "PORTFOLIO": return "star.fill"
        case "STORE": return "cart.fill"
        case "BOTH": return "star.circle.fill"
        case "ARCHIVE": return "archivebox.fill"
        default: return "questionmark.circle"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            Group {
                if let thumbnail = thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "photo")
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 40, height: 40)

            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(fileSize)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(modifiedDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Evaluation score and placement
            if let score = evaluationScore {
                HStack(spacing: 8) {
                    if let placement = evaluationPlacement {
                        HStack(spacing: 4) {
                            Image(systemName: placementIcon)
                                .font(.caption)
                            Text(placement)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }

                    Text(String(format: "%.1f", score))
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(scoreColor))
                }
            }
        }
        .padding(.vertical, 4)
        .task {
            await loadFileInfo()
            await loadThumbnail()
        }
    }

    private func loadFileInfo() async {
        do {
            let resources = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            if let size = resources.fileSize {
                fileSize = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
            }
            if let date = resources.contentModificationDate {
                modifiedDate = date
            }
        } catch {
            // Ignore errors
        }
    }

    private func loadThumbnail() async {
        // Check cache first
        if let cached = viewModel.thumbnail(for: url) {
            thumbnail = cached
            return
        }

        // Load thumbnail asynchronously
        await Task.detached(priority: .userInitiated) {
            guard let image = NSImage(contentsOf: url) else { return }

            // Create small thumbnail
            let targetSize = NSSize(width: 80, height: 80)
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