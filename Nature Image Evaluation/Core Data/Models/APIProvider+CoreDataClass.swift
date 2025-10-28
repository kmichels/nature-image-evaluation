//
//  APIProvider+CoreDataClass.swift
//  Nature Image Evaluation
//
//  Programmatically created NSManagedObject subclass
//

import Foundation
import CoreData

@objc(APIProvider)
public class APIProvider: NSManagedObject {

}

extension APIProvider {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<APIProvider> {
        return NSFetchRequest<APIProvider>(entityName: "APIProvider")
    }

    // Properties
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var displayName: String?
    @NSManaged public var isEnabled: Bool
    @NSManaged public var isDefault: Bool
    @NSManaged public var apiEndpoint: String?
    @NSManaged public var currentModel: String?
    @NSManaged public var supportedModels: [String]?
    @NSManaged public var lastTestDate: Date?
    @NSManaged public var lastTestSuccess: Bool
    @NSManaged public var totalRequests: Int64
    @NSManaged public var totalCost: Double
    @NSManaged public var averageResponseTime: Double
    @NSManaged public var successRate: Double
    @NSManaged public var configMetadata: [String: Any]?
}