//
//  GalleryToolbar.swift
//  Nature Image Evaluation
//
//  Created by Claude on 11/18/25.
//

import SwiftUI

/// Reusable toolbar component for gallery views
struct GalleryToolbar<SelectionID: Hashable>: View {
    // Required parameters
    let itemCount: Int
    let selectedCount: Int
    @Binding var showOnlySelected: Bool

    // Selection callbacks
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void
    let onInvertSelection: () -> Void

    // Optional components
    var showEvaluateButton: Bool = true
    var onEvaluate: (() -> Void)? = nil
    var isEvaluating: Bool = false

    var showRefreshButton: Bool = false
    var onRefresh: (() -> Void)? = nil

    // Custom content for filters/sorts
    var filterContent: AnyView? = nil
    var sortContent: AnyView? = nil

    var body: some View {
        HStack(spacing: 16) {
            // Item count
            Text("\(itemCount) \(itemCount == 1 ? "image" : "images")")
                .foregroundStyle(.secondary)

            if filterContent != nil || sortContent != nil {
                Divider()
                    .frame(height: 20)
            }

            // Filter and Sort controls (if provided)
            if let filterContent = filterContent {
                filterContent
            }

            if let sortContent = sortContent {
                sortContent
            }

            Spacer()

            // Selection controls
            if selectedCount > 0 {
                Text("\(selectedCount) selected")
                    .foregroundStyle(.secondary)
                    .font(.caption)

                // Selection Management Menu
                Menu {
                    Button(action: onSelectAll) {
                        Label("Select All", systemImage: "checkmark.rectangle.stack.fill")
                    }
                    .keyboardShortcut("a", modifiers: .command)
                    .disabled(selectedCount == itemCount)

                    Button(action: onDeselectAll) {
                        Label("Clear Selection", systemImage: "xmark.rectangle")
                    }
                    .keyboardShortcut(.escape, modifiers: [])

                    Button(action: onInvertSelection) {
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
                .disabled(selectedCount == 0)
            } else {
                // Show selection menu even when nothing selected
                Menu {
                    Button(action: onSelectAll) {
                        Label("Select All", systemImage: "checkmark.rectangle.stack.fill")
                    }
                    .keyboardShortcut("a", modifiers: .command)
                    .disabled(itemCount == 0)
                } label: {
                    Label("Select", systemImage: "checklist")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            // Optional action buttons
            if showEvaluateButton, let onEvaluate = onEvaluate {
                Button("Evaluate Selected") {
                    onEvaluate()
                }
                .disabled(selectedCount == 0 || isEvaluating)
            }

            if showRefreshButton, let onRefresh = onRefresh {
                Button("Refresh") {
                    onRefresh()
                }
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Convenience Extensions

extension GalleryToolbar {
    /// Create a toolbar with filter picker
    func withFilter<F: Hashable & CaseIterable & RawRepresentable>(
        _ selection: Binding<F>,
        label: String = "Filter"
    ) -> GalleryToolbar where F.RawValue == String, F.AllCases: RandomAccessCollection {
        var copy = self
        copy.filterContent = AnyView(
            Picker(label, selection: selection) {
                ForEach(F.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 150)
        )
        return copy
    }

    /// Create a toolbar with sort picker
    func withSort<S: Hashable & CaseIterable & RawRepresentable>(
        _ selection: Binding<S>,
        ascending: Binding<Bool>,
        onSortChange: @escaping () -> Void,
        label: String = "Sort"
    ) -> GalleryToolbar where S.RawValue == String, S.AllCases: RandomAccessCollection {
        var copy = self
        copy.sortContent = AnyView(
            HStack(spacing: 4) {
                Picker(label, selection: selection) {
                    ForEach(S.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 130)
                .onChange(of: selection.wrappedValue) { _, _ in
                    onSortChange()
                }

                Button(action: {
                    ascending.wrappedValue.toggle()
                    onSortChange()
                }) {
                    Image(systemName: ascending.wrappedValue ? "arrow.up" : "arrow.down")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .help(ascending.wrappedValue ? "Sort ascending" : "Sort descending")
            }
        )
        return copy
    }
}