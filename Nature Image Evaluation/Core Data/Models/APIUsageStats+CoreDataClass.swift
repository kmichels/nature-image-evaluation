//
//  APIUsageStats+CoreDataClass.swift
//  Nature Image Evaluation
//
//  Programmatically created NSManagedObject subclass
//

import Foundation
import CoreData

@objc(APIUsageStats)
public class APIUsageStats: NSManagedObject {

}

extension APIUsageStats {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<APIUsageStats> {
        return NSFetchRequest<APIUsageStats>(entityName: "APIUsageStats")
    }

    // Properties
    @NSManaged public var id: UUID?
    @NSManaged public var lastResetDate: Date?
    @NSManaged public var totalTokensUsed: Int64
    @NSManaged public var totalCost: Double
    @NSManaged public var totalImagesEvaluated: Int64
}