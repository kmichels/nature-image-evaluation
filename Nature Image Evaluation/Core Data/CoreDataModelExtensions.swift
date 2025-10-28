//
//  CoreDataModelExtensions.swift
//  Nature Image Evaluation
//
//  Created by Claude Code on 10/28/25.
//
//  Extensions for Core Data entities to support evaluation history
//  and multi-provider functionality
//

import Foundation
import CoreData

// MARK: - ImageEvaluation Extensions

extension ImageEvaluation {

    /// Computed property to get all evaluations sorted by date
    var sortedEvaluationHistory: [EvaluationResult] {
        let evaluations = evaluationHistory as? Set<EvaluationResult> ?? []
        return evaluations.sorted { $0.evaluationDate ?? Date() > $1.evaluationDate ?? Date() }
    }

    /// Get the most recent evaluation (may differ from currentEvaluation if user selected different one)
    var latestEvaluation: EvaluationResult? {
        sortedEvaluationHistory.first
    }

    /// Check if image has failed evaluations
    var hasFailedEvaluations: Bool {
        sortedEvaluationHistory.contains { $0.evaluationStatus == "failed" }
    }

    /// Get evaluations from a specific provider
    func evaluations(from provider: String) -> [EvaluationResult] {
        sortedEvaluationHistory.filter { $0.provider == provider }
    }

    /// Calculate average score across all evaluations
    var averageScore: Double? {
        let completedEvaluations = sortedEvaluationHistory.filter { $0.evaluationStatus == "completed" }
        guard !completedEvaluations.isEmpty else { return nil }

        let totalScore = completedEvaluations.reduce(0.0) { $0 + $1.overallWeightedScore }
        return totalScore / Double(completedEvaluations.count)
    }

    /// Check if scores are trending up or down
    var scoreTrend: ScoreTrend {
        let completedEvaluations = sortedEvaluationHistory.filter { $0.evaluationStatus == "completed" }
        guard completedEvaluations.count >= 2 else { return .stable }

        let recent = completedEvaluations[0].overallWeightedScore
        let previous = completedEvaluations[1].overallWeightedScore

        if recent > previous + 0.5 {
            return .improving
        } else if recent < previous - 0.5 {
            return .declining
        } else {
            return .stable
        }
    }

    enum ScoreTrend {
        case improving
        case declining
        case stable
    }
}

// MARK: - EvaluationResult Extensions

extension EvaluationResult {

    /// Full display name for the model
    var fullModelName: String {
        "\(provider ?? "Unknown") - \(modelDisplayName ?? modelIdentifier ?? "Unknown Model")"
    }

    /// Check if this is a successful evaluation
    var isSuccessful: Bool {
        evaluationStatus == "completed"
    }

    /// Check if this is a retry of a previous evaluation
    var isRetry: Bool {
        parentEvaluationID != nil
    }

    /// Format the evaluation source for display
    var sourceDisplayName: String {
        switch evaluationSource {
        case "manual":
            return "Manual"
        case "batch":
            return "Batch Import"
        case "retry":
            return "Retry"
        case "comparison":
            return "Comparison"
        case "re-evaluation":
            return "Re-evaluation"
        default:
            return evaluationSource ?? "Unknown"
        }
    }

    /// Calculate score difference from another evaluation
    func scoreDifference(from other: EvaluationResult) -> Double {
        self.overallWeightedScore - other.overallWeightedScore
    }

    /// Get a dictionary of all scores for easy comparison
    var allScores: [String: Double] {
        [
            "Overall": overallWeightedScore,
            "Composition": compositionScore,
            "Quality": qualityScore,
            "Sellability": sellabilityScore,
            "Artistic": artisticScore
        ]
    }

    /// Check if this evaluation used high resolution
    var usedHighResolution: Bool {
        imageResolution >= 2048
    }
}

// MARK: - EvaluationSession Extensions

extension EvaluationSession {

    /// Calculate session duration
    var duration: TimeInterval? {
        guard let end = endDate else { return nil }
        return end.timeIntervalSince(startDate ?? Date())
    }

    /// Get success rate as percentage
    var successRate: Double {
        guard totalImages > 0 else { return 0 }
        return Double(successCount) / Double(totalImages) * 100
    }

    /// Check if session is still running
    var isActive: Bool {
        endDate == nil
    }

