//
//  ThumbnailGenerator.swift
//  Nature Image Evaluation
//
//  Created by Claude on 11/14/25.
//

import AppKit
import CoreData
import Foundation

@MainActor
class ThumbnailGenerator {
    static let shared = ThumbnailGenerator()
    private let imageProcessor = ImageProcessor.shared

    private init() {}

    /// Generate thumbnail for an ImageEvaluation if it doesn't have one
    func ensureThumbnail(for evaluation: ImageEvaluation, context: NSManagedObjectContext) async -> Data? {
        // Return existing thumbnail if available
        if let existingThumbnail = evaluation.thumbnailData {
            return existingThumbnail
        }

        // Try to generate from processed image path (stored as file path string)
        if let processedPath = evaluation.processedFilePath {
            let url = URL(fileURLWithPath: processedPath)
            if FileManager.default.fileExists(atPath: url.path) {
                return await generateAndSaveThumbnail(from: url, for: evaluation, context: context)
            }
        }

        // Try to generate from original file path (stored as bookmark data)
        if let bookmarkData = evaluation.originalFilePath {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)

                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    return await generateAndSaveThumbnail(from: url, for: evaluation, context: context)
                }
            } catch {
                print("Failed to resolve bookmark for thumbnail generation: \(error)")
            }
        }

        return nil
    }

    /// Generate thumbnail from file URL and save to Core Data
    private func generateAndSaveThumbnail(from url: URL, for evaluation: ImageEvaluation, context: NSManagedObjectContext) async -> Data? {
        let evaluationID = evaluation.objectID

        return await Task.detached(priority: .background) {
            guard let imageData = self.readImageData(from: url) else { return nil }
            guard let thumbnailData = await self.createThumbnailData(from: imageData, url: url) else { return nil }

            await self.saveThumbnail(thumbnailData, evaluationID: evaluationID, context: context)
            return thumbnailData
        }.value
    }

    // MARK: - Thumbnail Generation Helpers

    /// Read image data from URL with size limit check
    private nonisolated func readImageData(from url: URL) -> Data? {
        do {
            let fileHandle = try FileHandle(forReadingFrom: url)
            defer { try? fileHandle.close() }

            let maxSize: UInt64 = 100_000_000 // 100MB limit
            let fileSize = try fileHandle.seekToEnd()
            guard fileSize <= maxSize else {
                print("Image file too large for thumbnail generation: \(fileSize) bytes")
                return nil
            }

            try fileHandle.seek(toOffset: 0)
            return autoreleasepool { fileHandle.readDataToEndOfFile() }
        } catch {
            print("Error reading image file: \(error)")
            return nil
        }
    }

    /// Create thumbnail data from image data
    private func createThumbnailData(from imageData: Data, url: URL) -> Data? {
        autoreleasepool {
            guard let image = NSImage(data: imageData) else {
                print("Failed to create image from data: \(url.path)")
                return nil
            }

            guard let thumbnail = imageProcessor.generateThumbnail(image: image) else {
                print("Failed to generate thumbnail for: \(url.path)")
                return nil
            }

            return imageProcessor.thumbnailToData(thumbnail)
        }
    }

    /// Save thumbnail to Core Data
    private nonisolated func saveThumbnail(_ data: Data, evaluationID: NSManagedObjectID, context: NSManagedObjectContext) async {
        await context.perform {
            if let evaluation = try? context.existingObject(with: evaluationID) as? ImageEvaluation {
                evaluation.thumbnailData = data
                try? context.save()
            }
        }
    }

    /// Batch generate thumbnails for multiple evaluations
    func generateMissingThumbnails(for evaluations: [ImageEvaluation], context: NSManagedObjectContext) async {
        // Process in batches to avoid overwhelming the system
        let batchSize = 5
        let evaluationsNeedingThumbnails = evaluations.filter { $0.thumbnailData == nil }

        for i in stride(from: 0, to: evaluationsNeedingThumbnails.count, by: batchSize) {
            let endIndex = min(i + batchSize, evaluationsNeedingThumbnails.count)
            let batch = Array(evaluationsNeedingThumbnails[i ..< endIndex])

            // Process batch concurrently
            await withTaskGroup(of: Void.self) { group in
                for evaluation in batch {
                    group.addTask {
                        _ = await self.ensureThumbnail(for: evaluation, context: context)
                    }
                }
            }

            // Small delay between batches to prevent overloading
            if endIndex < evaluationsNeedingThumbnails.count {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
    }
}
