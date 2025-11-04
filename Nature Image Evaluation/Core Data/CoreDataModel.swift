//
//  CoreDataModel.swift
//  Nature Image Evaluation
//
//  Programmatic Core Data Model Definition
//  This replaces the need for .xcdatamodeld file
//

import Foundation
import CoreData

class CoreDataModel {

    static func createModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // MARK: - ImageEvaluation Entity

        let imageEntity = NSEntityDescription()
        imageEntity.name = "ImageEvaluation"
        imageEntity.managedObjectClassName = "ImageEvaluation"

        // Basic Image Properties
        var imageAttributes: [NSAttributeDescription] = []

        imageAttributes.append(createAttribute(name: "id", type: .UUIDAttributeType, optional: true))
        imageAttributes.append(createAttribute(name: "dateAdded", type: .dateAttributeType, optional: true))
        imageAttributes.append(createAttribute(name: "originalFilePath", type: .stringAttributeType, optional: true))
        imageAttributes.append(createAttribute(name: "processedFilePath", type: .stringAttributeType, optional: true))
        imageAttributes.append(createAttribute(name: "thumbnailData", type: .binaryDataAttributeType, optional: true, allowsExternalStorage: true))
        imageAttributes.append(createAttribute(name: "originalWidth", type: .integer32AttributeType, optional: true, defaultValue: 0))
        imageAttributes.append(createAttribute(name: "originalHeight", type: .integer32AttributeType, optional: true, defaultValue: 0))
        imageAttributes.append(createAttribute(name: "processedWidth", type: .integer32AttributeType, optional: true, defaultValue: 0))
        imageAttributes.append(createAttribute(name: "processedHeight", type: .integer32AttributeType, optional: true, defaultValue: 0))
        imageAttributes.append(createAttribute(name: "aspectRatio", type: .doubleAttributeType, optional: true, defaultValue: 0.0))
        imageAttributes.append(createAttribute(name: "fileSize", type: .integer64AttributeType, optional: true, defaultValue: 0))

        // Evaluation Tracking
        imageAttributes.append(createAttribute(name: "dateLastEvaluated", type: .dateAttributeType, optional: true))
        imageAttributes.append(createAttribute(name: "firstEvaluatedDate", type: .dateAttributeType, optional: true))
        imageAttributes.append(createAttribute(name: "evaluationCount", type: .integer32AttributeType, optional: true, defaultValue: 0))

        // User Metadata
        imageAttributes.append(createAttribute(name: "notes", type: .stringAttributeType, optional: true))
        imageAttributes.append(createAttribute(name: "tags", type: .transformableAttributeType, optional: true, transformerName: "NSSecureUnarchiveFromDataTransformer"))
        imageAttributes.append(createAttribute(name: "isFavorite", type: .booleanAttributeType, optional: true, defaultValue: false))
        imageAttributes.append(createAttribute(name: "lastModifiedDate", type: .dateAttributeType, optional: true))

        // Organization Metadata (NEW)
        imageAttributes.append(createAttribute(name: "sourceFolder", type: .stringAttributeType, optional: true))
        imageAttributes.append(createAttribute(name: "importBatch", type: .stringAttributeType, optional: true))
        imageAttributes.append(createAttribute(name: "projectName", type: .stringAttributeType, optional: true))
        imageAttributes.append(createAttribute(name: "originalFileCreationDate", type: .dateAttributeType, optional: true))
        imageAttributes.append(createAttribute(name: "userTags", type: .transformableAttributeType, optional: true, transformerName: "NSSecureUnarchiveFromDataTransformer"))

        imageEntity.properties = imageAttributes

        // MARK: - EvaluationResult Entity

        let evalEntity = NSEntityDescription()
        evalEntity.name = "EvaluationResult"
        evalEntity.managedObjectClassName = "EvaluationResult"

        var evalAttributes: [NSAttributeDescription] = []

        // Core Properties
        evalAttributes.append(createAttribute(name: "id", type: .UUIDAttributeType, optional: true))
        evalAttributes.append(createAttribute(name: "evaluationDate", type: .dateAttributeType, optional: true))

