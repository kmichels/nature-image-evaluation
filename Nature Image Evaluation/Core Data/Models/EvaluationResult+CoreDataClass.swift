//
//  EvaluationResult+CoreDataClass.swift
//  Nature Image Evaluation
//
//  Programmatically created NSManagedObject subclass
//

import Foundation
import CoreData

@objc(EvaluationResult)
public class EvaluationResult: NSManagedObject {

}

extension EvaluationResult {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<EvaluationResult> {
        return NSFetchRequest<EvaluationResult>(entityName: "EvaluationResult")
    }

    // Core Properties
    @NSManaged public var id: UUID?
    @NSManaged public var evaluationDate: Date?

    // Scores
    @NSManaged public var compositionScore: Double
    @NSManaged public var qualityScore: Double
    @NSManaged public var sellabilityScore: Double
    @NSManaged public var artisticScore: Double
    @NSManaged public var overallWeightedScore: Double

    // Evaluation Details
    @NSManaged public var primaryPlacement: String?
    @NSManaged public var strengths: [String]?
    @NSManaged public var improvements: [String]?
    @NSManaged public var marketComparison: String?
    @NSManaged public var technicalInnovations: [String]?
    @NSManaged public var printSizeRecommendation: String?
    @NSManaged public var priceTierSuggestion: String?

    // API Metadata
    @NSManaged public var inputTokens: Int32
    @NSManaged public var outputTokens: Int32
    @NSManaged public var estimatedCost: Double
    @NSManaged public var rawAIResponse: String?

    // Provider Information (NEW)
    @NSManaged public var provider: String?
    @NSManaged public var modelIdentifier: String?
    @NSManaged public var modelDisplayName: String?
    @NSManaged public var apiVersion: String?

    // Evaluation Context (NEW)
    @NSManaged public var evaluationIndex: Int32
    @NSManaged public var evaluationSource: String?
    @NSManaged public var promptVersion: String?
    @NSManaged public var imageResolution: Int32
    @NSManaged public var processingTimeSeconds: Double
    @NSManaged public var temperature: Float
    @NSManaged public var maxTokensRequested: Int32

    // Status and Error Tracking (NEW)
    @NSManaged public var isCurrentEvaluation: Bool
    @NSManaged public var evaluationStatus: String?
    @NSManaged public var errorMessage: String?
    @NSManaged public var errorCode: String?
    @NSManaged public var retryCount: Int32
    @NSManaged public var parentEvaluationID: UUID?

    // Additional Metadata (NEW)
    @NSManaged public var providerMetadata: [String: Any]?
    @NSManaged public var comparisonGroup: UUID?

    // Relationships
    @NSManaged public var imageEvaluation: ImageEvaluation?
    @NSManaged public var currentOfImage: ImageEvaluation?
    @NSManaged public var session: EvaluationSession?
}