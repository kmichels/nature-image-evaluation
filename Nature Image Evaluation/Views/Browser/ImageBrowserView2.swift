//
//  ImageBrowserView2.swift
//  Nature Image Evaluation
//
//  Polished version with better UI design
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct ImageBrowserView2: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(EvaluationManager.self) private var evaluationManager
    @State private var viewModel: BrowserViewModel

    // UI State
    @State private var folderPickerPresented = false
    @State private var selectedFolder: URL?
    @State private var sidebarSelection: String? = "browser"
    @State private var showingSettings = false
    @State private var showingEvaluationError = false
    @State private var evaluationErrorMessage = ""

    // View customization
    @AppStorage("browserViewMode") private var savedViewMode: String = "grid"
    @AppStorage("lastSelectedFolderBookmark") private var savedFolderBookmark: Data?

    init() {
        _viewModel = State(initialValue: BrowserViewModel(viewContext: PersistenceController.shared.container.viewContext))
    }

    var body: some View {
        HSplitView {
            // Sidebar
            sidebarContent
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 300)

            // Main content
            mainContent
                .frame(minWidth: 600)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            viewModel.viewMode = BrowserViewModel.ViewMode(rawValue: savedViewMode) ?? .grid
            loadSavedFolder()
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
                        saveFolderBookmark(url)
                    }
                }
            case .failure(let error):
                print("Failed to select folder: \(error)")
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environment(\.managedObjectContext, viewContext)
                .frame(minWidth: 600, minHeight: 400)
        }
        .alert("Evaluation Error", isPresented: $showingEvaluationError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(evaluationErrorMessage)
        }
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebarContent: some View {
        VStack(spacing: 0) {
            // Header with better styling
            HStack {
                Label("Image Browser", systemImage: "photo.on.rectangle")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Current Folder Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Folder")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 16)

                        if let folder = selectedFolder {
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(.accentColor)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(folder.lastPathComponent)
                                        .lineLimit(1)
                                        .font(.system(.body, design: .rounded))
                                    Text("\(viewModel.displayedURLs.count) images")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(6)
                            .padding(.horizontal, 12)
                        } else {
                            Button(action: { folderPickerPresented = true }) {
                                HStack {
                                    Image(systemName: "folder.badge.plus")
                                    Text("Select Folder")
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                            .padding(.horizontal, 12)
                        }
                    }

                    // Quick Actions
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quick Actions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 16)

                        VStack(spacing: 4) {
                            Button(action: { folderPickerPresented = true }) {
                                Label("Change Folder", systemImage: "folder")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(SidebarButtonStyle())

                            if !viewModel.selectedURLs.isEmpty {
                                Button(action: { viewModel.deselectAll() }) {
                                    Label("Clear Selection", systemImage: "xmark.circle")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(SidebarButtonStyle())
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                }
                .padding(.vertical, 8)
            }

            Divider()

            // Selection info
            if !viewModel.selectedURLs.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                    Text("\(viewModel.selectedURLs.count) selected")
                        .font(.caption)
                    Spacer()
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Modern toolbar
            toolbarView

            // Content area with better background
            ZStack {
                // Background
                Color(NSColor.textBackgroundColor)

                // Image grid/list/columns based on view mode
                Group {
                    switch viewModel.viewMode {
                    case .grid:
                        ImageGridView2(viewModel: viewModel)
                    case .list:
                        ImageListView(viewModel: viewModel)
                    case .columns:
                        // Placeholder for column view
                        VStack {
                            Spacer()
                            Image(systemName: "rectangle.split.3x1")
                                .font(.system(size: 48))
                                .foregroundColor(Color(NSColor.tertiaryLabelColor))
                            Text("Column view coming soon")
                                .foregroundColor(.secondary)
                                .padding(.top)
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var toolbarView: some View {
        HStack(spacing: 16) {
            // Image count
            HStack(spacing: 4) {
                Image(systemName: "photo.stack")
                    .foregroundColor(.secondary)
                Text("\(viewModel.displayedURLs.count)")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
                Text("images")
                    .foregroundColor(.secondary)
            }

            if !viewModel.selectedURLs.isEmpty {
                Divider()
                    .frame(height: 16)

                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.accentColor)
                    Text("\(viewModel.selectedURLs.count)")
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundColor(.accentColor)
                    Text("selected")
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Sort menu
            Menu {
                ForEach(BrowserViewModel.SortOrder.allCases, id: \.self) { order in
                    Button(action: {
                        viewModel.sortOrder = order
                        viewModel.applyFiltersAndSorting()
                    }) {
                        HStack {
                            Text(order.rawValue)
                            if viewModel.sortOrder == order {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Divider()
                .frame(height: 16)

            // View mode selector with icons
            HStack(spacing: 2) {
                ForEach(BrowserViewModel.ViewMode.allCases, id: \.self) { mode in
                    Button(action: {
                        viewModel.viewMode = mode
                        savedViewMode = mode.rawValue
                    }) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 14))
                            .frame(width: 28, height: 24)
                            .background(viewModel.viewMode == mode ?
                                       Color.accentColor : Color.clear)
                            .foregroundColor(viewModel.viewMode == mode ?
                                           .white : .primary)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help(mode.rawValue)
                }
            }
            .padding(2)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)

            Divider()
                .frame(height: 16)

            // Evaluate button or progress
            if evaluationManager.isProcessing {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text(evaluationManager.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: 200)

                    Button("Cancel") {
                        evaluationManager.cancelEvaluation()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                    .font(.caption)
                }
            } else if !viewModel.selectedURLs.isEmpty {
                Button(action: { evaluateSelectedImages() }) {
                    Label("Evaluate (\(viewModel.selectedURLs.count))", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .help("Evaluate selected images with AI")
            }

            Divider()
                .frame(height: 16)

            // Settings button
            Button(action: { showingSettings = true }) {
                Image(systemName: "gear")
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    // MARK: - Evaluation

    private func evaluateSelectedImages() {
        let urls = Array(viewModel.selectedURLs)
        Task {
            await evaluationManager.addImages(urls: urls)
            do {
                try await evaluationManager.startEvaluation()
                // Refresh cache after evaluation completes
                viewModel.refreshEvaluationCache()
            } catch {
                evaluationErrorMessage = error.localizedDescription
                showingEvaluationError = true
            }
        }
    }

    // MARK: - Folder Persistence

    private func saveFolderBookmark(_ url: URL) {
        do {
            let bookmark = try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            savedFolderBookmark = bookmark
        } catch {
            print("Failed to save folder bookmark: \(error)")
        }
    }

    private func loadSavedFolder() {
        guard let bookmarkData = savedFolderBookmark else { return }

        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                // Bookmark is stale, clear it
                savedFolderBookmark = nil
                return
            }

            // Load the folder
            Task {
                await viewModel.loadFolder(url)
                selectedFolder = url
            }
        } catch {
            print("Failed to load saved folder: \(error)")
            // Clear invalid bookmark
            savedFolderBookmark = nil
        }
    }
}

// MARK: - Custom Button Style

struct SidebarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(configuration.isPressed ?
                       Color.accentColor.opacity(0.2) :
                       Color.clear)
            .cornerRadius(4)
            .contentShape(Rectangle())
    }
}

// MARK: - Preview

#Preview {
    ImageBrowserView2()
        .frame(width: 1200, height: 800)
}