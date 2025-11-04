//
//  Collection+CoreDataClass.swift
//  Nature Image Evaluation
//
//  Programmatically created NSManagedObject subclass
//

import Foundation
import CoreData

@objc(Collection)
public class Collection: NSManagedObject {

    // Helper methods to manage images in collection
    @objc(addImagesToObject:)
    @NSManaged public func addToImages(_ value: ImageEvaluation)

    @objc(removeImagesObject:)
    @NSManaged public func removeFromImages(_ value: ImageEvaluation)

    @objc(addImages:)
    @NSManaged public func addToImages(_ values: NSSet)

    @objc(removeImages:)
    @NSManaged public func removeFromImages(_ values: NSSet)
}

extension Collection {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Collection> {
        return NSFetchRequest<Collection>(entityName: "Collection")
    }

    // Basic Properties
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var icon: String?
    @NSManaged public var color: String?
    @NSManaged public var dateCreated: Date?
    @NSManaged public var sortOrder: Int32
    @NSManaged public var isSmartFolder: Bool
    @NSManaged public var smartPredicate: String?
    @NSManaged public var collectionDescription: String?

    // Relationships
    @NSManaged public var images: NSSet?

    // Computed properties
    var imageCount: Int {
        return images?.count ?? 0
    }

    var sortedImages: [ImageEvaluation] {
        let set = images as? Set<ImageEvaluation> ?? []
        return set.sorted {
            ($0.dateAdded ?? Date.distantPast) > ($1.dateAdded ?? Date.distantPast)
        }
    }
}

// MARK: - Collection Types

extension Collection {
    enum CollectionType: String {
        case userCreated = "user"
        case smartFolder = "smart"
        case system = "system"
    }

    var type: CollectionType {
        if isSmartFolder {
            return .smartFolder
        }
        return .userCreated
    }
}