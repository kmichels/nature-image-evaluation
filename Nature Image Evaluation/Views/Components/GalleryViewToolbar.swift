//
//  GalleryViewToolbar.swift
//  Nature Image Evaluation
//
//  Created by Claude on 11/18/25.
//

import SwiftUI
import CoreData

struct GalleryViewToolbar: View {
    @ObservedObject var selectionManager: SelectionManager
    let evaluationManager: EvaluationManager

    let filteredImages: [ImageEvaluation]
    let failedImages: [ImageEvaluation]

    @Binding var isImporting: Bool
    @Binding var filterOption: GalleryView.FilterOption
    @Binding var sortOption: GalleryView.SortOption
    @Binding var searchText: String
    @Binding var showOnlySelected: Bool
    @Binding var showingDeleteConfirmation: Bool

    let onEvaluateSelected: () -> Void
    let onDeleteSelected: () -> Void

    var selectedImages: [ImageEvaluation] {
        filteredImages.filter { selectionManager.selectedIDs.contains($0.objectID) }
    }

    var body: some View {
        HStack(spacing: 16) {
            // Import and Evaluation Controls
            Button(action: { isImporting = true }) {
                Label("Import", systemImage: "photo.badge.plus")
            }

            Button(action: onEvaluateSelected) {
                Label("Evaluate", systemImage: "brain")
            }
            .disabled(selectionManager.selectedIDs.isEmpty || evaluationManager.isProcessing)

            // Show progress if evaluating
            if evaluationManager.isProcessing {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 16, height: 16)

                Text("\(evaluationManager.currentImageIndex)/\(evaluationManager.totalImages)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Failed images indicator
            if !failedImages.isEmpty {
                Button(action: {
                    filterOption = .failed
                }) {
                    Label("\(failedImages.count) failed", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                }
            }

            // Delete button
            if !selectionManager.selectedIDs.isEmpty {
                Button(action: { showingDeleteConfirmation = true }) {
                    Label("Delete", systemImage: "trash")
                }
                .foregroundColor(.red)
                .disabled(evaluationManager.isProcessing)
                .keyboardShortcut(.delete, modifiers: .command)
            }

            Divider()
                .frame(height: 20)

            // Filter and Sort
            Picker("Filter", selection: $filterOption) {
                ForEach(GalleryView.FilterOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 150)

            Picker("Sort", selection: $sortOption) {
                ForEach(GalleryView.SortOption.allCases, id: \.self) { option in
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

            // Selection Controls
            SelectionControls(
                selectionManager: selectionManager,
                filteredImages: filteredImages,
                showOnlySelected: $showOnlySelected
            )
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct SelectionControls: View {
    @ObservedObject var selectionManager: SelectionManager
    let filteredImages: [ImageEvaluation]
    @Binding var showOnlySelected: Bool

    var selectedImages: [ImageEvaluation] {
        filteredImages.filter { selectionManager.selectedIDs.contains($0.objectID) }
    }

    var body: some View {
        Group {
            if !selectionManager.selectedIDs.isEmpty {
                Text("\(selectedImages.count) selected")
                    .foregroundStyle(.secondary)
                    .font(.caption)

                // Selection Management Menu
                Menu {
                    Button(action: {
                        selectionManager.selectAll(ids: filteredImages.map { $0.objectID })
                    }) {
                        Label("Select All", systemImage: "checkmark.rectangle.stack.fill")
                    }
                    .keyboardShortcut("a", modifiers: .command)
                    .disabled(selectionManager.selectedIDs.count == filteredImages.count)

                    Button(action: {
                        selectionManager.deselectAll()
                    }) {
                        Label("Clear Selection", systemImage: "xmark.rectangle")
                    }
                    .keyboardShortcut(.escape, modifiers: [])

                    Button(action: {
                        selectionManager.invertSelection(allIDs: filteredImages.map { $0.objectID })
                    }) {
                        Label("Invert Selection", systemImage: "arrow.triangle.2.circlepath")
                    }
                } label: {
                    Label("Selection", systemImage: "checklist")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Button(action: {
                    showOnlySelected.toggle()
                }) {
                    Label(showOnlySelected ? "Show All" : "Show Selected",
                          systemImage: showOnlySelected ? "rectangle.grid.2x2" : "checkmark.rectangle.stack")
                }
                .disabled(selectedImages.isEmpty)
            } else {
                // Show selection menu even when nothing selected
                Menu {
                    Button(action: {
                        selectionManager.selectAll(ids: filteredImages.map { $0.objectID })
                    }) {
                        Label("Select All", systemImage: "checkmark.rectangle.stack.fill")
                    }
                    .keyboardShortcut("a", modifiers: .command)
                    .disabled(filteredImages.isEmpty)
                } label: {
                    Label("Select", systemImage: "checklist")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
    }
}