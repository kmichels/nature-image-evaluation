//
//  FolderManager.swift
//  Nature Image Evaluation
//
//  Created by Claude on 11/12/25.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Represents a monitored folder in the sidebar
struct MonitoredFolder: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let bookmarkData: Data  // Security-scoped bookmark
    let dateAdded: Date
    var color: String  // Store as string for Codable

    init(url: URL, color: Color = .blue) throws {
        self.id = UUID()
        self.name = url.lastPathComponent
        self.dateAdded = Date()
        self.color = color.description

        // Create security-scoped bookmark for persistent access
        self.bookmarkData = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    /// Resolves the bookmark to get the actual URL
    func resolveURL() throws -> URL {
        var isStale = false
        let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)

        if isStale {
            throw FolderError.staleBookmark
        }

        return url
    }
}

enum FolderError: LocalizedError {
    case invalidURL
    case accessDenied
    case staleBookmark
    case notADirectory

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid folder URL"
        case .accessDenied: return "Access denied to this folder"
        case .staleBookmark: return "Folder reference is stale and needs to be re-added"
        case .notADirectory: return "Selected item is not a folder"
        }
    }
}

@Observable
final class FolderManager {
    static let shared = FolderManager()

    private(set) var folders: [MonitoredFolder] = []
    private let storageKey = "MonitoredFolders"

    private init() {
        loadFolders()
    }

    // MARK: - Public Methods

    func addFolder(at url: URL) throws {
        // Verify it's a directory
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw FolderError.notADirectory
        }

        // Check if already monitoring this folder
        if folders.contains(where: { folder in
            if let existingURL = try? folder.resolveURL() {
                return existingURL.path == url.path
            }
            return false
        }) {
            return  // Already monitoring this folder
        }

        let folder = try MonitoredFolder(url: url)
        folders.append(folder)
        saveFolders()
    }

    func removeFolder(_ folder: MonitoredFolder) {
        folders.removeAll { $0.id == folder.id }
        saveFolders()
    }

    func scanFolder(_ folder: MonitoredFolder) throws -> [URL] {
        let url = try folder.resolveURL()

        // Note: The caller is responsible for managing security scope access
        // This allows the caller to keep access open for the duration needed

        // Get all image files in the folder
        let imageTypes: [UTType] = [.image, .png, .jpeg, .heic, .tiff, .rawImage]
        let contents = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.contentTypeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        let imageFiles = contents.filter { fileURL in
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.contentTypeKey, .isRegularFileKey]),
                  let isRegularFile = resourceValues.isRegularFile,
                  isRegularFile,
                  let contentType = resourceValues.contentType else {
                return false
            }

            return imageTypes.contains { imageType in
                contentType.conforms(to: imageType)
            }
        }

        return imageFiles.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    // MARK: - Private Methods

    private func loadFolders() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([MonitoredFolder].self, from: data) else {
            return
        }

        // Filter out any folders with stale bookmarks
        folders = decoded.filter { folder in
            do {
                _ = try folder.resolveURL()
                return true
            } catch {
                print("Removing stale folder: \(folder.name)")
                return false
            }
        }
    }

    private func saveFolders() {
        guard let data = try? JSONEncoder().encode(folders) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}