        // Scores
        evalAttributes.append(createAttribute(name: "compositionScore", type: .doubleAttributeType, optional: true, defaultValue: 0.0))
        evalAttributes.append(createAttribute(name: "qualityScore", type: .doubleAttributeType, optional: true, defaultValue: 0.0))
        evalAttributes.append(createAttribute(name: "sellabilityScore", type: .doubleAttributeType, optional: true, defaultValue: 0.0))
        evalAttributes.append(createAttribute(name: "artisticScore", type: .doubleAttributeType, optional: true, defaultValue: 0.0))
        evalAttributes.append(createAttribute(name: "overallWeightedScore", type: .doubleAttributeType, optional: true, defaultValue: 0.0))

        // Evaluation Details
        evalAttributes.append(createAttribute(name: "primaryPlacement", type: .stringAttributeType, optional: true))
        evalAttributes.append(createAttribute(name: "strengths", type: .transformableAttributeType, optional: true, transformerName: "NSSecureUnarchiveFromDataTransformer"))
        evalAttributes.append(createAttribute(name: "improvements", type: .transformableAttributeType, optional: true, transformerName: "NSSecureUnarchiveFromDataTransformer"))
        evalAttributes.append(createAttribute(name: "marketComparison", type: .stringAttributeType, optional: true))
        evalAttributes.append(createAttribute(name: "technicalInnovations", type: .transformableAttributeType, optional: true, transformerName: "NSSecureUnarchiveFromDataTransformer"))
        evalAttributes.append(createAttribute(name: "printSizeRecommendation", type: .stringAttributeType, optional: true))
        evalAttributes.append(createAttribute(name: "priceTierSuggestion", type: .stringAttributeType, optional: true))

        // API Metadata
        evalAttributes.append(createAttribute(name: "inputTokens", type: .integer32AttributeType, optional: true, defaultValue: 0))
        evalAttributes.append(createAttribute(name: "outputTokens", type: .integer32AttributeType, optional: true, defaultValue: 0))
        evalAttributes.append(createAttribute(name: "estimatedCost", type: .doubleAttributeType, optional: true, defaultValue: 0.0))
        evalAttributes.append(createAttribute(name: "rawAIResponse", type: .stringAttributeType, optional: true))

        // Provider Information (NEW)
        evalAttributes.append(createAttribute(name: "provider", type: .stringAttributeType, optional: true, defaultValue: "Anthropic"))
        evalAttributes.append(createAttribute(name: "modelIdentifier", type: .stringAttributeType, optional: true))
        evalAttributes.append(createAttribute(name: "modelDisplayName", type: .stringAttributeType, optional: true))
        evalAttributes.append(createAttribute(name: "apiVersion", type: .stringAttributeType, optional: true))

        // Evaluation Context (NEW)
        evalAttributes.append(createAttribute(name: "evaluationIndex", type: .integer32AttributeType, optional: true, defaultValue: 1))
        evalAttributes.append(createAttribute(name: "evaluationSource", type: .stringAttributeType, optional: true, defaultValue: "manual"))
        evalAttributes.append(createAttribute(name: "promptVersion", type: .stringAttributeType, optional: true, defaultValue: "v1.0"))
        evalAttributes.append(createAttribute(name: "imageResolution", type: .integer32AttributeType, optional: true, defaultValue: 2048))
        evalAttributes.append(createAttribute(name: "processingTimeSeconds", type: .doubleAttributeType, optional: true, defaultValue: 0.0))
        evalAttributes.append(createAttribute(name: "temperature", type: .floatAttributeType, optional: true, defaultValue: 1.0))
        evalAttributes.append(createAttribute(name: "maxTokensRequested", type: .integer32AttributeType, optional: true, defaultValue: 4096))

        // Status and Error Tracking (NEW)
        evalAttributes.append(createAttribute(name: "isCurrentEvaluation", type: .booleanAttributeType, optional: true, defaultValue: false))
        evalAttributes.append(createAttribute(name: "evaluationStatus", type: .stringAttributeType, optional: true, defaultValue: "completed"))
        evalAttributes.append(createAttribute(name: "errorMessage", type: .stringAttributeType, optional: true))
        evalAttributes.append(createAttribute(name: "errorCode", type: .stringAttributeType, optional: true))
        evalAttributes.append(createAttribute(name: "retryCount", type: .integer32AttributeType, optional: true, defaultValue: 0))
        evalAttributes.append(createAttribute(name: "parentEvaluationID", type: .UUIDAttributeType, optional: true))

