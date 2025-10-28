//
//  EvaluationSession+CoreDataClass.swift
//  Nature Image Evaluation
//
//  Programmatically created NSManagedObject subclass
//

import Foundation
import CoreData

@objc(EvaluationSession)
public class EvaluationSession: NSManagedObject {

    // Helper methods for managing evaluations
    @objc(addToEvaluations:)
    @NSManaged public func addToEvaluations(_ value: EvaluationResult)

    @objc(removeFromEvaluations:)
    @NSManaged public func removeFromEvaluations(_ value: EvaluationResult)
}

extension EvaluationSession {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<EvaluationSession> {
        return NSFetchRequest<EvaluationSession>(entityName: "EvaluationSession")
    }

    // Properties
    @NSManaged public var id: UUID?
    @NSManaged public var startDate: Date?
    @NSManaged public var endDate: Date?
    @NSManaged public var sessionType: String?
    @NSManaged public var totalImages: Int32
    @NSManaged public var successCount: Int32
    @NSManaged public var failureCount: Int32
    @NSManaged public var totalCost: Double
    @NSManaged public var averageProcessingTime: Double
    @NSManaged public var providers: [String]?
    @NSManaged public var notes: String?

    // Relationships
    @NSManaged public var evaluations: NSSet?

    // Computed properties are defined in CoreDataModelExtensions.swift
}