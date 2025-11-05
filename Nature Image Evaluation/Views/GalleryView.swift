//
//  GalleryView.swift
//  Nature Image Evaluation
//
//  Created by Claude Code on 10/28/25.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

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

    // MARK: - State

    @State private var selectedImages: Set<ImageEvaluation> = []
    @State private var isImporting = false
    @State private var isDragOver = false
    @State private var showingEvaluationSheet = false
    @State private var detailViewImage: ImageEvaluation?  // When non-nil, shows detail view
    @State private var searchText = ""
    @State private var sortOption: SortOption = .dateAdded
    @State private var filterOption: FilterOption = .all
    @State private var showingDeleteConfirmation = false

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
            HStack(spacing: 20) {
                // Import Button
                Button(action: { isImporting = true }) {
                    Label("Import Images", systemImage: "photo.badge.plus")
                }
                .keyboardShortcut("i", modifiers: .command)

                // Evaluate Button
                Button(action: startEvaluation) {
                    Label("Evaluate Selected", systemImage: "brain")
                }
                .disabled(selectedImages.isEmpty || evaluationManager.isProcessing)
                .keyboardShortcut("e", modifiers: .command)

                // Retry Failed Button
                if failedImages.count > 0 {
                    Button(action: retryFailedEvaluations) {
                        Label("Retry Failed (\(failedImages.count))", systemImage: "arrow.clockwise")
                    }
                    .disabled(evaluationManager.isProcessing)
                }

                // Delete Selected Button
                if !selectedImages.isEmpty {
                    Button(action: { showingDeleteConfirmation = true }) {
                        Label("Delete Selected", systemImage: "trash")
                    }
                    .foregroundColor(.red)
                    .disabled(evaluationManager.isProcessing)
                    .keyboardShortcut(.delete, modifiers: .command)
                }

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

                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search images...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .frame(maxWidth: 250)

                // Selection Info
                if !selectedImages.isEmpty {
                    Text("\(selectedImages.count) selected")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Main Content
            ScrollView {
                if filteredImages.isEmpty {
                    // Empty State
                    VStack(spacing: 20) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundStyle(.tertiary)

                        Text("No Images")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Drag images here or click 'Import Images' to get started")
                            .foregroundStyle(.secondary)

                        Button("Import Images...") {
                            isImporting = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, minHeight: 400)
                    .padding()

                } else {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(filteredImages.indices, id: \.self) { index in
                            let evaluation = filteredImages[index]
                            let isSelected = selectedImages.contains(evaluation)

                            ImageThumbnailView(
                                evaluation: evaluation,
                                isSelected: isSelected,
                                onTap: {
                                    print("🟢 Tap at actual index \(index)")
                                    print("   Image at this index: \(getFilename(evaluation))")
                                    print("   Total images: \(filteredImages.count)")
                                    toggleSelection(evaluation)
                                },
                                onDoubleTap: {
                                    showDetailView(evaluation)
                                },
                                debugIndex: index
                            )
                            .id(evaluation.objectID)
                            .contextMenu {
                                Button(action: {
                                    showDetailView(evaluation)
                                }) {
                                    Label("View Details", systemImage: "info.circle")
                                }

                                Button(action: {
                                    selectedImages = [evaluation]
                                    startEvaluation()
                                }) {
                                    Label("Re-evaluate", systemImage: "brain")
                                }

                                Divider()

                                Button(role: .destructive, action: {
                                    selectedImages = [evaluation]
                                    showingDeleteConfirmation = true
                                }) {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .background(isDragOver ? Color.accentColor.opacity(0.1) : Color.clear)
            .animation(.easeInOut(duration: 0.2), value: isDragOver)
            .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
                return handleDrop(providers)
            }

            // Status Bar
            if evaluationManager.isProcessing {
                EvaluationStatusBar(manager: evaluationManager)
            }
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
    }

    // MARK: - Computed Properties

    private var filteredImages: [ImageEvaluation] {
        imageEvaluations
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
        if let path = evaluation.originalFilePath?.lowercased(),
           path.contains(searchLower) {
            return true
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

    private func toggleSelection(_ evaluation: ImageEvaluation) {
        let filename = getFilename(evaluation)
        print("🟡 toggleSelection called for: \(filename)")
        print("   ID: \(evaluation.id?.uuidString ?? "nil")")
        print("   Currently selected count: \(selectedImages.count)")

        if selectedImages.contains(evaluation) {
            selectedImages.remove(evaluation)
            print("   ❌ Removed from selection")
        } else {
            selectedImages.insert(evaluation)
            print("   ✅ Added to selection")
        }
        print("   New selected count: \(selectedImages.count)")
    }

    private func getFilename(_ evaluation: ImageEvaluation) -> String {
        if let bookmarkData = evaluation.originalFilePath,
           let data = Data(base64Encoded: bookmarkData) {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale)
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
                    selectedImages.removeAll()
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
            selectedImages.removeAll()
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
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    var debugIndex: Int? = nil  // Add debug index

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
                // Debug index overlay (temporary)
                if let idx = debugIndex {
                    Text("\(idx)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.yellow)
                        .padding(4)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)
                        .allowsHitTesting(false) // Don't interfere with taps
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
                .foregroundStyle(isSelected ? .blue : .primary)
        }
        .background(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            print("🔵 Double-tap on image: \(filename)")
            onDoubleTap()
        }
        .onTapGesture(count: 1) {
            print("🔵 Single-tap on image: \(filename)")
            print("   Debug index: \(debugIndex ?? -1)")
            onTap()
        }
        .onAppear {
            loadThumbnail()
        }
    }

    private var filename: String {
        if let bookmarkData = evaluation.originalFilePath,
           let data = Data(base64Encoded: bookmarkData) {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale)
                return url.lastPathComponent
            } catch {
                return "Unknown"
            }
        }
        return "Unknown"
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