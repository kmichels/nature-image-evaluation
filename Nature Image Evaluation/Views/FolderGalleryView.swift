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
    @State private var evaluationCompletedCount = 0  // Trigger view refresh
    @State private var detailViewImage: ImageEvaluation?  // For showing detail view

    // Grid layout
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 20)
    ]

    init(folder: MonitoredFolder) {
        self.folder = folder
        // Fetch all evaluations - we'll match them by filename
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
                                existingEvaluation: existingEvaluation(for: imageURL),
                                onTap: {
                                    toggleSelection(imageURL)
                                },
                                onDoubleTap: {
                                    if let evaluation = existingEvaluation(for: imageURL) {
                                        showDetailView(evaluation)
                                    }
                                }
                            )
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
        .sheet(item: $detailViewImage) { image in
            ImageDetailView(evaluation: image)
                .environment(\.managedObjectContext, viewContext)
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

    private func showDetailView(_ evaluation: ImageEvaluation) {
        detailViewImage = evaluation
    }

    private func existingEvaluation(for url: URL) -> ImageEvaluation? {
        // Use evaluationCompletedCount to force refresh when evaluations complete
        _ = evaluationCompletedCount

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

        showingEvaluationSheet = true

        Task {
            // Create or find ImageEvaluation objects for selected images
            var evaluationsToProcess: [ImageEvaluation] = []

            for imageURL in selectedImages {
                // Check if we already have an evaluation for this image
                if let existing = existingEvaluation(for: imageURL) {
                    // If it already has a processed file, we can re-evaluate
                    if existing.processedFilePath != nil {
                        evaluationsToProcess.append(existing)
                    } else {
                        // Need to process the image first
                        if let processed = await processImage(from: imageURL, for: existing) {
                            evaluationsToProcess.append(processed)
                        }
                    }
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

                    // Process the image
                    if let processed = await processImage(from: imageURL, for: newEvaluation) {
                        evaluationsToProcess.append(processed)
                    }
                }
            }

            // Save the new evaluations
            if viewContext.hasChanges {
                do {
                    try viewContext.save()
                } catch {
                    print("Error saving new evaluations: \(error)")
                    await MainActor.run {
                        showingEvaluationSheet = false
                    }
                    return
                }
            }

            // Start evaluation with the selected images
            await MainActor.run {
                evaluationManager.evaluationQueue = evaluationsToProcess
            }

            do {
                try await evaluationManager.startEvaluation()

                // Force Core Data to save
                if viewContext.hasChanges {
                    try? viewContext.save()
                }

                await MainActor.run {
                    // Clear selection after evaluation
                    selectedImages.removeAll()
                    showingEvaluationSheet = false
                    // Trigger view refresh
                    evaluationCompletedCount += 1
                }
            } catch {
                print("Evaluation error: \(error)")
                await MainActor.run {
                    showingEvaluationSheet = false
                }
            }
        }
    }

    private func processImage(from url: URL, for evaluation: ImageEvaluation) async -> ImageEvaluation? {
        // Note: The parent folder already has security scope access, so we don't need it for individual files
        guard let image = NSImage(contentsOf: url) else {
            print("Failed to load image for processing: \(url.lastPathComponent)")
            return nil
        }

        // Get original dimensions
        if let rep = image.representations.first {
            evaluation.originalWidth = Int32(rep.pixelsWide)
            evaluation.originalHeight = Int32(rep.pixelsHigh)
        }

        // Resize image for evaluation
        let processor = ImageProcessor.shared
        guard let resized = processor.resizeForEvaluation(image: image) else {
            print("Failed to resize image: \(url.lastPathComponent)")
            return nil
        }

        // Generate unique path for processed image
        let processedURL = getProcessedImageURL(for: evaluation.id ?? UUID())

        do {
            // Save processed image
            let fileSize = try processor.saveProcessedImage(resized, to: processedURL)
            evaluation.processedFilePath = processedURL.path
            evaluation.fileSize = fileSize

            // Get processed dimensions
            if let rep = resized.representations.first {
                evaluation.processedWidth = Int32(rep.pixelsWide)
                evaluation.processedHeight = Int32(rep.pixelsHigh)
            }

            return evaluation
        } catch {
            print("Error saving processed image: \(error)")
            return nil
        }
    }

    private func getProcessedImageURL(for id: UUID) -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("Nature Image Evaluation")
        let processedFolder = appFolder.appendingPathComponent("ProcessedImages")
        let imageFolder = processedFolder.appendingPathComponent(id.uuidString)

        // Create directories if needed
        try? FileManager.default.createDirectory(at: imageFolder, withIntermediateDirectories: true)

        return imageFolder.appendingPathComponent("processed.jpg")
    }
}

// MARK: - Thumbnail View

struct FolderImageThumbnail: View {
    let url: URL
    let isSelected: Bool
    let existingEvaluation: ImageEvaluation?
    let onTap: () -> Void
    let onDoubleTap: () -> Void

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
        .onTapGesture(count: 2) {
            onDoubleTap()
        }
        .onTapGesture(count: 1) {
            onTap()
        }
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        // Load image - parent folder already has security scope
        guard let image = NSImage(contentsOf: url) else {
            print("Failed to load image for thumbnail: \(url.lastPathComponent)")
            return
        }

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