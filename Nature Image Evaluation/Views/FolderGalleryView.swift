//
//  FolderGalleryView.swift
//  Nature Image Evaluation
//
//  Created by Claude on 11/12/25.
//

import SwiftUI
import CoreData

struct FolderGalleryView: View {
    let folder: MonitoredFolder
    @Environment(\.managedObjectContext) private var viewContext

    // Core Data fetch for existing evaluations
    @FetchRequest private var existingEvaluations: FetchedResults<ImageEvaluation>

    @State private var folderImages: [URL] = []
    @State private var isLoadingImages = true
    @State private var loadError: Error?
    @State private var selectedImages: Set<URL> = []
    @State private var showingEvaluationSheet = false
    @State private var evaluationManager = EvaluationManager()
    @State private var folderURL: URL?  // Store resolved folder URL for security scope

    // Grid layout
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 20)
    ]

    init(folder: MonitoredFolder) {
        self.folder = folder
        // Fetch evaluations for this folder's images
        self._existingEvaluations = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \ImageEvaluation.dateAdded, ascending: false)],
            animation: .default
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("\(folderImages.count) images")
                    .foregroundStyle(.secondary)

                Spacer()

                if !selectedImages.isEmpty {
                    Text("\(selectedImages.count) selected")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }

                Button("Evaluate Selected") {
                    startEvaluation()
                }
                .disabled(selectedImages.isEmpty || evaluationManager.isProcessing)

                Button("Refresh") {
                    Task {
                        await loadFolderImages()
                    }
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Main content
            if isLoadingImages {
                ProgressView("Loading images...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = loadError {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundStyle(.red)
                    Text("Error loading folder")
                        .font(.title2)
                    Text(error.localizedDescription)
                        .foregroundStyle(.secondary)
                    Button("Try Again") {
                        Task {
                            await loadFolderImages()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if folderImages.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 60))
                        .foregroundStyle(.tertiary)
                    Text("No images in this folder")
                        .font(.title2)
                    Text(folder.name)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(folderImages, id: \.self) { imageURL in
                            FolderImageThumbnail(
                                url: imageURL,
                                isSelected: selectedImages.contains(imageURL),
                                existingEvaluation: existingEvaluation(for: imageURL)
                            ) {
                                toggleSelection(imageURL)
                            }
                        }
                    }
                    .padding()
                }
            }

            // Status bar for evaluation
            if evaluationManager.isProcessing {
                EvaluationStatusBar(manager: evaluationManager)
            }
        }
        .task {
            await loadFolderImages()
        }
        .onDisappear {
            // Stop accessing the security-scoped folder when view disappears
            folderURL?.stopAccessingSecurityScopedResource()
        }
        .sheet(isPresented: $showingEvaluationSheet) {
            @Bindable var manager = evaluationManager
            VStack(spacing: 20) {
                Text("Evaluating Images")
                    .font(.title2)
                    .fontWeight(.semibold)

                if manager.totalImages > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Progress:")
                            Text("\(manager.currentImageIndex) of \(manager.totalImages)")
                                .fontWeight(.semibold)
                        }

                        ProgressView(value: manager.currentProgress)
                            .progressViewStyle(LinearProgressViewStyle())

                        Text(manager.statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 300)
                }

                HStack(spacing: 12) {
                    if manager.successfulEvaluations > 0 {
                        Label("\(manager.successfulEvaluations) completed", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }

                    if manager.failedEvaluations > 0 {
                        Label("\(manager.failedEvaluations) failed", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
                .font(.caption)

                Button("Cancel") {
                    manager.cancelEvaluation()
                    showingEvaluationSheet = false
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(30)
            .frame(minWidth: 400)
        }
    }

    // MARK: - Helper Methods

    private func loadFolderImages() async {
        isLoadingImages = true
        loadError = nil

        do {
            // Resolve and store the folder URL with security scope
            let url = try folder.resolveURL()

            // Start accessing for the duration of this view
            guard url.startAccessingSecurityScopedResource() else {
                throw FolderError.accessDenied
            }

            // Store the URL so we can stop accessing later
            await MainActor.run {
                self.folderURL = url
            }

            let images = try FolderManager.shared.scanFolder(folder)
            await MainActor.run {
                folderImages = images
                isLoadingImages = false
            }
        } catch {
            await MainActor.run {
                loadError = error
                isLoadingImages = false
            }
        }
    }

    private func toggleSelection(_ url: URL) {
        if selectedImages.contains(url) {
            selectedImages.remove(url)
        } else {
            selectedImages.insert(url)
        }
    }

    private func existingEvaluation(for url: URL) -> ImageEvaluation? {
        // Find if this image has already been evaluated
        let filename = url.lastPathComponent
        return existingEvaluations.first { evaluation in
            if let bookmarkData = evaluation.originalFilePath,
               let data = Data(base64Encoded: bookmarkData) {
                var isStale = false
                if let evaluationURL = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale),
                   evaluationURL.lastPathComponent == filename {
                    return true
                }
            }
            return false
        }
    }

    private func startEvaluation() {
        guard !selectedImages.isEmpty else { return }

        // Create or find ImageEvaluation objects for selected images
        var evaluationsToProcess: [ImageEvaluation] = []

        for imageURL in selectedImages {
            // Check if we already have an evaluation for this image
            if let existing = existingEvaluation(for: imageURL) {
                evaluationsToProcess.append(existing)
            } else {
                // Create a new ImageEvaluation object
                let newEvaluation = ImageEvaluation(context: viewContext)
                newEvaluation.id = UUID()
                newEvaluation.dateAdded = Date()

                // Store the file path as a bookmark
                if let bookmarkData = try? imageURL.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                ) {
                    newEvaluation.originalFilePath = bookmarkData.base64EncodedString()
                }

                evaluationsToProcess.append(newEvaluation)
            }
        }

        // Save the new evaluations
        if viewContext.hasChanges {
            do {
                try viewContext.save()
            } catch {
                print("Error saving new evaluations: \(error)")
                return
            }
        }

        // Start evaluation with the selected images
        evaluationManager.evaluationQueue = evaluationsToProcess
        showingEvaluationSheet = true

        Task {
            do {
                try await evaluationManager.startEvaluation()
                await MainActor.run {
                    // Clear selection after evaluation
                    selectedImages.removeAll()
                    showingEvaluationSheet = false
                }
            } catch {
                print("Evaluation error: \(error)")
                await MainActor.run {
                    showingEvaluationSheet = false
                }
            }
        }
    }
}

