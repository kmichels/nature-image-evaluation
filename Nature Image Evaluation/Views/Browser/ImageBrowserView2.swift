//
//  ImageBrowserView2.swift
//  Nature Image Evaluation
//
//  Polished version with better UI design
//

import CoreData
import SwiftUI
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
    @AppStorage("browserSortOrder") private var savedSortOrder: String = "Date Modified"
    @AppStorage("lastSelectedFolderBookmark") private var savedFolderBookmark: Data?

    init() {
        _viewModel = State(initialValue: BrowserViewModel(viewContext: PersistenceController.shared.container.viewContext))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Full-bleed content underneath
            mainContent

            // Sidebar container extends to top (for traffic lights), glass panel is inset
            sidebarContainer
                .ignoresSafeArea()
        }
        .onAppear {
            viewModel.viewMode = BrowserViewModel.ViewMode(rawValue: savedViewMode) ?? .grid
            viewModel.sortOrder = BrowserViewModel.SortOrder(rawValue: savedSortOrder) ?? .dateModified
            loadSavedFolder()
        }
        .fileImporter(
            isPresented: $folderPickerPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                if let url = urls.first {
                    Task {
                        await viewModel.loadFolder(url)
                        selectedFolder = url
                        saveFolderBookmark(url)
                    }
                }
            case let .failure(error):
                print("Failed to select folder: \(error)")
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environment(\.managedObjectContext, viewContext)
                .frame(minWidth: 600, minHeight: 400)
        }
        .alert("Evaluation Error", isPresented: $showingEvaluationError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(evaluationErrorMessage)
        }
    }

    // MARK: - Sidebar Container (extends to top for traffic lights)

    private let sidebarWidth: CGFloat = 220
    private let sidebarInset: CGFloat = 6 // Gap around the glass panel
    private let toolbarAreaHeight: CGFloat = 44 // Height for toolbar/traffic light area

    private var contentLeadingPadding: CGFloat {
        sidebarWidth + sidebarInset + 6
    }

    @ViewBuilder
    private var sidebarContainer: some View {
        // Clear container that extends to window edges - traffic lights float here
        VStack(spacing: 0) {
            // The actual glass panel with rounded corners, inset from edges
            sidebarGlassPanel
                .padding(.top, sidebarInset)
                .padding(.leading, sidebarInset)
                .padding(.bottom, sidebarInset)
        }
        .frame(width: sidebarWidth + sidebarInset) // Width includes left padding
        .frame(maxHeight: .infinity)
    }

    // MARK: - Sidebar Glass Panel (the visible rounded panel)

    @ViewBuilder
    private var sidebarGlassPanel: some View {
        VStack(spacing: 0) {
            sidebarHeader
            Divider().padding(.horizontal, 8)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    sidebarLocationSection
                    sidebarActionsSection
                }
                .padding(.vertical, 8)
            }
            sidebarSelectionInfo
        }
        .frame(width: sidebarWidth)
        .frame(maxHeight: .infinity)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 2)
    }

    @ViewBuilder
    private var sidebarHeader: some View {
        HStack {
            Label("Library", systemImage: "photo.on.rectangle")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 36)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var sidebarLocationSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Location")
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 12)

            if let folder = selectedFolder {
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 16))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(folder.lastPathComponent)
                            .lineLimit(1)
                            .font(.system(.callout, design: .rounded, weight: .medium))
                        Text("\(viewModel.displayedURLs.count) images")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 8)
            } else {
                Button(action: { folderPickerPresented = true }) {
                    HStack {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 16))
                        Text("Select Folder")
                            .font(.callout)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .background(.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 8)
            }
        }
    }

    @ViewBuilder
    private var sidebarActionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Actions")
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 12)

            VStack(spacing: 2) {
                Button(action: { folderPickerPresented = true }) {
                    Label("Change Folder", systemImage: "folder")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(GlassButtonStyle())

                if !viewModel.selectedURLs.isEmpty {
                    Button(action: { viewModel.deselectAll() }) {
                        Label("Clear Selection", systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(GlassButtonStyle())
                }
            }
            .padding(.horizontal, 8)
        }
    }

    @ViewBuilder
    private var sidebarSelectionInfo: some View {
        if !viewModel.selectedURLs.isEmpty {
            Divider().padding(.horizontal, 8)
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 14))
                Text("\(viewModel.selectedURLs.count) selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        ZStack(alignment: .top) {
            // Full-bleed content area
            Color(NSColor.textBackgroundColor)
                .ignoresSafeArea()

            // Image grid/list/columns based on view mode
            Group {
                switch viewModel.viewMode {
                case .grid:
                    ImageGridView2(viewModel: viewModel, sidebarWidth: contentLeadingPadding)
                case .list:
                    ImageListView(viewModel: viewModel)
                        .padding(.leading, contentLeadingPadding)
                        .padding(.top, toolbarAreaHeight)
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
                    .padding(.leading, contentLeadingPadding)
                }
            }

            // Floating toolbar at top-right (aligned with traffic lights)
            floatingToolbar
                .padding(.trailing, 8)
                .padding(.leading, contentLeadingPadding)
        }
    }

    // MARK: - Floating Toolbar (Liquid Glass style)

    @ViewBuilder
    private var floatingToolbar: some View {
        HStack(spacing: 12) {
            toolbarImageCountPill
            toolbarSelectionCountPill
            Spacer()
            toolbarSortMenu
            toolbarViewModePicker
            toolbarEvaluationButton
            toolbarSettingsButton
        }
        .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
    }

    @ViewBuilder
    private var toolbarImageCountPill: some View {
        HStack(spacing: 4) {
            Image(systemName: "photo.stack")
                .font(.system(size: 11))
            Text("\(viewModel.displayedURLs.count)")
                .font(.system(.caption, design: .rounded, weight: .semibold))
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var toolbarSelectionCountPill: some View {
        if !viewModel.selectedURLs.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                Text("\(viewModel.selectedURLs.count)")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
            }
            .foregroundColor(.accentColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private var toolbarSortMenu: some View {
        Menu {
            ForEach(BrowserViewModel.SortOrder.allCases, id: \.self) { order in
                Button(action: {
                    viewModel.sortOrder = order
                    savedSortOrder = order.rawValue
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
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 11))
                Text("Sort")
                    .font(.system(.caption, design: .rounded, weight: .medium))
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
        }
        .menuStyle(.borderlessButton)
    }

    @ViewBuilder
    private var toolbarViewModePicker: some View {
        HStack(spacing: 0) {
            ForEach(BrowserViewModel.ViewMode.allCases, id: \.self) { mode in
                Button(action: {
                    viewModel.viewMode = mode
                    savedViewMode = mode.rawValue
                }) {
                    Image(systemName: mode.icon)
                        .font(.system(size: 12))
                        .frame(width: 28, height: 24)
                        .background(viewModel.viewMode == mode ? Color.accentColor : Color.clear)
                        .foregroundColor(viewModel.viewMode == mode ? .white : .primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(mode.rawValue)
            }
        }
        .padding(3)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var toolbarEvaluationButton: some View {
        if evaluationManager.isProcessing {
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
                Text("Evaluating")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                Button(action: { evaluationManager.cancelEvaluation() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.8))
            .clipShape(Capsule())
        } else if !viewModel.selectedURLs.isEmpty {
            Button(action: { evaluateSelectedImages() }) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                    Text("Evaluate")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentColor)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Evaluate selected images with AI")
        }
    }

    @ViewBuilder
    private var toolbarSettingsButton: some View {
        Button(action: { showingSettings = true }) {
            Image(systemName: "gear")
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .frame(width: 28, height: 28)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Settings")
    }

    // MARK: - Evaluation

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    private func timestamp() -> String {
        Self.timestampFormatter.string(from: Date())
    }

    private func evaluateSelectedImages() {
        let urls = Array(viewModel.selectedURLs)
        let folderURL = viewModel.currentFolder
        Task {
            print("⏱️ [\(timestamp())] Starting evaluation for \(urls.count) images...")
            await evaluationManager.addImages(urls: urls, folderURL: folderURL)
            do {
                print("⏱️ [\(timestamp())] Calling startEvaluation...")
                try await evaluationManager.startEvaluation()
                print("⏱️ [\(timestamp())] startEvaluation returned, updating cache...")
                // Efficiently update cache only for evaluated URLs
                viewModel.updateEvaluationCache(for: urls)
                print("⏱️ [\(timestamp())] Cache update complete")
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

// MARK: - Glass Button Style

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(configuration.isPressed ?
                Color.white.opacity(0.15) :
                Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
    }
}

// MARK: - Preview

#Preview {
    ImageBrowserView2()
        .frame(width: 1200, height: 800)
}