        // Additional Metadata (NEW)
        evalAttributes.append(createAttribute(name: "providerMetadata", type: .transformableAttributeType, optional: true, transformerName: "NSSecureUnarchiveFromDataTransformer"))
        evalAttributes.append(createAttribute(name: "comparisonGroup", type: .UUIDAttributeType, optional: true))

        // SEO and Commerce Metadata (NEW)
        evalAttributes.append(createAttribute(name: "title", type: .stringAttributeType, optional: true))
        evalAttributes.append(createAttribute(name: "descriptionText", type: .stringAttributeType, optional: true))
        evalAttributes.append(createAttribute(name: "keywords", type: .transformableAttributeType, optional: true, transformerName: "NSSecureUnarchiveFromDataTransformer"))
        evalAttributes.append(createAttribute(name: "altText", type: .stringAttributeType, optional: true))
        evalAttributes.append(createAttribute(name: "suggestedCategories", type: .transformableAttributeType, optional: true, transformerName: "NSSecureUnarchiveFromDataTransformer"))
        evalAttributes.append(createAttribute(name: "bestUseCases", type: .transformableAttributeType, optional: true, transformerName: "NSSecureUnarchiveFromDataTransformer"))
        evalAttributes.append(createAttribute(name: "suggestedPriceTier", type: .stringAttributeType, optional: true))

        evalEntity.properties = evalAttributes

        // MARK: - EvaluationSession Entity (NEW)

        let sessionEntity = NSEntityDescription()
        sessionEntity.name = "EvaluationSession"
        sessionEntity.managedObjectClassName = "EvaluationSession"

        var sessionAttributes: [NSAttributeDescription] = []

        sessionAttributes.append(createAttribute(name: "id", type: .UUIDAttributeType, optional: true))
        sessionAttributes.append(createAttribute(name: "startDate", type: .dateAttributeType, optional: true))
        sessionAttributes.append(createAttribute(name: "endDate", type: .dateAttributeType, optional: true))
        sessionAttributes.append(createAttribute(name: "sessionType", type: .stringAttributeType, optional: true, defaultValue: "batch"))
        sessionAttributes.append(createAttribute(name: "totalImages", type: .integer32AttributeType, optional: true, defaultValue: 0))
        sessionAttributes.append(createAttribute(name: "successCount", type: .integer32AttributeType, optional: true, defaultValue: 0))
        sessionAttributes.append(createAttribute(name: "failureCount", type: .integer32AttributeType, optional: true, defaultValue: 0))
        sessionAttributes.append(createAttribute(name: "totalCost", type: .doubleAttributeType, optional: true, defaultValue: 0.0))
        sessionAttributes.append(createAttribute(name: "averageProcessingTime", type: .doubleAttributeType, optional: true, defaultValue: 0.0))
        sessionAttributes.append(createAttribute(name: "providers", type: .transformableAttributeType, optional: true, transformerName: "NSSecureUnarchiveFromDataTransformer"))
        sessionAttributes.append(createAttribute(name: "notes", type: .stringAttributeType, optional: true))

        sessionEntity.properties = sessionAttributes

        // MARK: - APIProvider Entity (NEW)

        let providerEntity = NSEntityDescription()
        providerEntity.name = "APIProvider"
        providerEntity.managedObjectClassName = "APIProvider"

        var providerAttributes: [NSAttributeDescription] = []

        providerAttributes.append(createAttribute(name: "id", type: .UUIDAttributeType, optional: true))
        providerAttributes.append(createAttribute(name: "name", type: .stringAttributeType, optional: true))
        providerAttributes.append(createAttribute(name: "displayName", type: .stringAttributeType, optional: true))
        providerAttributes.append(createAttribute(name: "isEnabled", type: .booleanAttributeType, optional: true, defaultValue: false))
        providerAttributes.append(createAttribute(name: "isDefault", type: .booleanAttributeType, optional: true, defaultValue: false))
        providerAttributes.append(createAttribute(name: "apiEndpoint", type: .stringAttributeType, optional: true))
        providerAttributes.append(createAttribute(name: "currentModel", type: .stringAttributeType, optional: true))
        providerAttributes.append(createAttribute(name: "supportedModels", type: .transformableAttributeType, optional: true, transformerName: "NSSecureUnarchiveFromDataTransformer"))
        providerAttributes.append(createAttribute(name: "lastTestDate", type: .dateAttributeType, optional: true))
        providerAttributes.append(createAttribute(name: "lastTestSuccess", type: .booleanAttributeType, optional: true, defaultValue: false))
        providerAttributes.append(createAttribute(name: "totalRequests", type: .integer64AttributeType, optional: true, defaultValue: 0))
        providerAttributes.append(createAttribute(name: "totalCost", type: .doubleAttributeType, optional: true, defaultValue: 0.0))
        providerAttributes.append(createAttribute(name: "averageResponseTime", type: .doubleAttributeType, optional: true, defaultValue: 0.0))
        providerAttributes.append(createAttribute(name: "successRate", type: .doubleAttributeType, optional: true, defaultValue: 0.0))
        providerAttributes.append(createAttribute(name: "configMetadata", type: .transformableAttributeType, optional: true, transformerName: "NSSecureUnarchiveFromDataTransformer"))