// MARK: - Thumbnail View

struct FolderImageThumbnail: View {
    let url: URL
    let isSelected: Bool
    let existingEvaluation: ImageEvaluation?
    let onTap: () -> Void

    @State private var thumbnail: NSImage?

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topLeading) {
                // Image
                Group {
                    if let thumbnail = thumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .overlay(
                                ProgressView()
                                    .controlSize(.small)
                            )
                    }
                }
                .frame(width: 150, height: 150)
                .cornerRadius(8)

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white, .blue)
                        .background(Circle().fill(.black.opacity(0.5)))
                        .padding(8)
                }

                // Evaluation badge if exists
                if let evaluation = existingEvaluation,
                   let result = evaluation.currentEvaluation {
                    VStack(spacing: 2) {
                        HStack(spacing: 4) {
                            VStack(spacing: 1) {
                                Text("A")
                                    .font(.system(size: 8))
                                Text(String(format: "%.1f", result.artisticScore))
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .frame(width: 28)

                            Divider()
                                .frame(height: 20)

                            VStack(spacing: 1) {
                                Text("C")
                                    .font(.system(size: 8))
                                Text(String(format: "%.1f", result.sellabilityScore))
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .frame(width: 28)
                        }
                        .foregroundStyle(.white)
                    }
                    .padding(4)
                    .background(scoreColor(result.overallWeightedScore).opacity(0.9))
                    .cornerRadius(4)
                    .offset(x: 90, y: 110)
                }
            }

            // Filename
            Text(url.lastPathComponent)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(isSelected ? .blue : .primary)
        }
        .onTapGesture {
            onTap()
        }
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        // Try loading image - parent folder should have security scope
        var loadedImage: NSImage?

        if let image = NSImage(contentsOf: url) {
            loadedImage = image
        } else {
            // If regular loading fails, try with explicit security scope
            print("Failed initial load, trying with security scope: \(url.lastPathComponent)")
            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to access image for thumbnail: \(url.lastPathComponent)")
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            loadedImage = NSImage(contentsOf: url)
            if loadedImage == nil {
                print("Still failed to load image: \(url.lastPathComponent)")
                return
            }
        }

        guard let image = loadedImage else { return }

        // Create thumbnail
        let targetSize = NSSize(width: 150, height: 150)
        let thumbnailImage = NSImage(size: targetSize)
        thumbnailImage.lockFocus()

        // Calculate aspect-fit rect
        let imageSize = image.size
        let scale = min(targetSize.width / imageSize.width, targetSize.height / imageSize.height)
        let scaledSize = NSSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let drawRect = NSRect(
            x: (targetSize.width - scaledSize.width) / 2,
            y: (targetSize.height - scaledSize.height) / 2,
            width: scaledSize.width,
            height: scaledSize.height
        )

        image.draw(in: drawRect,
                  from: NSRect(origin: .zero, size: imageSize),
                  operation: .copy,
                  fraction: 1.0)
        thumbnailImage.unlockFocus()

        await MainActor.run {
            self.thumbnail = thumbnailImage
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 8...: return .green
        case 6..<8: return .blue
        case 4..<6: return .orange
        default: return .red
        }
    }
}