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

        // Try to generate from processed image path
        if let processedPath = evaluation.processedFilePath,
           let url = URL(string: processedPath) {
            return await generateAndSaveThumbnail(from: url, for: evaluation, context: context)
        }

        // Try to generate from original file path
        if let originalPath = evaluation.originalFilePath,
           let url = URL(string: originalPath) {
            return await generateAndSaveThumbnail(from: url, for: evaluation, context: context)
        }

        return nil
    }

    /// Generate thumbnail from file URL and save to Core Data
    private func generateAndSaveThumbnail(from url: URL, for evaluation: ImageEvaluation, context: NSManagedObjectContext) async -> Data? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        guard let thumbnail = imageProcessor.generateThumbnail(image: image) else { return nil }
        let thumbnailData = imageProcessor.thumbnailToData(thumbnail)

        // Save to Core Data
        evaluation.thumbnailData = thumbnailData
        try? context.save()

        return thumbnailData
    }

    /// Batch generate thumbnails for multiple evaluations
    func generateMissingThumbnails(for evaluations: [ImageEvaluation], context: NSManagedObjectContext) async {
        for evaluation in evaluations where evaluation.thumbnailData == nil {
            _ = await ensureThumbnail(for: evaluation, context: context)
        }
    }
}