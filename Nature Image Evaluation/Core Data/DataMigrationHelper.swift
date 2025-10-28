//
//  DataMigrationHelper.swift
//  Nature Image Evaluation
//
//  Created by Claude Code on 10/28/25.
//
//  Helper to migrate existing data to the new evaluation history model
//

import Foundation
import CoreData

class DataMigrationHelper {

    static let shared = DataMigrationHelper()

    private init() {}

    /// Check if migration is needed and perform it
    func performMigrationIfNeeded(context: NSManagedObjectContext) {
        // Check if we've already migrated
        let migrationKey = "HasMigratedToHistoryModel"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else {
            print("Migration already completed")
            return
        }

        print("Starting migration to history model...")

        do {
            try migrateExistingEvaluations(context: context)
            UserDefaults.standard.set(true, forKey: migrationKey)
            print("Migration completed successfully")
        } catch {
            print("Migration failed: \(error)")
        }
    }

    /// Migrate existing evaluations to support history
    private func migrateExistingEvaluations(context: NSManagedObjectContext) throws {
        let fetchRequest: NSFetchRequest<ImageEvaluation> = ImageEvaluation.fetchRequest()
        let images = try context.fetch(fetchRequest)

        var migratedCount = 0

        for image in images {
            // Skip if already has history (shouldn't happen but be safe)
            if let history = image.evaluationHistory as? Set<EvaluationResult>,
               !history.isEmpty {
                continue
            }

            // If image has old-style evaluationResult
            if let existingResult = image.value(forKey: "evaluationResult") as? EvaluationResult {
                // Set provider info for existing evaluation
                existingResult.provider = "Anthropic"
                existingResult.modelIdentifier = "claude-sonnet-4-5"
                existingResult.modelDisplayName = "Claude 4.5 Sonnet"
                existingResult.apiVersion = "2024-10-01"
                existingResult.evaluationSource = "manual"
                existingResult.promptVersion = "v1.0"
                existingResult.imageResolution = 1568 // Default old resolution
                existingResult.evaluationStatus = "completed"
                existingResult.isCurrentEvaluation = true
                existingResult.evaluationIndex = 1

                // Initialize evaluation history if needed
                if image.evaluationHistory == nil {
                    image.evaluationHistory = NSSet()
                }

                // Add to history
                // Use mutableSetValue for Core Data relationship manipulation
                let history = image.mutableSetValue(forKey: "evaluationHistory")
                history.add(existingResult)

                // Set as current
                image.currentEvaluation = existingResult

                // Set counts and dates
                image.evaluationCount = 1
                image.firstEvaluatedDate = existingResult.evaluationDate
                image.dateLastEvaluated = existingResult.evaluationDate

                migratedCount += 1
                print("Migrated evaluation for image: \(image.id?.uuidString ?? "unknown")")
            }
        }

        // Save changes
        if context.hasChanges {
            try context.save()
            print("Successfully migrated \(migratedCount) evaluations")
        } else {
            print("No evaluations needed migration")
        }
    }

    /// Create default API provider entries (TODO: Enable when APIProvider entity is added)
    func createDefaultProviders(context: NSManagedObjectContext) {
        // Commented out until APIProvider entity is added
        /*
        // Check if providers already exist
        let fetchRequest: NSFetchRequest<APIProvider> = APIProvider.fetchRequest()
        let existingCount = (try? context.count(for: fetchRequest)) ?? 0

        guard existingCount == 0 else {
            print("API providers already configured")
            return
        }

        // Create Anthropic provider
        let anthropic = APIProvider(context: context)
        anthropic.id = UUID()
        anthropic.name = "Anthropic"
        anthropic.displayName = "Claude 4.5 Sonnet"
        anthropic.isEnabled = true
        anthropic.isDefault = true
        anthropic.apiEndpoint = Constants.anthropicAPIURL
        anthropic.currentModel = Constants.anthropicDefaultModel
        anthropic.supportedModels = [Constants.anthropicDefaultModel] as NSArray
        anthropic.totalRequests = 0
        anthropic.totalCost = 0
        anthropic.averageResponseTime = 0
        anthropic.successRate = 0

        // Create OpenAI provider (disabled by default)
        let openai = APIProvider(context: context)
        openai.id = UUID()
        openai.name = "OpenAI"
        openai.displayName = "GPT-4 Vision"
        openai.isEnabled = false
        openai.isDefault = false
        openai.apiEndpoint = Constants.openAIAPIURL
        openai.currentModel = Constants.openAIDefaultModel
        openai.supportedModels = [Constants.openAIDefaultModel] as NSArray
        openai.totalRequests = 0
        openai.totalCost = 0
        openai.averageResponseTime = 0
        openai.successRate = 0

        // Create Google provider placeholder (disabled)
        let google = APIProvider(context: context)
        google.id = UUID()
        google.name = "Google"
        google.displayName = "Gemini Pro Vision"
        google.isEnabled = false
        google.isDefault = false
        google.apiEndpoint = "https://generativelanguage.googleapis.com/v1"
        google.currentModel = "gemini-pro-vision"
        google.supportedModels = ["gemini-pro-vision"] as NSArray
        google.totalRequests = 0
        google.totalCost = 0
        google.averageResponseTime = 0
        google.successRate = 0

        do {
            try context.save()
            print("Created default API providers")
        } catch {
            print("Failed to create providers: \(error)")
        }
        */
        print("APIProvider entity not yet implemented - skipping provider creation")
    }

    /// Clean up orphaned evaluations
    func cleanupOrphanedEvaluations(context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<EvaluationResult> = EvaluationResult.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "imageEvaluation == nil")

        do {
            let orphaned = try context.fetch(fetchRequest)
            if !orphaned.isEmpty {
                print("Found \(orphaned.count) orphaned evaluations")
                for evaluation in orphaned {
                    context.delete(evaluation)
                }
                try context.save()
                print("Cleaned up orphaned evaluations")
            }
        } catch {
            print("Cleanup failed: \(error)")
        }
    }

    /// Run all migration tasks
    func runFullMigration(context: NSManagedObjectContext) {
        performMigrationIfNeeded(context: context)
        createDefaultProviders(context: context)
        cleanupOrphanedEvaluations(context: context)
    }
}