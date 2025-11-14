//
//  SmartFolderGalleryView.swift
//  Nature Image Evaluation
//
//  Created by Claude on 11/14/25.
//

import SwiftUI
import CoreData

struct SmartFolderGalleryView: View {
    let smartFolder: Collection
    @Environment(\.managedObjectContext) private var viewContext
    @State private var evaluationManager = EvaluationManager()
    @StateObject private var smartFolderManager = SmartFolderManager.shared

    @State private var images: [ImageEvaluation] = []
    @State private var selectedImages = Set<ImageEvaluation>()
    @State private var selectedImageForDetail: ImageEvaluation?
    @State private var sortOption: SortOption = .dateAdded
    @State private var filterOption: FilterOption = .all
    @State private var showingFilePicker = false
    @State private var showingEvaluationError = false
    @State private var evaluationError: String?
    @State private var showOnlySelected = false
    @State private var isRefreshing = false

    var body: some View {
        VStack(spacing: 0) {
            toolbarView

            Divider()

            galleryView

            statusBarView
        }
        .sheet(item: $selectedImageForDetail) { image in
            ImageDetailView(evaluation: image)
                .environment(\.managedObjectContext, viewContext)
                .frame(minWidth: 1200, minHeight: 800)
        }
        .alert("Evaluation Error", isPresented: $showingEvaluationError) {
            Button("OK") { }
        } message: {
            Text(evaluationError ?? "An error occurred during evaluation")
        }
        .onAppear {
            refreshImages()
        }
        .onChange(of: smartFolder) { _, _ in
            refreshImages()
        }
    }

    // MARK: - View Components

