//
//  ThumbnailGenerator.swift
//  Nature Image Evaluation
//
//  Created by Claude on 11/14/25.
//

import Foundation
import AppKit
import CoreData

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

        // Try to generate from original file path (stored as base64 bookmark)
        if let originalPath = evaluation.originalFilePath,
           let bookmarkData = Data(base64Encoded: originalPath) {
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
        // Load image data directly to handle security-scoped URLs properly
        guard let imageData = try? Data(contentsOf: url),
              let image = NSImage(data: imageData) else {
            print("Failed to load image from URL: \(url.path)")
            return nil
        }

        guard let thumbnail = imageProcessor.generateThumbnail(image: image) else {
            print("Failed to generate thumbnail for: \(url.path)")
            return nil
        }

        let thumbnailData = imageProcessor.thumbnailToData(thumbnail)

        // Save to Core Data
        evaluation.thumbnailData = thumbnailData
        try? context.save()

        return thumbnailData
    }

    /// Batch generate thumbnails for multiple evaluations
    func generateMissingThumbnails(for evaluations: [ImageEvaluation], context: NSManagedObjectContext) async {
        // Process in batches to avoid overwhelming the system
        let batchSize = 5
        let evaluationsNeedingThumbnails = evaluations.filter { $0.thumbnailData == nil }

        for i in stride(from: 0, to: evaluationsNeedingThumbnails.count, by: batchSize) {
            let endIndex = min(i + batchSize, evaluationsNeedingThumbnails.count)
            let batch = Array(evaluationsNeedingThumbnails[i..<endIndex])

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