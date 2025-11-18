//
//  GalleryView.swift
//  Nature Image Evaluation
//
//  Created by Claude Code on 10/28/25.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

/// Quick Analysis area for drag-and-drop image evaluation
/// Provides fast evaluation of images without organizing into folders
struct GalleryView: View {
    @Environment(\.managedObjectContext) private var viewContext

    // MARK: - Fetch Request

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \ImageEvaluation.dateAdded, ascending: false)
        ],
        animation: .default
    )
    private var imageEvaluations: FetchedResults<ImageEvaluation>

    // Initialize with batch fetching for performance
    init() {
        let request = ImageEvaluation.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ImageEvaluation.dateAdded, ascending: false)
        ]
        request.fetchBatchSize = 20 // Load in batches for better memory management
        request.returnsObjectsAsFaults = true // Don't load all properties immediately
        _imageEvaluations = FetchRequest(fetchRequest: request, animation: .default)
    }

    // MARK: - State

    @StateObject private var selectionManager = SelectionManager()
    @State private var isImporting = false
    @State private var isDragOver = false
    @State private var showingEvaluationSheet = false
    @State private var detailViewImage: ImageEvaluation?  // When non-nil, shows detail view
    @State private var searchText = ""
    @State private var sortOption: SortOption = .dateAdded
    @State private var filterOption: FilterOption = .all
    @State private var showingDeleteConfirmation = false
    @State private var showOnlySelected = false  // Toggle to show only selected images

    // Evaluation state
    @State private var evaluationManager = {
        let manager = EvaluationManager()
        // Load saved image resolution preference
        let savedResolution = UserDefaults.standard.integer(forKey: "imageResolution")
        if savedResolution > 0 {
            manager.imageResolution = savedResolution
        }
        // Load saved rate limiting preferences
        let savedDelay = UserDefaults.standard.double(forKey: "requestDelay")
        if savedDelay > 0 {
            manager.requestDelay = savedDelay
        }
        let savedBatchSize = UserDefaults.standard.integer(forKey: "maxBatchSize")
        if savedBatchSize > 0 {
            manager.maxBatchSize = savedBatchSize
        }
        return manager
    }()

    // Grid layout
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 20)
    ]

    enum SortOption: String, CaseIterable {
        case dateAdded = "Date Added"
        case dateEvaluated = "Date Evaluated"
        case overallScore = "Overall Score"
        case sellability = "Sellability"

        var sortDescriptor: NSSortDescriptor {
            switch self {
            case .dateAdded:
                return NSSortDescriptor(keyPath: \ImageEvaluation.dateAdded, ascending: false)
            case .dateEvaluated:
                return NSSortDescriptor(keyPath: \ImageEvaluation.dateLastEvaluated, ascending: false)
            case .overallScore:
                return NSSortDescriptor(keyPath: \ImageEvaluation.currentEvaluation?.overallWeightedScore, ascending: false)
            case .sellability:
                return NSSortDescriptor(keyPath: \ImageEvaluation.currentEvaluation?.sellabilityScore, ascending: false)
            }
        }
    }

    enum FilterOption: String, CaseIterable {
        case all = "All Images"
        case evaluated = "Evaluated"
        case notEvaluated = "Not Evaluated"
        case failed = "Failed"
        case portfolio = "Portfolio"
        case store = "Store"

        func matches(_ evaluation: ImageEvaluation) -> Bool {
            switch self {
            case .all:
                return true
            case .evaluated:
                return evaluation.currentEvaluation != nil
            case .notEvaluated:
                return evaluation.dateLastEvaluated == nil
            case .failed:
                // Failed = attempted evaluation but no successful result
                return evaluation.dateLastEvaluated != nil &&
                       (evaluation.currentEvaluation == nil ||
                        evaluation.currentEvaluation?.evaluationStatus == "failed")
            case .portfolio:
                return evaluation.currentEvaluation?.primaryPlacement == "PORTFOLIO"
            case .store:
                return evaluation.currentEvaluation?.primaryPlacement == "STORE"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            GalleryViewToolbar(
                selectionManager: selectionManager,
                evaluationManager: evaluationManager,
                filteredImages: filteredImages,
                failedImages: failedImages,
                isImporting: $isImporting,
                filterOption: $filterOption,
                sortOption: $sortOption,
                searchText: $searchText,
                showOnlySelected: $showOnlySelected,
                showingDeleteConfirmation: $showingDeleteConfirmation,
                onEvaluateSelected: startEvaluation,
                onDeleteSelected: { showingDeleteConfirmation = true }
            )

            Divider()

            // Main content
            GalleryGridContent(
                filteredImages: filteredImages,
                selectionManager: selectionManager,
                evaluationManager: evaluationManager,
                isImporting: $isImporting,
                isDragOver: $isDragOver,
                selectedDetailImage: $detailViewImage,
                showingDeleteConfirmation: $showingDeleteConfirmation
            )
        }
        .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
            handleDrop(providers)
            return true
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
        .sheet(isPresented: $showingEvaluationSheet) {
            EvaluationProgressView(manager: evaluationManager)
        }
        .sheet(item: $detailViewImage) { image in
            let _ = print("🔷 Sheet presenting with image: \(image.id?.uuidString ?? "unknown")")
            ImageDetailView(evaluation: image)
                .environment(\.managedObjectContext, viewContext)
        }
        .alert("Delete Images", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSelectedImages()
            }
        } message: {
            Text("Are you sure you want to delete \(selectedImages.count) selected image\(selectedImages.count == 1 ? "" : "s")? This will remove the image data and all evaluation results. This action cannot be undone.")
        }
        .onChange(of: selectionManager.selectedIDs) { _, _ in
            // If no images selected, turn off selection filter
            if selectionManager.selectedIDs.isEmpty && showOnlySelected {
                showOnlySelected = false
            }
        }
        .focusable()
        .onKeyPress(.escape) {
            if !selectionManager.selectedIDs.isEmpty {
                selectionManager.deselectAll()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(keys: [.init("a")]) { press in
            // Check if command key is pressed
            if press.modifiers.contains(.command) {
                selectionManager.selectAll(ids: filteredImages.map { $0.objectID })
                return .handled
            }
            return .ignored
        }
    }

    // MARK: - Computed Properties
    private var filteredImages: [ImageEvaluation] {
        let baseImages = showOnlySelected ? Array(selectedImages) : Array(imageEvaluations)

        return baseImages
            .filter { filterOption.matches($0) }
            .filter { searchText.isEmpty || matchesSearch($0) }
            .sorted(by: sortOption.sortDescriptor)
    }

    private var failedImages: [ImageEvaluation] {
        imageEvaluations.filter { evaluation in
            evaluation.dateLastEvaluated != nil &&
            (evaluation.currentEvaluation == nil ||
             evaluation.currentEvaluation?.evaluationStatus == "failed")
        }
    }

    private func matchesSearch(_ evaluation: ImageEvaluation) -> Bool {
        guard !searchText.isEmpty else { return true }

        let searchLower = searchText.lowercased()

        // Search in file path
        if let bookmarkData = evaluation.originalFilePath {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale)
                if url.lastPathComponent.lowercased().contains(searchLower) {
                    return true
                }
            } catch {
                // Ignore bookmark resolution errors for search
            }
        }

        // Search in evaluation text
        if let result = evaluation.currentEvaluation {
            let searchableText = [
                result.primaryPlacement,
                result.strengths?.joined(separator: " "),
                result.improvements?.joined(separator: " "),
                result.marketComparison
            ].compactMap { $0 }.joined(separator: " ").lowercased()

            return searchableText.contains(searchLower)
        }

        return false
    }

    // MARK: - Methods

    // Helper computed property to get selected images from IDs
    private var selectedImages: [ImageEvaluation] {
        imageEvaluations.filter { selectionManager.selectedIDs.contains($0.objectID) }
    }

    private func handleSelection(_ evaluation: ImageEvaluation, index: Int, modifiers: EventModifiers) {
        let allIDs = filteredImages.map { $0.objectID }
        selectionManager.handleSelection(
            id: evaluation.objectID,
            index: index,
            modifiers: modifiers,
            allIDs: allIDs
        )
    }


    private func isImageBeingEvaluated(_ evaluation: ImageEvaluation) -> Bool {
        guard evaluationManager.isProcessing else { return false }

        // Check if this image is in the current evaluation queue
        guard let index = evaluationManager.evaluationQueue.firstIndex(of: evaluation) else {
            return false
        }

        // Check if this is the current image being processed
        // currentImageIndex is 1-based, array index is 0-based
        return index == evaluationManager.currentImageIndex - 1
    }

    private func isImageInQueue(_ evaluation: ImageEvaluation) -> Bool {
        guard evaluationManager.isProcessing else { return false }

        // Check if this image is in the queue
        guard let index = evaluationManager.evaluationQueue.firstIndex(of: evaluation) else {
            return false
        }

        // Only show as queued if it hasn't been processed yet
        // currentImageIndex is 1-based, so index should be >= currentImageIndex
        return index >= evaluationManager.currentImageIndex
    }

    private func getFilename(_ evaluation: ImageEvaluation) -> String {
        if let bookmarkData = evaluation.originalFilePath {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale)
                return url.lastPathComponent
            } catch {
                return "Unknown"
            }
        }
        return "Unknown"
    }

    private func showDetailView(_ evaluation: ImageEvaluation) {
        print("🔵 GalleryView.showDetailView called")
        print("  - Image ID: \(evaluation.id?.uuidString ?? "unknown")")
        print("  - Has processed path: \(evaluation.processedFilePath != nil)")
        print("  - Has original path: \(evaluation.originalFilePath != nil)")
        print("  - Has thumbnail: \(evaluation.thumbnailData != nil)")
        detailViewImage = evaluation
        print("  - detailViewImage set: \(detailViewImage != nil)")
    }

    private func startEvaluation() {
        guard !selectedImages.isEmpty else { return }

        // Add selected images to evaluation queue
        evaluationManager.evaluationQueue = Array(selectedImages)
        showingEvaluationSheet = true

        Task {
            do {
                try await evaluationManager.startEvaluation()
                await MainActor.run {
                    // Don't clear selection - let user see what was evaluated
                    // selectedImages.removeAll() -- removed to keep selection visible
                    showingEvaluationSheet = false
                }
            } catch {
                print("Evaluation error: \(error)")
            }
        }
    }

    private func retryFailedEvaluations() {
        guard !failedImages.isEmpty else { return }

        // Add failed images to evaluation queue
        evaluationManager.evaluationQueue = failedImages
        showingEvaluationSheet = true

        Task {
            do {
                try await evaluationManager.startEvaluation()
                await MainActor.run {
                    showingEvaluationSheet = false
                }
            } catch {
                print("Evaluation error: \(error)")
            }
        }
    }

    private func deleteSelectedImages() {
        let imagesToDelete = Array(selectedImages)

        for image in imagesToDelete {
            // Delete processed files if they exist
            if let processedPath = image.processedFilePath {
                try? FileManager.default.removeItem(atPath: processedPath)
            }

            // Delete the Core Data object
            viewContext.delete(image)
        }

        // Save the context
        do {
            try viewContext.save()
            // Clear selection after deletion
            selectionManager.selectedIDs.removeAll()
            // Reset selection filter
            showOnlySelected = false
        } catch {
            print("Error deleting images: \(error)")
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    return
                }

                Task {
                    await importImageURLs([url])
                }
            }
        }
        return true
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                await importImageURLs(urls)
            }
        case .failure(let error):
            print("Import error: \(error)")
        }
    }

    @MainActor
    private func importImageURLs(_ urls: [URL]) async {
        await evaluationManager.addImages(urls: urls)
    }
}

