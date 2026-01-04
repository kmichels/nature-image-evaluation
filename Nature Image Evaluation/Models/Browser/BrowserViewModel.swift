//
//  BrowserViewModel.swift
//  Nature Image Evaluation
//
//  Created on December 2025 during UI rebuild
//  Pure SwiftUI approach - no NSViewRepresentable
//

import CoreData
import Observation
import SwiftUI
import UniformTypeIdentifiers

@Observable
final class BrowserViewModel {
    // MARK: - Properties

    // Current folder being browsed
    var currentFolder: URL?

    // Security-scoped access to current folder
    private var folderAccessToken: Bool = false

    // All image URLs in current folder
    private(set) var imageURLs: [URL] = []

    // Filtered/sorted URLs for display
    private(set) var displayedURLs: [URL] = []

    // Selection state
    var selectedURLs: Set<URL> = []
    var lastSelectedURL: URL?
    var anchorURL: URL? // For range selection

    // View options
    var viewMode: ViewMode = .grid
    var thumbnailSize: CGFloat = 150
    var sortOrder: SortOrder = .name
    var showOnlyEvaluated: Bool = false

    // Thumbnail cache
    private var thumbnailCache: [URL: NSImage] = [:]

    // Core Data context for checking evaluations
    private let viewContext: NSManagedObjectContext

    // MARK: - Types

    enum ViewMode: String, CaseIterable {
        case grid = "Grid"
        case list = "List"
        case columns = "Columns"

        var icon: String {
            switch self {
            case .grid: return "square.grid.3x3"
            case .list: return "list.bullet"
            case .columns: return "rectangle.grid.1x2"
            }
        }
    }

    enum SortOrder: String, CaseIterable {
        case name = "Name"
        case dateModified = "Date Modified"
        case size = "Size"
        case score = "Overall Score"
        case artisticScore = "Artistic Score"
        case commercialScore = "Commercial Score"
    }

