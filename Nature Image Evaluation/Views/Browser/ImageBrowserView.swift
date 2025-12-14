//
//  ImageBrowserView.swift
//  Nature Image Evaluation
//
//  Created on December 2025 during UI rebuild
//  Main browser view - pure SwiftUI, no NSViewRepresentable
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct ImageBrowserView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var viewModel: BrowserViewModel

    // UI State
    @State private var folderPickerPresented = false
    @State private var selectedFolder: URL?

    // View customization
    @AppStorage("browserViewMode") private var savedViewMode: String = "grid"
    @AppStorage("browserThumbnailSize") private var savedThumbnailSize: Double = 150

    init() {
        // Initialize will be called with proper context from parent
        _viewModel = State(initialValue: BrowserViewModel(viewContext: PersistenceController.shared.container.viewContext))
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar - folder tree or recent folders
            sidebarContent
                .frame(minWidth: 200, idealWidth: 250)
        } detail: {
            // Main content area
            mainContent
        }
        .toolbar {
            toolbarContent
        }
        .onAppear {
            loadSavedSettings()
        }
        .fileImporter(
            isPresented: $folderPickerPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task {
                        await viewModel.loadFolder(url)
                        selectedFolder = url
                    }
                }
            case .failure(_):
                print("Failed to select folder")
            }
        }
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebarContent: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("Folders", systemImage: "folder")
                    .font(.headline)
                Spacer()
                Button(action: { folderPickerPresented = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Folder list (placeholder for now)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if let folder = selectedFolder {
                        FolderRow(url: folder, isSelected: true)
                            .onTapGesture {
                                Task {
                                    await viewModel.loadFolder(folder)
                                }
                            }
                    }

                    // Placeholder for recent/favorite folders
                    Text("Recent folders will appear here")
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .padding()
                }
                .padding(.vertical)
            }
        }
        .background(.regularMaterial)
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Status bar
            statusBar

            Divider()

            // Image grid/list/columns based on view mode
            contentView
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    @ViewBuilder
    private var statusBar: some View {
        HStack {
            Text("\(viewModel.displayedURLs.count) images")
                .foregroundColor(.secondary)

            if !viewModel.selectedURLs.isEmpty {
                Text("• \(viewModel.selectedURLs.count) selected")
                    .foregroundColor(.secondary)
            }

            Spacer()

            // View mode selector
            Picker("View", selection: $viewModel.viewMode) {
                ForEach(BrowserViewModel.ViewMode.allCases, id: \.self) { mode in
                    Label(mode.rawValue, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            // Thumbnail size slider (for grid view)
            if viewModel.viewMode == .grid {
                Slider(value: $viewModel.thumbnailSize, in: 100...300, step: 25) {
                    Text("Size")
                }
                .frame(width: 120)
                .onChange(of: viewModel.thumbnailSize) { _, newValue in
                    savedThumbnailSize = newValue
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private var contentView: some View {
        switch viewModel.viewMode {
        case .grid:
            ImageGridView(viewModel: viewModel)
        case .list:
            ImageListView(viewModel: viewModel)
        case .columns:
            // Placeholder for column view
            Text("Column view coming soon")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Select Folder", systemImage: "folder.badge.plus") {
                folderPickerPresented = true
            }
        }

        ToolbarItem(placement: .automatic) {
            Menu("Sort", systemImage: "arrow.up.arrow.down") {
                ForEach(BrowserViewModel.SortOrder.allCases, id: \.self) { order in
                    Button(order.rawValue) {
                        viewModel.sortOrder = order
                        viewModel.applyFiltersAndSorting()
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func loadSavedSettings() {
        if let mode = BrowserViewModel.ViewMode(rawValue: savedViewMode) {
            viewModel.viewMode = mode
        }
        viewModel.thumbnailSize = savedThumbnailSize
    }
}

// MARK: - Folder Row

struct FolderRow: View {
    let url: URL
    let isSelected: Bool

    var body: some View {
        HStack {
            Image(systemName: isSelected ? "folder.fill" : "folder")
                .foregroundColor(isSelected ? .accentColor : .secondary)
            Text(url.lastPathComponent)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(4)
    }
}

// MARK: - Preview

#Preview {
    ImageBrowserView()
        .frame(width: 1200, height: 800)
}