        providerEntity.properties = providerAttributes

        // MARK: - APIUsageStats Entity

        let statsEntity = NSEntityDescription()
        statsEntity.name = "APIUsageStats"
        statsEntity.managedObjectClassName = "APIUsageStats"

        var statsAttributes: [NSAttributeDescription] = []

        statsAttributes.append(createAttribute(name: "id", type: .UUIDAttributeType, optional: true))
        statsAttributes.append(createAttribute(name: "lastResetDate", type: .dateAttributeType, optional: true))
        statsAttributes.append(createAttribute(name: "totalTokensUsed", type: .integer64AttributeType, optional: true, defaultValue: 0))
        statsAttributes.append(createAttribute(name: "totalCost", type: .doubleAttributeType, optional: true, defaultValue: 0.0))
        statsAttributes.append(createAttribute(name: "totalImagesEvaluated", type: .integer64AttributeType, optional: true, defaultValue: 0))

        statsEntity.properties = statsAttributes

        // MARK: - Collection Entity (NEW)

        let collectionEntity = NSEntityDescription()
        collectionEntity.name = "Collection"
        collectionEntity.managedObjectClassName = "Collection"

        var collectionAttributes: [NSAttributeDescription] = []

        collectionAttributes.append(createAttribute(name: "id", type: .UUIDAttributeType, optional: true))
        collectionAttributes.append(createAttribute(name: "name", type: .stringAttributeType, optional: true))
        collectionAttributes.append(createAttribute(name: "icon", type: .stringAttributeType, optional: true, defaultValue: "folder"))
        collectionAttributes.append(createAttribute(name: "color", type: .stringAttributeType, optional: true, defaultValue: "blue"))
        collectionAttributes.append(createAttribute(name: "dateCreated", type: .dateAttributeType, optional: true))
        collectionAttributes.append(createAttribute(name: "sortOrder", type: .integer32AttributeType, optional: true, defaultValue: 0))
        collectionAttributes.append(createAttribute(name: "isSmartFolder", type: .booleanAttributeType, optional: true, defaultValue: false))
        collectionAttributes.append(createAttribute(name: "smartPredicate", type: .stringAttributeType, optional: true))
        collectionAttributes.append(createAttribute(name: "collectionDescription", type: .stringAttributeType, optional: true))

        collectionEntity.properties = collectionAttributes

        // MARK: - Set up Relationships

        // After all entities are defined, now we set up relationships
        var imageRelationships: [NSRelationshipDescription] = []
        var evalRelationships: [NSRelationshipDescription] = []
        var sessionRelationships: [NSRelationshipDescription] = []
        var collectionRelationships: [NSRelationshipDescription] = []

        // ImageEvaluation → EvaluationResult (one-to-many for history)
        let evaluationHistoryRel = NSRelationshipDescription()
        evaluationHistoryRel.name = "evaluationHistory"
        evaluationHistoryRel.destinationEntity = evalEntity
        evaluationHistoryRel.minCount = 0
        evaluationHistoryRel.maxCount = 0 // 0 = to-many
        evaluationHistoryRel.isOptional = true
        evaluationHistoryRel.deleteRule = .cascadeDeleteRule
        imageRelationships.append(evaluationHistoryRel)

        // ImageEvaluation → EvaluationResult (one-to-one for current)
        let currentEvaluationRel = NSRelationshipDescription()
        currentEvaluationRel.name = "currentEvaluation"
        currentEvaluationRel.destinationEntity = evalEntity
        currentEvaluationRel.minCount = 0
        currentEvaluationRel.maxCount = 1
        currentEvaluationRel.isOptional = true
        currentEvaluationRel.deleteRule = .nullifyDeleteRule
        imageRelationships.append(currentEvaluationRel)