// MARK: - Thumbnail View

struct ImageThumbnailView: View {
    let evaluation: ImageEvaluation
    let isSelected: Bool
    var isBeingEvaluated: Bool = false
    var isInQueue: Bool = false
    var index: Int = 0
    let onSelection: (EventModifiers) -> Void
    let onDoubleTap: () -> Void

    @State private var thumbnailImage: NSImage?

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                // Thumbnail
                Group {
                    if let thumbnail = thumbnailImage {
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
                .clipped()
                .cornerRadius(8)

                // Selection Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .white)
                    .background(Circle().fill(.black.opacity(0.5)))
                    .padding(8)

            }
            .overlay(alignment: .center) {
                // Evaluation status overlay
                if isBeingEvaluated {
                    ZStack {
                        Rectangle()
                            .fill(.black.opacity(0.6))

                        VStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.regular)
                                .progressViewStyle(CircularProgressViewStyle())

                            Text("Evaluating...")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                        }
                        .padding(.bottom, 20) // Adjust for badge space
                    }
                } else if isInQueue {
                    ZStack {
                        Rectangle()
                            .fill(.black.opacity(0.4))

                        VStack(spacing: 8) {
                            Image(systemName: "clock.fill")
                                .font(.title2)
                                .foregroundStyle(.white.opacity(0.9))

                            Text("Queued")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .padding(.bottom, 20) // Adjust for badge space
                    }
                }
            }
            .overlay(alignment: .bottomLeading) {
                // Commercial Metadata Indicator (bottom left) - show for STORE/BOTH placement
                if let result = evaluation.currentEvaluation,
                   result.title != nil,
                   (result.primaryPlacement == "STORE" || result.primaryPlacement == "BOTH") {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Circle().fill(Color.green.opacity(0.9)))
                        .padding(8)
                }

            }
            .overlay(alignment: .bottomTrailing) {
                // Evaluation Badge
                if let result = evaluation.currentEvaluation {
                    VStack(spacing: 2) {
                        // Show artistic and commercial scores
                        HStack(spacing: 4) {
                            // Artistic score
                            VStack(spacing: 1) {
                                Text("A")
                                    .font(.system(size: 8))
                                Text(String(format: "%.1f", result.artisticScore))
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .frame(width: 28)

                            Divider()
                                .frame(height: 20)

                            // Commercial score
                            VStack(spacing: 1) {
                                Text("C")
                                    .font(.system(size: 8))
                                Text(String(format: "%.1f", result.sellabilityScore))
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .frame(width: 28)
                        }
                        .foregroundStyle(.white)

                        if let placement = result.primaryPlacement {
                            Text(placement)
                                .font(.system(size: 9))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(4)
                    .background(scoreColor.opacity(0.9))
                    .cornerRadius(4)
                    .padding(8)
                } else if evaluation.dateLastEvaluated != nil &&
                         (evaluation.currentEvaluation == nil ||
                          evaluation.currentEvaluation?.evaluationStatus == "failed") {
                    // Show failed evaluation badge
                    VStack(spacing: 2) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 16))
                        Text("FAILED")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(Color.red.opacity(0.9))
                    .cornerRadius(4)
                    .padding(8)
                }
            }

            // Filename
            Text(filename)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(filenameColor)
        }
        .background(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onDoubleTap()
        }
        .simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    // Get current event modifiers
                    let modifiers = NSEvent.modifierFlags
                    var eventModifiers = EventModifiers()

                    if modifiers.contains(.command) {
                        eventModifiers.insert(.command)
                    }
                    if modifiers.contains(.shift) {
                        eventModifiers.insert(.shift)
                    }
                    if modifiers.contains(.option) {
                        eventModifiers.insert(.option)
                    }
                    if modifiers.contains(.control) {
                        eventModifiers.insert(.control)
                    }

                    onSelection(eventModifiers)
                }
        )
        .onAppear {
            loadThumbnail()
        }
    }

    private var filename: String {
        if let bookmarkData = evaluation.originalFilePath {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale)
                return url.lastPathComponent
            } catch {
                return "Unknown"
            }
        }
        return "Unknown"
    }

    private var filenameColor: Color {
        if isBeingEvaluated {
            return .green
        } else if isInQueue {
            return .orange
        } else if isSelected {
            return .blue
        } else {
            return .primary
        }
    }

    private var scoreColor: Color {
        guard let score = evaluation.currentEvaluation?.overallWeightedScore else {
            return .gray
        }

        switch score {
        case 8...:
            return .green
        case 6..<8:
            return .blue
        case 4..<6:
            return .orange
        default:
            return .red
        }
    }

    private func loadThumbnail() {
        if let thumbnailData = evaluation.thumbnailData,
           let image = NSImage(data: thumbnailData) {
            thumbnailImage = image
        }
    }
}

