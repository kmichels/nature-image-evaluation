//
//  PersistenceController.swift
//  Nature Image Evaluation
//
//  Created by Konrad Michels on 10/27/25.
//

import CoreData

struct PersistenceController {
    @MainActor
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        // Create sample data for previews
        for i in 0..<5 {
            let imageEval = ImageEvaluation(context: viewContext)
            imageEval.id = UUID()
            imageEval.dateAdded = Date().addingTimeInterval(TimeInterval(-i * 86400))
            imageEval.originalFilePath = "bookmark_data_\(i)".data(using: .utf8)
            imageEval.processedFilePath = "/path/to/processed/image_\(i).jpg"
            imageEval.originalWidth = 4000
            imageEval.originalHeight = 3000
            imageEval.processedWidth = 1568
            imageEval.processedHeight = 1176
            imageEval.aspectRatio = 4.0 / 3.0
            imageEval.fileSize = 2_500_000
            imageEval.evaluationCount = 1
            imageEval.dateLastEvaluated = Date().addingTimeInterval(TimeInterval(-i * 86400))

            let result = EvaluationResult(context: viewContext)
            result.id = UUID()
            result.evaluationDate = Date().addingTimeInterval(TimeInterval(-i * 86400))
            result.compositionScore = Double.random(in: 6.0...9.5)
            result.qualityScore = Double.random(in: 6.0...9.5)
            result.sellabilityScore = Double.random(in: 5.0...9.0)
            result.artisticScore = Double.random(in: 6.0...9.5)
            result.overallWeightedScore = (result.compositionScore * 0.30 +
                                          result.qualityScore * 0.25 +
                                          result.sellabilityScore * 0.25 +
                                          result.artisticScore * 0.20)
            result.primaryPlacement = result.overallWeightedScore >= 8.0 ? "PORTFOLIO" : "STORE"
            result.strengths = ["Strong composition", "Excellent lighting", "Good color palette"]
            result.improvements = ["Could benefit from slightly tighter framing"]
            result.marketComparison = "Similar to popular landscape prints"
            result.inputTokens = 1200
            result.outputTokens = 450
            result.estimatedCost = 0.025
            result.rawAIResponse = "{\"composition_score\": \(result.compositionScore)}"

            // Add new provider fields
            result.provider = "Anthropic"
            result.modelIdentifier = "claude-sonnet-4-5"
            result.modelDisplayName = "Claude 4.5 Sonnet"
            result.evaluationStatus = "completed"
            result.evaluationSource = "manual"
            result.isCurrentEvaluation = true
            result.evaluationIndex = 1
            // Set up the new relationships
            result.imageEvaluation = imageEval
            imageEval.currentEvaluation = result
            if imageEval.evaluationHistory == nil {
                imageEval.evaluationHistory = NSSet()
            }
            // Use mutableSetValue for Core Data relationship manipulation
            let history = imageEval.mutableSetValue(forKey: "evaluationHistory")
            history.add(result)
        }

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        // Use programmatic model instead of .xcdatamodeld file
        let model = CoreDataModel.createModel()
        container = NSPersistentContainer(name: "Nature_Image_Evaluation", managedObjectModel: model)

        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }

        // Create local reference to container for closure
        let localContainer = container

        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                print("Core Data error: \(error), \(error.userInfo)")

                #if DEBUG
                // Try to delete and recreate the store for development
                if let storeURL = storeDescription.url {
                    try? FileManager.default.removeItem(at: storeURL)
                    print("Deleted old store, creating fresh one...")

                    // Try again with fresh store
                    localContainer.loadPersistentStores { _, retryError in
                        if let retryError = retryError {
                            fatalError("Could not create fresh store: \(retryError)")
                        }
                    }
                }
                #else
                // In production, don't delete data - show proper error
                fatalError("""
                    Core Data store is corrupted and cannot be loaded.
                    Please contact support at https://github.com/kmichels/nature-image-evaluation/issues
                    Error: \(error.localizedDescription)
                    """)
                #endif
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
