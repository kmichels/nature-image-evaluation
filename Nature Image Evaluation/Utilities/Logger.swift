//
//  Logger.swift
//  Nature Image Evaluation
//
//  Created by Claude Code on 11/17/25.
//

import Foundation
import os.log

/// Centralized logging utility using Apple's unified logging system
struct AppLogger {

    // MARK: - Log Categories

    /// API related logging (requests, responses, errors)
    static let api = Logger(subsystem: "com.natureimageeval", category: "API")

    /// Evaluation process logging (start, progress, completion)
    static let evaluation = Logger(subsystem: "com.natureimageeval", category: "Evaluation")

    /// Storage operations (file I/O, Core Data, thumbnails)
    static let storage = Logger(subsystem: "com.natureimageeval", category: "Storage")

    /// User interface events and interactions
    static let ui = Logger(subsystem: "com.natureimageeval", category: "UI")

    /// Image processing operations
    static let imageProcessing = Logger(subsystem: "com.natureimageeval", category: "ImageProcessing")

    /// Saliency analysis operations
    static let saliency = Logger(subsystem: "com.natureimageeval", category: "Saliency")

    /// Technical analysis operations
    static let technical = Logger(subsystem: "com.natureimageeval", category: "Technical")

    /// General app lifecycle and configuration
    static let app = Logger(subsystem: "com.natureimageeval", category: "App")

    // MARK: - Helper Methods

    /// Log API key validation (without exposing the key)
    static func logAPIKeyValidation(provider: String, isValid: Bool, error: String? = nil) {
        if isValid {
            api.info("✅ \(provider) API key validated successfully")
        } else {
            api.error("❌ \(provider) API key validation failed: \(error ?? "Unknown error")")
        }
    }

    /// Log evaluation start
    static func logEvaluationStart(imageCount: Int, batchSize: Int) {
        evaluation.info("🚀 Starting evaluation of \(imageCount) images in batches of \(batchSize)")
    }

    /// Log evaluation progress
    static func logEvaluationProgress(current: Int, total: Int, imageName: String) {
        evaluation.debug("📊 Evaluating image \(current)/\(total): \(imageName)")
    }

    /// Log evaluation completion
    static func logEvaluationComplete(successful: Int, failed: Int, duration: TimeInterval) {
        evaluation.info("✅ Evaluation complete: \(successful) successful, \(failed) failed in \(String(format: "%.1f", duration))s")
    }

    /// Log file operation
    static func logFileOperation(operation: String, path: String, success: Bool, size: Int64? = nil) {
        if success {
            if let size = size {
                storage.debug("📁 \(operation) at \(path) (\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)))")
            } else {
                storage.debug("📁 \(operation) at \(path)")
            }
        } else {
            storage.error("❌ Failed to \(operation) at \(path)")
        }
    }

    /// Log Core Data operation
    static func logCoreDataOperation(operation: String, entityName: String, count: Int? = nil, error: Error? = nil) {
        if let error = error {
            storage.error("❌ Core Data \(operation) failed for \(entityName): \(error.localizedDescription)")
        } else if let count = count {
            storage.debug("💾 Core Data \(operation) for \(entityName): \(count) objects")
        } else {
            storage.debug("💾 Core Data \(operation) for \(entityName)")
        }
    }

    /// Log UI interaction
    static func logUIEvent(_ event: String, details: String? = nil) {
        if let details = details {
            ui.debug("👆 \(event): \(details)")
        } else {
            ui.debug("👆 \(event)")
        }
    }

    /// Log saliency analysis
    static func logSaliencyAnalysis(imageName: String, duration: TimeInterval, success: Bool) {
        if success {
            saliency.debug("🎯 Saliency analysis completed for \(imageName) in \(String(format: "%.2f", duration))s")
        } else {
            saliency.error("❌ Saliency analysis failed for \(imageName)")
        }
    }

    /// Log technical analysis results
    static func logTechnicalAnalysis(imageName: String, sharpness: Float, blur: String, duration: TimeInterval) {
        technical.debug("🔬 Technical analysis for \(imageName): sharpness=\(String(format: "%.1f", sharpness)), blur=\(blur) in \(String(format: "%.2f", duration))s")
    }

    /// Log memory warning
    static func logMemoryWarning(availableMemory: Int64? = nil) {
        if let memory = availableMemory {
            app.warning("⚠️ Memory warning - Available: \(ByteCountFormatter.string(fromByteCount: memory, countStyle: .memory))")
        } else {
            app.warning("⚠️ Memory warning received")
        }
    }

    /// Log app lifecycle event
    static func logAppEvent(_ event: String) {
        app.info("📱 App event: \(event)")
    }

    /// Log network event with sanitized information
    static func logNetworkEvent(type: String, url: String, statusCode: Int? = nil, error: Error? = nil) {
        // Sanitize URL to not expose API keys
        let sanitizedURL = url.replacingOccurrences(
            of: #"sk-[a-zA-Z0-9_-]+"#,
            with: "[REDACTED]",
            options: .regularExpression
        )

        if let error = error {
            api.error("🌐 \(type) failed for \(sanitizedURL): \(error.localizedDescription)")
        } else if let code = statusCode {
            if code >= 200 && code < 300 {
                api.debug("🌐 \(type) successful for \(sanitizedURL) (HTTP \(code))")
            } else {
                api.warning("🌐 \(type) for \(sanitizedURL) returned HTTP \(code)")
            }
        } else {
            api.debug("🌐 \(type) for \(sanitizedURL)")
        }
    }
}

// MARK: - Convenience Extensions

extension Logger {
    /// Log with automatic error level detection
    func logResult<T>(_ message: String, result: Result<T, Error>) {
        switch result {
        case .success:
            self.info("\(message): Success")
        case .failure(let error):
            self.error("\(message): Failed - \(error.localizedDescription)")
        }
    }
}

// MARK: - Performance Logging

extension AppLogger {
    /// Measure and log the execution time of a block
    static func measureTime<T>(
        category: Logger,
        operation: String,
        block: () throws -> T
    ) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            category.debug("⏱ \(operation) completed in \(String(format: "%.3f", duration))s")
        }
        return try block()
    }

    /// Measure and log the async execution time
    static func measureTimeAsync<T>(
        category: Logger,
        operation: String,
        block: () async throws -> T
    ) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            category.debug("⏱ \(operation) completed in \(String(format: "%.3f", duration))s")
        }
        return try await block()
    }
}