        // EvaluationResult → ImageEvaluation (inverse of history)
        let imageEvaluationRel = NSRelationshipDescription()
        imageEvaluationRel.name = "imageEvaluation"
        imageEvaluationRel.destinationEntity = imageEntity
        imageEvaluationRel.minCount = 0
        imageEvaluationRel.maxCount = 1
        imageEvaluationRel.isOptional = true
        imageEvaluationRel.deleteRule = .nullifyDeleteRule
        evalRelationships.append(imageEvaluationRel)

        // EvaluationResult → ImageEvaluation (inverse of current)
        let currentOfImageRel = NSRelationshipDescription()
        currentOfImageRel.name = "currentOfImage"
        currentOfImageRel.destinationEntity = imageEntity
        currentOfImageRel.minCount = 0
        currentOfImageRel.maxCount = 1
        currentOfImageRel.isOptional = true
        currentOfImageRel.deleteRule = .nullifyDeleteRule
        evalRelationships.append(currentOfImageRel)

        // EvaluationResult → EvaluationSession
        let sessionRel = NSRelationshipDescription()
        sessionRel.name = "session"
        sessionRel.destinationEntity = sessionEntity
        sessionRel.minCount = 0
        sessionRel.maxCount = 1
        sessionRel.isOptional = true
        sessionRel.deleteRule = .nullifyDeleteRule
        evalRelationships.append(sessionRel)

        // EvaluationSession → EvaluationResult
        let evaluationsRel = NSRelationshipDescription()
        evaluationsRel.name = "evaluations"
        evaluationsRel.destinationEntity = evalEntity
        evaluationsRel.minCount = 0
        evaluationsRel.maxCount = 0 // to-many
        evaluationsRel.isOptional = true
        evaluationsRel.deleteRule = .cascadeDeleteRule
        sessionRelationships.append(evaluationsRel)

        // Collection ⟷ ImageEvaluation (many-to-many)
        let collectionsRel = NSRelationshipDescription()
        collectionsRel.name = "collections"
        collectionsRel.destinationEntity = collectionEntity
        collectionsRel.minCount = 0
        collectionsRel.maxCount = 0 // to-many
        collectionsRel.isOptional = true
        collectionsRel.deleteRule = .nullifyDeleteRule
        imageRelationships.append(collectionsRel)

        let imagesRel = NSRelationshipDescription()
        imagesRel.name = "images"
        imagesRel.destinationEntity = imageEntity
        imagesRel.minCount = 0
        imagesRel.maxCount = 0 // to-many
        imagesRel.isOptional = true
        imagesRel.deleteRule = .nullifyDeleteRule
        collectionRelationships.append(imagesRel)

        // Set up inverse relationships
        evaluationHistoryRel.inverseRelationship = imageEvaluationRel
        imageEvaluationRel.inverseRelationship = evaluationHistoryRel

        currentEvaluationRel.inverseRelationship = currentOfImageRel
        currentOfImageRel.inverseRelationship = currentEvaluationRel

        sessionRel.inverseRelationship = evaluationsRel
        evaluationsRel.inverseRelationship = sessionRel

        collectionsRel.inverseRelationship = imagesRel
        imagesRel.inverseRelationship = collectionsRel

        // Add relationships to entities
        imageEntity.properties.append(contentsOf: imageRelationships)
        evalEntity.properties.append(contentsOf: evalRelationships)
        sessionEntity.properties.append(contentsOf: sessionRelationships)
        collectionEntity.properties.append(contentsOf: collectionRelationships)

        // Add all entities to model
        model.entities = [imageEntity, evalEntity, sessionEntity, providerEntity, statsEntity, collectionEntity]

        return model
    }

    // MARK: - Helper Methods

    private static func createAttribute(
        name: String,
        type: NSAttributeType,
        optional: Bool = true,
        defaultValue: Any? = nil,
        transformerName: String? = nil,
        allowsExternalStorage: Bool = false
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional

        if let defaultValue = defaultValue {
            attribute.defaultValue = defaultValue
        }

        if let transformerName = transformerName {
            attribute.valueTransformerName = transformerName
        }

        if allowsExternalStorage && type == .binaryDataAttributeType {
            attribute.allowsExternalBinaryDataStorage = true
        }

        return attribute
    }
}