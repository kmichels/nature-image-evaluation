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
    @State private var sortOption: SortOption = .name
    @State private var filterOption: FilterOption = .all
    @State private var cachedFilteredImages: [URL] = []  // Cache sorted/filtered results
    @State private var thumbnailCache: [URL: NSImage] = [:]  // Cache thumbnails
    @State private var showOnlySelected = false  // Toggle to show only selected images

    // Grid layout
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 20)
    ]

    enum SortOption: String, CaseIterable {
        case name = "Name"
        case dateModified = "Date Modified"
        case overallScore = "Overall Score"
        case sellability = "Sellability"
        case artisticScore = "Artistic Score"
    }

    enum FilterOption: String, CaseIterable {
        case all = "All Images"
        case evaluated = "Evaluated"
        case notEvaluated = "Not Evaluated"
        case portfolio = "Portfolio"
        case store = "Store"
        case both = "Both (Portfolio & Store)"
    }

    init(folder: MonitoredFolder) {
        self.folder = folder
        // Fetch all evaluations - we'll match them by filename
        self._existingEvaluations = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \ImageEvaluation.dateAdded, ascending: false)],
            animation: .default
        )
    }

    // MARK: - Computed Properties

    private func updateFilteredImages() {
        // Build evaluation cache once to avoid repeated lookups
        var evaluationCache: [URL: ImageEvaluation?] = [:]
        for url in folderImages {
            evaluationCache[url] = existingEvaluation(for: url)
        }

        // First, apply selection filter if enabled
        let baseImages = showOnlySelected ? Array(selectedImages) : folderImages

        // Then, filter the images
        let filtered = baseImages.filter { url in
            let evaluation = evaluationCache[url] ?? nil

            switch filterOption {
            case .all:
                return true
            case .evaluated:
                return evaluation?.currentEvaluation != nil
            case .notEvaluated:
                return evaluation == nil || evaluation?.currentEvaluation == nil
            case .portfolio:
                return evaluation?.currentEvaluation?.primaryPlacement == "PORTFOLIO"
            case .store:
                return evaluation?.currentEvaluation?.primaryPlacement == "STORE"
            case .both:
                return evaluation?.currentEvaluation?.primaryPlacement == "BOTH"
            }
        }

        // Cache file dates if sorting by date to avoid repeated file system access
        var dateCache: [URL: Date] = [:]
        if sortOption == .dateModified {
            for url in filtered {
                dateCache[url] = (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date) ?? Date.distantPast
            }
        }

        // Then sort them
        cachedFilteredImages = filtered.sorted { url1, url2 in
            let eval1 = evaluationCache[url1] ?? nil
            let eval2 = evaluationCache[url2] ?? nil

            switch sortOption {
            case .name:
                return url1.lastPathComponent < url2.lastPathComponent
            case .dateModified:
                let date1 = dateCache[url1] ?? Date.distantPast
                let date2 = dateCache[url2] ?? Date.distantPast
                return date1 > date2
            case .overallScore:
                let score1 = eval1?.currentEvaluation?.overallWeightedScore ?? -1
                let score2 = eval2?.currentEvaluation?.overallWeightedScore ?? -1
                return score1 > score2
            case .sellability:
                let score1 = eval1?.currentEvaluation?.sellabilityScore ?? -1
                let score2 = eval2?.currentEvaluation?.sellabilityScore ?? -1
                return score1 > score2
            case .artisticScore:
                let score1 = eval1?.currentEvaluation?.artisticScore ?? -1
                let score2 = eval2?.currentEvaluation?.artisticScore ?? -1
                return score1 > score2
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 16) {
                Text("\(cachedFilteredImages.count) images")
                    .foregroundStyle(.secondary)

                Divider()
                    .frame(height: 20)

                // Filter and Sort
                Picker("Filter", selection: $filterOption) {
                    ForEach(FilterOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)

                Picker("Sort", selection: $sortOption) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)

                Spacer()

                if !selectedImages.isEmpty {
                    Text("\(selectedImages.count) selected")
                        .foregroundStyle(.secondary)
                        .font(.caption)

                    Button(action: {
                        showOnlySelected.toggle()
                        updateFilteredImages()
                    }) {
                        Label(showOnlySelected ? "Show All" : "Show Selected",
                              systemImage: showOnlySelected ? "rectangle.grid.2x2" : "checkmark.rectangle.stack")
                    }
                    .disabled(selectedImages.isEmpty)
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
            } else if cachedFilteredImages.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 60))
                        .foregroundStyle(.tertiary)
                    if folderImages.isEmpty {
                        Text("No images in this folder")
                            .font(.title2)
                        Text(folder.name)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No images match filter")
                            .font(.title2)
                        Text("Try changing the filter to see more images")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(cachedFilteredImages, id: \.self) { imageURL in
                            FolderImageThumbnail(
                                url: imageURL,
                                isSelected: selectedImages.contains(imageURL),
                                existingEvaluation: existingEvaluation(for: imageURL),
                                thumbnail: thumbnailCache[imageURL],
                                onTap: {
                                    toggleSelection(imageURL)
                                },
                                onDoubleTap: {
                                    if let evaluation = existingEvaluation(for: imageURL) {
                                        showDetailView(evaluation)
                                    }
                                },
                                onThumbnailLoaded: { image in
                                    thumbnailCache[imageURL] = image
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
        .onChange(of: sortOption) { _, _ in
            updateFilteredImages()
        }
        .onChange(of: filterOption) { _, _ in
            updateFilteredImages()
        }
        .onChange(of: evaluationCompletedCount) { _, _ in
            updateFilteredImages()
        }
        .onChange(of: selectedImages) { _, _ in
            // If no images selected, turn off selection filter
            if selectedImages.isEmpty && showOnlySelected {
                showOnlySelected = false
                updateFilteredImages()
            }
        }
        .onDisappear {
            // Stop accessing the security-scoped folder when view disappears
            folderURL?.stopAccessingSecurityScopedResource()
            // Clear thumbnail cache to free memory
            thumbnailCache.removeAll()
            // Reset selection filter
            showOnlySelected = false
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
                updateFilteredImages()
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
                    // Don't clear selection - let user see what was evaluated
                    // selectedImages.removeAll() -- removed to keep selection visible
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
    let thumbnail: NSImage?  // Passed from parent
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    let onThumbnailLoaded: ((NSImage) -> Void)?

    @State private var isLoadingThumbnail = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topLeading) {
                // Image
                Group {
                    if let thumbnail = thumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if isLoadingThumbnail {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .overlay(
                                ProgressView()
                                    .controlSize(.small)
                            )
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
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
            // Only load thumbnail if we don't have one cached
            if thumbnail == nil && !isLoadingThumbnail {
                await loadThumbnail()
            }
        }
    }

    private func loadThumbnail() async {
        await MainActor.run {
            isLoadingThumbnail = true
        }

        // Do all image processing off the main thread
        let thumbnailImage = await Task.detached(priority: .userInitiated) { () -> NSImage? in
            // Load image - parent folder already has security scope
            guard let image = NSImage(contentsOf: url) else {
                return nil
            }

            // Create thumbnail off main thread

            // Use CGImage for better performance
            var proposedRect = NSRect(origin: .zero, size: image.size)
            guard let cgImage = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
                return nil
            }

            let aspectRatio = Double(cgImage.width) / Double(cgImage.height)
            let targetWidth: Double
            let targetHeight: Double

            if aspectRatio > 1 {
                targetWidth = 150
                targetHeight = 150 / aspectRatio
            } else {
                targetWidth = 150 * aspectRatio
                targetHeight = 150
            }

            // Create thumbnail using Core Graphics (faster than NSImage drawing)
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

            guard let context = CGContext(
                data: nil,
                width: Int(targetWidth),
                height: Int(targetHeight),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
            ) else {
                return nil
            }

            context.interpolationQuality = .high
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

            guard let thumbnailCGImage = context.makeImage() else {
                return nil
            }

            return NSImage(cgImage: thumbnailCGImage, size: NSSize(width: targetWidth, height: targetHeight))
        }.value

        await MainActor.run {
            isLoadingThumbnail = false
            if let thumbnailImage = thumbnailImage {
                // Notify parent to cache this thumbnail
                onThumbnailLoaded?(thumbnailImage)
            }
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