// MARK: - Evaluation Status Bar

struct EvaluationStatusBar: View {
    @Bindable var manager: EvaluationManager

    var body: some View {
        HStack(spacing: 20) {
            ProgressView()
                .controlSize(.small)

            Text(manager.statusMessage)
                .font(.caption)

            if manager.totalImages > 0 {
                Text("\(manager.currentImageIndex) of \(manager.totalImages)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            ProgressView(value: manager.currentProgress)
                .frame(width: 200)

            Button("Cancel") {
                manager.cancelEvaluation()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Evaluation Progress Sheet

struct EvaluationProgressView: View {
    @Bindable var manager: EvaluationManager
    @Environment(\.dismiss) private var dismiss

    private var statusColor: Color {
        if manager.statusMessage.lowercased().contains("failed") ||
           manager.statusMessage.lowercased().contains("error") {
            return .red
        } else if manager.statusMessage.lowercased().contains("overloaded") ||
                  manager.statusMessage.lowercased().contains("waiting") {
            return .orange
        } else if manager.statusMessage.lowercased().contains("successful") ||
                  manager.statusMessage.lowercased().contains("complete") {
            return .green
        } else {
            return .primary
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Evaluating Images")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Status:")
                        .foregroundStyle(.secondary)
                    Text(manager.statusMessage)
                        .foregroundStyle(statusColor)
                }

                HStack {
                    Text("Progress:")
                        .foregroundStyle(.secondary)
                    Text("\(manager.currentImageIndex) of \(manager.totalImages)")
                        .monospacedDigit()
                }

                if manager.currentBatch > 0 {
                    HStack {
                        Text("Batch:")
                            .foregroundStyle(.secondary)
                        Text("\(manager.currentBatch) of \(manager.totalBatches)")
                            .monospacedDigit()
                    }
                }

                // Show success/failure counts
                if manager.successfulEvaluations > 0 || manager.failedEvaluations > 0 {
                    HStack(spacing: 20) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("\(manager.successfulEvaluations) successful")
                                .foregroundStyle(.green)
                        }

                        if manager.failedEvaluations > 0 {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                                Text("\(manager.failedEvaluations) failed")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .font(.caption)
                }

                ProgressView(value: manager.currentProgress)
                    .progressViewStyle(.linear)
            }
            .frame(minWidth: 400)

            HStack {
                Button("Cancel") {
                    manager.cancelEvaluation()
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                if !manager.isProcessing {
                    Button("Done") {
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(30)
        .frame(minWidth: 500, minHeight: 250)
    }
}

// MARK: - Sorting Extension

extension Array where Element == ImageEvaluation {
    func sorted(by descriptor: NSSortDescriptor) -> [Element] {
        return (self as NSArray).sortedArray(using: [descriptor]) as? [Element] ?? []
    }
}

#Preview {
    GalleryView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .frame(width: 900, height: 600)
}