    private var toolbarView: some View {
        HStack(spacing: 12) {
            // Refresh button
            Button(action: refreshImages) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(isRefreshing)

            if isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }

            Divider()
                .frame(height: 20)

            // Sort menu
            Menu {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button(action: { sortOption = option }) {
                        HStack {
                            Text(option.rawValue)
                            if sortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label("Sort: \(sortOption.rawValue)", systemImage: "arrow.up.arrow.down")
            }

            // Filter menu
            Menu {
                ForEach(FilterOption.allCases, id: \.self) { option in
                    Button(action: { filterOption = option }) {
                        HStack {
                            Text(option.rawValue)
                            if filterOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label("Filter: \(filterOption.rawValue)", systemImage: "line.3.horizontal.decrease.circle")
            }

            // Show selected toggle
            Toggle(isOn: $showOnlySelected) {
                Label("Show Selected", systemImage: "checkmark.square")
            }
            .toggleStyle(.button)

            Spacer()

            // Evaluate selected button
            if !selectedImages.isEmpty {
                Button(action: evaluateSelectedImages) {
                    Label("Evaluate Selected (\(selectedImages.count))", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .disabled(evaluationManager.isProcessing)
            }

            // Processing indicator
            if evaluationManager.isProcessing {
                processingIndicator
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var processingIndicator: some View {
        HStack(spacing: 4) {
            ProgressView()
                .controlSize(.small)
            Text("Processing...")
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(6)
    }

    private var galleryView: some View {
        ScrollView {
            if filteredAndSortedImages.isEmpty {
                emptyStateView
            } else {
                imageGridView
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: smartFolder.icon ?? "sparkle.magnifyingglass")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("No images match the criteria")
                .font(.title2)

            if let predicateString = smartFolder.smartPredicate,
               let criteria = SmartFolderCriteria.fromJSONString(predicateString) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current criteria:")
                        .font(.headline)

                    ForEach(criteria.rules) { rule in
                        HStack {
                            Text("• \(rule.criteriaType.rawValue)")
                            Text(rule.comparison.rawValue)
                            Text(rule.value.displayValue)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(50)
    }

    private var imageGridView: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)], spacing: 16) {
            ForEach(filteredAndSortedImages, id: \.self) { image in
                SmartFolderImageThumbnailView(
                    image: image,
                    isSelected: selectedImages.contains(image),
                    onTap: {
                        toggleSelection(image)
                    },
                    onDoubleTap: {
                        selectedImageForDetail = image
                    }
                )
            }
        }
        .padding()
    }

    private var statusBarView: some View {
        HStack {
            Text("\(filteredAndSortedImages.count) images")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !selectedImages.isEmpty {
                Text("• \(selectedImages.count) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Criteria summary
            if let predicateString = smartFolder.smartPredicate,
               let criteria = SmartFolderCriteria.fromJSONString(predicateString) {
                Text("\(criteria.rules.count) criteria • \(criteria.matchAll ? "Match all" : "Match any")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Helper Methods

    private var filteredAndSortedImages: [ImageEvaluation] {
        let baseImages = showOnlySelected ? Array(selectedImages) : images

        let filtered = baseImages.filter { image in
            filterOption.matches(image)
        }

        return filtered.sorted { first, second in
            sortOption.compare(first, second)
        }
    }

    private func refreshImages() {
        isRefreshing = true

        Task {
            await MainActor.run {
                images = smartFolderManager.fetchImages(for: smartFolder)
                isRefreshing = false
            }
        }
    }

    private func toggleSelection(_ image: ImageEvaluation) {
        if selectedImages.contains(image) {
            selectedImages.remove(image)
        } else {
            selectedImages.insert(image)
        }
    }

    private func evaluateSelectedImages() {
        guard !selectedImages.isEmpty else { return }

        // Add selected images to evaluation queue
        evaluationManager.evaluationQueue = Array(selectedImages)

        Task {
            do {
                try await evaluationManager.startEvaluation()
                await MainActor.run {
                    // Refresh images after evaluation
                    refreshImages()
                }
            } catch {
                print("Evaluation error: \(error)")
                await MainActor.run {
                    evaluationError = error.localizedDescription
                    showingEvaluationError = true
                }
            }
        }
    }
}

// Image Thumbnail View (reusing from GalleryView)
private struct SmartFolderImageThumbnailView: View {
    let image: ImageEvaluation
    let isSelected: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                // Thumbnail
                if let thumbnailData = image.thumbnailData,
                   let nsImage = NSImage(data: thumbnailData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 150, height: 150)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 150, height: 150)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        )
                }

                // Score bar
                if let result = image.currentEvaluation {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)

                        Text(String(format: "%.1f", result.overallWeightedScore))
                            .font(.caption.bold())

                        Spacer()

                        if let placement = result.primaryPlacement {
                            Text(placement)
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(placementColor(placement).opacity(0.2))
                                .foregroundStyle(placementColor(placement))
                                .cornerRadius(4)
                        }
                    }
                    .padding(6)
                    .background(Color(NSColor.controlBackgroundColor))
                } else {
                    HStack {
                        Text("Not evaluated")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(6)
                    .background(Color(NSColor.controlBackgroundColor))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
            )
            .onTapGesture {
                onTap()
            }
            .onTapGesture(count: 2) {
                onDoubleTap()
            }

            // Selection indicator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white, Color.accentColor)
                    .background(Circle().fill(Color.white).padding(2))
                    .offset(x: -8, y: 8)
            }
        }
    }

    private func placementColor(_ placement: String) -> Color {
        switch placement {
        case "PORTFOLIO":
            return .green
        case "STORE":
            return .blue
        case "BOTH":
            return .purple
        case "ARCHIVE":
            return .gray
        case "PRACTICE":
            return .orange
        default:
            return .secondary
        }
    }
}

// MARK: - Supporting Types

enum SortOption: String, CaseIterable {
    case dateAdded = "Date Added"
    case dateEvaluated = "Date Evaluated"
    case overallScore = "Overall Score"
    case sellability = "Sellability"

    func compare(_ first: ImageEvaluation, _ second: ImageEvaluation) -> Bool {
        switch self {
        case .dateAdded:
            return (first.dateAdded ?? Date.distantPast) > (second.dateAdded ?? Date.distantPast)
        case .dateEvaluated:
            return (first.dateLastEvaluated ?? Date.distantPast) > (second.dateLastEvaluated ?? Date.distantPast)
        case .overallScore:
            let firstScore = first.currentEvaluation?.overallWeightedScore ?? 0
            let secondScore = second.currentEvaluation?.overallWeightedScore ?? 0
            return firstScore > secondScore
        case .sellability:
            let firstScore = first.currentEvaluation?.sellabilityScore ?? 0
            let secondScore = second.currentEvaluation?.sellabilityScore ?? 0
            return firstScore > secondScore
        }
    }
}

enum FilterOption: String, CaseIterable {
    case all = "All Images"
    case evaluated = "Evaluated"
    case notEvaluated = "Not Evaluated"
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
        case .portfolio:
            return evaluation.currentEvaluation?.primaryPlacement == "PORTFOLIO"
        case .store:
            return evaluation.currentEvaluation?.primaryPlacement == "STORE"
        }
    }
}

#Preview {
    SmartFolderGalleryView(smartFolder: Collection())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}