    /// Get average cost per image
    var averageCostPerImage: Double {
        guard totalImages > 0 else { return 0 }
        return totalCost / Double(totalImages)
    }

    /// Get all unique providers used in session
    var uniqueProviders: [String] {
        guard let evaluations = evaluations as? Set<EvaluationResult> else { return [] }
        let providers = evaluations.compactMap { $0.provider }
        return Array(Set(providers)).sorted()
    }
}

// MARK: - Evaluation Context

struct EvaluationContext {
    let source: EvaluationSource
    let reason: String?
    let previousScore: Double?
    let promptVersion: String
    let modelVersion: String
    let imageResolution: Int
    let sessionID: UUID?

    static func manual(resolution: Int) -> EvaluationContext {
        return EvaluationContext(
            source: .manual,
            reason: "User requested evaluation",
            previousScore: nil,
            promptVersion: "v1.0",
            modelVersion: Constants.anthropicDefaultModel,
            imageResolution: resolution,
            sessionID: nil
        )
    }

    static func batch(resolution: Int, sessionID: UUID) -> EvaluationContext {
        return EvaluationContext(
            source: .batch,
            reason: "Batch processing",
            previousScore: nil,
            promptVersion: "v1.0",
            modelVersion: Constants.anthropicDefaultModel,
            imageResolution: resolution,
            sessionID: sessionID
        )
    }

    static func retry(previousEvaluation: EvaluationResult, resolution: Int) -> EvaluationContext {
        return EvaluationContext(
            source: .retry,
            reason: "Retry after failure",
            previousScore: previousEvaluation.overallWeightedScore,
            promptVersion: "v1.0",
            modelVersion: Constants.anthropicDefaultModel,
            imageResolution: resolution,
            sessionID: nil
        )
    }
}

enum EvaluationSource: String {
    case manual = "manual"
    case batch = "batch"
    case retry = "retry"
    case reEvaluation = "re-evaluation"
    case comparison = "comparison"
    case scheduled = "scheduled"
}

// MARK: - Migration Helpers

struct CoreDataMigration {

    /// Migrate existing evaluations to new model structure
    static func migrateExistingEvaluations(in context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<ImageEvaluation> = ImageEvaluation.fetchRequest()

        do {
            let images = try context.fetch(fetchRequest)

            for image in images {
                // Skip if already has current evaluation
                if image.currentEvaluation != nil {
                    continue
                }

                // Try to find any existing evaluation in the history
                if let history = image.evaluationHistory as? Set<EvaluationResult>,
                   let existingResult = history.first {

                    // Set provider info for existing evaluation
                    existingResult.provider = "Anthropic"
                    existingResult.modelIdentifier = "claude-sonnet-4-5"
                    existingResult.modelDisplayName = "Claude 4.5 Sonnet"
                    existingResult.evaluationIndex = 1
                    existingResult.evaluationSource = "manual"
                    existingResult.promptVersion = "v1.0"
                    existingResult.imageResolution = 1568 // Default old resolution
                    existingResult.isCurrentEvaluation = true
                    existingResult.evaluationStatus = "completed"

                    // Set relationships
                    image.currentEvaluation = existingResult
                    image.evaluationCount = 1
                    image.firstEvaluatedDate = existingResult.evaluationDate

                    print("Migrated evaluation for image: \(image.id?.uuidString ?? "unknown")")
                }
            }

            try context.save()
            print("Migration completed successfully")

        } catch {
            print("Migration failed: \(error)")
        }
    }
}

// MARK: - Provider Management

struct ProviderInfo {
    let identifier: String
    let displayName: String
    let model: String
    let apiVersion: String

    static let anthropicClaude = ProviderInfo(
        identifier: "Anthropic",
        displayName: "Claude 4.5 Sonnet",
        model: Constants.anthropicDefaultModel,
        apiVersion: "2024-10-01"
    )

    static let openAIGPT4 = ProviderInfo(
        identifier: "OpenAI",
        displayName: "GPT-4 Vision",
        model: "gpt-4-vision-preview",
        apiVersion: "2024-02-01"
    )

    static let googleGemini = ProviderInfo(
        identifier: "Google",
        displayName: "Gemini Pro Vision",
        model: "gemini-pro-vision",
        apiVersion: "v1"
    )
}