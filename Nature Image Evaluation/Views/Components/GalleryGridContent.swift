//
//  GalleryGridContent.swift
//  Nature Image Evaluation
//
//  Created by Claude on 11/18/25.
//

import SwiftUI
import CoreData

struct GalleryGridContent: View {
    let filteredImages: [ImageEvaluation]
    @ObservedObject var selectionManager: SelectionManager
    let evaluationManager: EvaluationManager

    @Binding var isImporting: Bool
    @Binding var isDragOver: Bool
    @Binding var selectedDetailImage: ImageEvaluation?
    @Binding var showingDeleteConfirmation: Bool

    // COMMENTED OUT: Old LazyVGrid columns - replaced with NSCollectionView
    // let columns = [
    //     GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 20)
    // ]

    var body: some View {
        if filteredImages.isEmpty {
            ScrollView {
                EmptyGalleryView(
                    isImporting: $isImporting,
                    isDragOver: isDragOver
                )
            }
            .background(dragOverBackground)
        } else {
            // NEW: Native NSCollectionView for proper macOS behavior
            GeometryReader { geometry in
                NativeImageCollectionView(
                    images: filteredImages,
                    selection: $selectionManager.selectedIDs,
                    onDoubleClick: { evaluation in
                        selectedDetailImage = evaluation
                    },
                    evaluationManager: evaluationManager
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
                .background(dragOverBackground)
            }

            // COMMENTED OUT: Old LazyVGrid implementation
            // GalleryGrid(
            //     filteredImages: filteredImages,
            //     selectionManager: selectionManager,
            //     evaluationManager: evaluationManager,
            //     selectedDetailImage: $selectedDetailImage,
            //     showingDeleteConfirmation: $showingDeleteConfirmation,
            //     columns: columns
            // )
        }
    }

    @ViewBuilder
    private var dragOverBackground: some View {
        if isDragOver {
            Color.accentColor.opacity(0.1)
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor, lineWidth: 3)
                .padding()
        }
    }
}

struct EmptyGalleryView: View {
    @Binding var isImporting: Bool
    let isDragOver: Bool

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)

            Text("Quick Analysis")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(spacing: 10) {
                Text("Drag images here for instant evaluation")
                    .foregroundStyle(.primary)
                Text("Perfect for quick tests and one-off analyses")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Import Images...") {
                isImporting = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
        .padding()
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [10, 5]))
                .foregroundStyle(.tertiary)
                .opacity(isDragOver ? 1 : 0.3)
        )
    }
}

// COMMENTED OUT: Old LazyVGrid implementation - replaced with NSCollectionView
// Keeping for reference during transition
/*
struct GalleryGrid: View {
    let filteredImages: [ImageEvaluation]
    @ObservedObject var selectionManager: SelectionManager
    let evaluationManager: EvaluationManager

    @Binding var selectedDetailImage: ImageEvaluation?
    @Binding var showingDeleteConfirmation: Bool

    let columns: [GridItem]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
            ForEach(filteredImages.indices, id: \.self) { index in
                let evaluation = filteredImages[index]
                let isSelected = selectionManager.selectedIDs.contains(evaluation.objectID)
                let isBeingEvaluated = isImageBeingEvaluated(evaluation)
                let isInQueue = isImageInQueue(evaluation) && !isBeingEvaluated

                ImageThumbnailView(
                    evaluation: evaluation,
                    isSelected: isSelected,
                    isBeingEvaluated: isBeingEvaluated,
                    isInQueue: isInQueue,
                    index: index,
                    onSelection: { modifiers in
                        handleSelection(evaluation, index: index, modifiers: modifiers)
                    },
                    onDoubleTap: {
                        showDetailView(evaluation)
                    }
                )
                .frame(minWidth: 150, idealWidth: 175, maxWidth: 200, minHeight: 180, maxHeight: 240)
                .id(evaluation.objectID)
                .contextMenu {
                    contextMenuItems(for: evaluation)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top)
        .padding(.bottom, 40) // Extra bottom padding for scroll
    }

    private func isImageBeingEvaluated(_ evaluation: ImageEvaluation) -> Bool {
        guard evaluationManager.isProcessing else { return false }

        // Check if this image is in the current evaluation queue
        guard let index = evaluationManager.evaluationQueue.firstIndex(of: evaluation) else {
            return false
        }

        // Check if it's currently being processed (index is 0-based, currentImageIndex is 1-based)
        return index == evaluationManager.currentImageIndex - 1
    }

    private func isImageInQueue(_ evaluation: ImageEvaluation) -> Bool {
        evaluationManager.evaluationQueue.contains(evaluation)
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

    private func showDetailView(_ evaluation: ImageEvaluation) {
        selectedDetailImage = evaluation
    }

    @ViewBuilder
    private func contextMenuItems(for evaluation: ImageEvaluation) -> some View {
        Button(action: {
            showDetailView(evaluation)
        }) {
            Label("View Details", systemImage: "info.circle")
        }

        Button(action: {
            selectionManager.selectedIDs = [evaluation.objectID]
            // Start evaluation would be called from parent
        }) {
            Label("Re-evaluate", systemImage: "brain")
        }

        Divider()

        Button(role: .destructive, action: {
            selectionManager.selectedIDs = [evaluation.objectID]
            showingDeleteConfirmation = true
        }) {
            Label("Delete", systemImage: "trash")
        }
    }
}
*/