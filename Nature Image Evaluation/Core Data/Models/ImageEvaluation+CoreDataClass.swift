//
//  ImageEvaluation+CoreDataClass.swift
//  Nature Image Evaluation
//
//  Programmatically created NSManagedObject subclass
//

import Foundation
import CoreData

@objc(ImageEvaluation)
public class ImageEvaluation: NSManagedObject, Identifiable {

    // Helper method to add evaluation to history
    @objc(addToEvaluationHistory:)
    @NSManaged public func addToEvaluationHistory(_ value: EvaluationResult)

    @objc(removeFromEvaluationHistory:)
    @NSManaged public func removeFromEvaluationHistory(_ value: EvaluationResult)
}

extension ImageEvaluation {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ImageEvaluation> {
        return NSFetchRequest<ImageEvaluation>(entityName: "ImageEvaluation")
    }

    // Basic Properties
    @NSManaged public var id: UUID?
    @NSManaged public var dateAdded: Date?
    @NSManaged public var originalFilePath: String?
    @NSManaged public var processedFilePath: String?
    @NSManaged public var thumbnailData: Data?
    @NSManaged public var originalWidth: Int32
    @NSManaged public var originalHeight: Int32
    @NSManaged public var processedWidth: Int32
    @NSManaged public var processedHeight: Int32
    @NSManaged public var aspectRatio: Double
    @NSManaged public var fileSize: Int64

    // Evaluation Tracking
    @NSManaged public var dateLastEvaluated: Date?
    @NSManaged public var firstEvaluatedDate: Date?
    @NSManaged public var evaluationCount: Int32

    // User Metadata
    @NSManaged public var notes: String?
    @NSManaged public var tags: [String]?
    @NSManaged public var isFavorite: Bool
    @NSManaged public var lastModifiedDate: Date?

    // Relationships
    @NSManaged public var evaluationHistory: NSSet?
    @NSManaged public var currentEvaluation: EvaluationResult?

    // Computed properties are defined in CoreDataModelExtensions.swift
}