    // MARK: - Initialization

    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
    }

    // MARK: - Folder Loading

    func loadFolder(_ url: URL) async {
        // Stop previous folder access if any
        if folderAccessToken, let oldFolder = currentFolder {
            oldFolder.stopAccessingSecurityScopedResource()
            folderAccessToken = false
        }

        // Start accessing the new folder
        folderAccessToken = url.startAccessingSecurityScopedResource()

        currentFolder = url

        // Load image URLs from folder
        let urls = await Task.detached(priority: .userInitiated) {
            // Run file system operations synchronously in detached task
            Self.findImageURLsStatic(in: url)
        }.value

        // Update UI on main actor
        imageURLs = urls
        applyFiltersAndSorting()

        // Clear selection when changing folders
        selectedURLs.removeAll()
        lastSelectedURL = nil
        anchorURL = nil

        // Refresh evaluation cache for this folder
        refreshEvaluationCache()
    }

    deinit {
        // Clean up security-scoped access
        if folderAccessToken, let folder = currentFolder {
            folder.stopAccessingSecurityScopedResource()
        }
    }

    private nonisolated static func findImageURLsStatic(in folder: URL) -> [URL] {
        let imageTypes = [UTType.jpeg, .png, .heic, .tiff, .bmp, .gif, .webP]
        let typeIdentifiers = imageTypes.compactMap { $0.identifier }

        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey, .typeIdentifierKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var urls: [URL] = []
        for case let url as URL in enumerator {
            do {
                let values = try url.resourceValues(forKeys: [.isRegularFileKey, .typeIdentifierKey])
                if let isRegular = values.isRegularFile, isRegular,
                   let typeID = values.typeIdentifier,
                   typeIdentifiers.contains(typeID)
                {
                    urls.append(url)
                }
            } catch {
                continue
            }
        }

        return urls
    }

    // MARK: - Filtering and Sorting

    func applyFiltersAndSorting() {
        var filtered = imageURLs

        // Apply filters
        if showOnlyEvaluated {
            filtered = filtered.filter { hasEvaluation(for: $0) }
        }

        // Apply sorting
        switch sortOrder {
        case .name:
            filtered.sort { $0.lastPathComponent < $1.lastPathComponent }
        case .dateModified:
            filtered.sort { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                return date1 > date2
            }
        case .size:
            filtered.sort { url1, url2 in
                let size1 = (try? url1.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                let size2 = (try? url2.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                return size1 > size2
            }
        case .score:
            // Sort by overall evaluation score if available
            filtered.sort { url1, url2 in
                let score1 = getEvaluationScore(for: url1) ?? -1
                let score2 = getEvaluationScore(for: url2) ?? -1
                return score1 > score2
            }
        case .artisticScore:
            // Sort by artistic score
            filtered.sort { url1, url2 in
                let score1 = getArtisticScore(for: url1) ?? -1
                let score2 = getArtisticScore(for: url2) ?? -1
                return score1 > score2
            }
        case .commercialScore:
            // Sort by commercial/sellability score
            filtered.sort { url1, url2 in
                let score1 = getCommercialScore(for: url1) ?? -1
                let score2 = getCommercialScore(for: url2) ?? -1
                return score1 > score2
            }
        }

        displayedURLs = filtered
    }

    // MARK: - Selection Management

    func handleSelection(of url: URL, modifiers: EventModifiers) {
        if modifiers.contains(.command) {
            // Toggle selection
            if selectedURLs.contains(url) {
                selectedURLs.remove(url)
            } else {
                selectedURLs.insert(url)
                lastSelectedURL = url
            }
        } else if modifiers.contains(.shift), let anchor = anchorURL ?? lastSelectedURL {
            // Range selection
            selectRange(from: anchor, to: url)
        } else {
            // Single selection
            selectedURLs = [url]
            lastSelectedURL = url
            anchorURL = url
        }
    }

    private func selectRange(from start: URL, to end: URL) {
        guard let startIndex = displayedURLs.firstIndex(of: start),
              let endIndex = displayedURLs.firstIndex(of: end) else { return }

        let range = min(startIndex, endIndex) ... max(startIndex, endIndex)
        let urlsInRange = range.map { displayedURLs[$0] }

        selectedURLs = Set(urlsInRange)
        lastSelectedURL = end
    }

    func selectAll() {
        selectedURLs = Set(displayedURLs)
        lastSelectedURL = displayedURLs.last
    }

    func deselectAll() {
        selectedURLs.removeAll()
        lastSelectedURL = nil
        anchorURL = nil
    }

    // MARK: - Keyboard Navigation

    func navigateSelection(direction: NavigationDirection) {
        guard !displayedURLs.isEmpty else { return }

        let currentIndex: Int
        if let last = lastSelectedURL, let index = displayedURLs.firstIndex(of: last) {
            currentIndex = index
        } else {
            currentIndex = -1
        }

        let newIndex: Int
        switch direction {
        case .up:
            newIndex = max(0, currentIndex - itemsPerRow())
        case .down:
            newIndex = min(displayedURLs.count - 1, currentIndex + itemsPerRow())
        case .left:
            newIndex = max(0, currentIndex - 1)
        case .right:
            newIndex = min(displayedURLs.count - 1, currentIndex + 1)
        }

        if newIndex >= 0, newIndex < displayedURLs.count {
            let url = displayedURLs[newIndex]
            selectedURLs = [url]
            lastSelectedURL = url
            anchorURL = url
        }
    }

    private func itemsPerRow() -> Int {
        // Calculate based on window width and thumbnail size
        // This is a simple estimate - can be refined
        let windowWidth: CGFloat = 1200 // Default estimate
        let itemWidth = thumbnailSize + 40 // Include padding
        return max(1, Int(windowWidth / itemWidth))
    }

    enum NavigationDirection {
        case up, down, left, right
    }

    // MARK: - Thumbnails

    func thumbnail(for url: URL) -> NSImage? {
        if let cached = thumbnailCache[url] {
            return cached
        }

        // Return nil - let the view handle async loading
        return nil
    }

    func cacheThumbnail(_ image: NSImage, for url: URL) {
        thumbnailCache[url] = image

        // Limit cache size
        if thumbnailCache.count > 500 {
            // Remove oldest entries (simple FIFO for now)
            let toRemove = thumbnailCache.count - 400
            for item in thumbnailCache.keys.prefix(toRemove) {
                thumbnailCache.removeValue(forKey: item)
            }
        }
    }

    // MARK: - Core Data Integration

    /// Cache of URL path to ImageEvaluation for quick lookups
    private var evaluationCache: [String: ImageEvaluation] = [:]

    /// Refresh the evaluation cache for current folder
    func refreshEvaluationCache() {
        evaluationCache.removeAll()

        let request = NSFetchRequest<ImageEvaluation>(entityName: "ImageEvaluation")
        request.predicate = NSPredicate(format: "processedFilePath != nil")
        // Prefetch related objects to avoid lazy loading delays
        request.relationshipKeyPathsForPrefetching = ["currentEvaluation", "evaluationHistory"]

        do {
            let evaluations = try viewContext.fetch(request)
            for eval in evaluations {
                // Try to resolve original file path from bookmark
                if let bookmarkData = eval.originalFilePath,
                   let resolvedURL = resolveBookmark(bookmarkData)
                {
                    evaluationCache[resolvedURL.path] = eval
                }
            }
        } catch {
            print("Error fetching evaluations: \(error)")
        }
    }

    /// Directly add an evaluation to the cache (most efficient - no Core Data fetch needed)
    func addToEvaluationCache(url: URL, evaluation: ImageEvaluation) {
        evaluationCache[url.path] = evaluation
    }

    /// Batch update cache for multiple URLs by fetching only those specific evaluations
    func updateEvaluationCache(for urls: [URL]) {
        print("🔄 [\(timestamp())] updateEvaluationCache starting for \(urls.count) URLs...")

        // Refresh context to get latest data
        print("🔄 [\(timestamp())] Refreshing context...")
        viewContext.refreshAllObjects()

        let urlPaths = Set(urls.map { $0.path })

        let request = NSFetchRequest<ImageEvaluation>(entityName: "ImageEvaluation")
        request.predicate = NSPredicate(format: "processedFilePath != nil")
        // Prefetch related objects to avoid lazy loading delays
        request.relationshipKeyPathsForPrefetching = ["currentEvaluation", "evaluationHistory"]

        do {
            print("🔄 [\(timestamp())] Fetching evaluations...")
            let evaluations = try viewContext.fetch(request)
            print("🔄 [\(timestamp())] Fetched \(evaluations.count) evaluations, resolving bookmarks...")

            var matchCount = 0
            for eval in evaluations {
                if let bookmarkData = eval.originalFilePath,
                   let resolvedURL = resolveBookmark(bookmarkData),
                   urlPaths.contains(resolvedURL.path)
                {
                    evaluationCache[resolvedURL.path] = eval
                    matchCount += 1
                }
            }
            print("🔄 [\(timestamp())] Cache updated with \(matchCount) matches")
        } catch {
            print("Error updating evaluation cache: \(error)")
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    private func timestamp() -> String {
        Self.timestampFormatter.string(from: Date())
    }

    /// Resolve bookmark data to URL
    private func resolveBookmark(_ data: Data) -> URL? {
        // Quick check: if data looks like a plain path string (starts with /), use it directly
        // This avoids expensive bookmark resolution attempts for fallback path data
        if data.first == 0x2F { // ASCII '/'
            if let pathString = String(data: data, encoding: .utf8) {
                return URL(fileURLWithPath: pathString)
            }
        }

        // Try as security-scoped bookmark
        var isStale = false
        if let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) {
            return url
        }

        // Final fallback: try as plain path string
        if let pathString = String(data: data, encoding: .utf8) {
            return URL(fileURLWithPath: pathString)
        }

        return nil
    }

    func hasEvaluation(for url: URL) -> Bool {
        return evaluationCache[url.path] != nil
    }

    func getEvaluation(for url: URL) -> ImageEvaluation? {
        return evaluationCache[url.path]
    }

    private func getEvaluationResult(for url: URL) -> EvaluationResult? {
        evaluationCache[url.path]?.currentEvaluation
    }

    func getEvaluationScore(for url: URL) -> Double? {
        getEvaluationResult(for: url)?.overallWeightedScore
    }

    func getEvaluationPlacement(for url: URL) -> String? {
        getEvaluationResult(for: url)?.primaryPlacement
    }

    func getArtisticScore(for url: URL) -> Double? {
        getEvaluationResult(for: url)?.artisticScore
    }

    func getCommercialScore(for url: URL) -> Double? {
        getEvaluationResult(for: url)?.sellabilityScore
    }
}
