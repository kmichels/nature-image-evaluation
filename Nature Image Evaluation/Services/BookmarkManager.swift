//
//  BookmarkManager.swift
//  Nature Image Evaluation
//
//  Created by Claude Code on 10/27/25.
//

import Foundation
import AppKit

/// Manages security-scoped bookmarks for persistent file access
final class BookmarkManager {

    static let shared = BookmarkManager()

    private init() {}

    // MARK: - Bookmark Creation

    /// Create a security-scoped bookmark from a URL
    /// - Parameter url: The URL to create a bookmark for
    /// - Returns: Bookmark data that can be stored
    func createBookmark(for url: URL) throws -> Data {
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            return bookmarkData
        } catch {
            throw BookmarkError.creationFailed(error)
        }
    }

    /// Create a bookmark with write access (for archive locations)
    /// - Parameter url: The URL to create a bookmark for
    /// - Returns: Bookmark data that can be stored
    func createWritableBookmark(for url: URL) throws -> Data {
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            return bookmarkData
        } catch {
            throw BookmarkError.creationFailed(error)
        }
    }

    // MARK: - Bookmark Resolution

    /// Resolve a bookmark to a URL
    /// - Parameter bookmarkData: The bookmark data to resolve
    /// - Returns: Tuple with resolved URL and whether bookmark is stale
    func resolveBookmark(from bookmarkData: Data) throws -> (url: URL, isStale: Bool) {
        var isStale = false

        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            return (url, isStale)
        } catch {
            throw BookmarkError.resolutionFailed(error)
        }
    }

    // MARK: - Security Scope Access

    /// Access a security-scoped resource
    /// - Parameters:
    ///   - url: The URL to access (must be from resolved bookmark)
    ///   - perform: The work to perform with the accessed resource
    func accessResource<T>(at url: URL, perform: (URL) throws -> T) throws -> T {
        guard url.startAccessingSecurityScopedResource() else {
            throw BookmarkError.accessDenied
        }

        defer {
            url.stopAccessingSecurityScopedResource()
        }

        return try perform(url)
    }

    /// Access a resource from bookmark data
    /// - Parameters:
    ///   - bookmarkData: The bookmark data
    ///   - perform: The work to perform with the accessed resource
    func accessResource<T>(from bookmarkData: Data, perform: (URL) throws -> T) throws -> T {
        let (url, isStale) = try resolveBookmark(from: bookmarkData)

        if isStale {
            print("Warning: Bookmark is stale for URL: \(url)")
        }

        return try accessResource(at: url, perform: perform)
    }

    // MARK: - Bookmark Validation

    /// Check if a bookmark is still valid
    /// - Parameter bookmarkData: The bookmark data to check
    /// - Returns: true if bookmark is valid and not stale
    func isBookmarkValid(_ bookmarkData: Data) -> Bool {
        do {
            let (_, isStale) = try resolveBookmark(from: bookmarkData)
            return !isStale
        } catch {
            return false
        }
    }

    /// Refresh a stale bookmark if possible
    /// - Parameters:
    ///   - bookmarkData: The stale bookmark data
    ///   - url: The current URL if known
    /// - Returns: New bookmark data if refresh successful
    func refreshBookmark(_ bookmarkData: Data, url: URL? = nil) throws -> Data? {
        // Try to resolve the bookmark first
        let resolvedURL: URL
        if let url = url {
            resolvedURL = url
        } else {
            let (url, _) = try resolveBookmark(from: bookmarkData)
            resolvedURL = url
        }

        // Check if the file still exists
        guard FileManager.default.fileExists(atPath: resolvedURL.path) else {
            throw BookmarkError.fileNotFound
        }

        // Try to create a new bookmark
        return try? createBookmark(for: resolvedURL)
    }
}

// MARK: - Bookmark Error

enum BookmarkError: LocalizedError {
    case creationFailed(Error)
    case resolutionFailed(Error)
    case accessDenied
    case fileNotFound
    case staleBookmark

    var errorDescription: String? {
        switch self {
        case .creationFailed(let error):
            return "Failed to create bookmark: \(error.localizedDescription)"
        case .resolutionFailed(let error):
            return "Failed to resolve bookmark: \(error.localizedDescription)"
        case .accessDenied:
            return "Access to the security-scoped resource was denied"
        case .fileNotFound:
            return "The bookmarked file no longer exists"
        case .staleBookmark:
            return "The bookmark is stale and needs to be refreshed"
        }
    }
}