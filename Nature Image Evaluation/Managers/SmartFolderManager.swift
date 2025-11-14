//
//  SmartFolderManager.swift
//  Nature Image Evaluation
//
//  Created by Claude on 11/14/25.
//

import Foundation
import CoreData
import SwiftUI
import Combine

@MainActor
class SmartFolderManager: ObservableObject {
    static let shared = SmartFolderManager()

    @Published var smartFolders: [Collection] = []

    private let viewContext: NSManagedObjectContext

    private init() {
        self.viewContext = PersistenceController.shared.container.viewContext
        loadSmartFolders()
    }

    // MARK: - CRUD Operations

    func loadSmartFolders() {
        let request: NSFetchRequest<Collection> = Collection.fetchRequest()
        request.predicate = NSPredicate(format: "isSmartFolder == true")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Collection.sortOrder, ascending: true),
                                   NSSortDescriptor(keyPath: \Collection.name, ascending: true)]

        do {
            smartFolders = try viewContext.fetch(request)
        } catch {
            print("Error loading smart folders: \(error)")
            smartFolders = []
        }
    }

    func createSmartFolder(name: String, icon: String = "sparkle.magnifyingglass", criteria: SmartFolderCriteria) throws {
        let collection = Collection(context: viewContext)
        collection.id = UUID()
        collection.name = name
        collection.icon = icon
        collection.isSmartFolder = true
        collection.dateCreated = Date()
        collection.smartPredicate = criteria.toJSONString()
        collection.sortOrder = Int32(smartFolders.count)

        try viewContext.save()
        loadSmartFolders()
    }

    func updateSmartFolder(_ collection: Collection, name: String? = nil, icon: String? = nil, criteria: SmartFolderCriteria? = nil) throws {
        if let name = name {
            collection.name = name
        }
        if let icon = icon {
            collection.icon = icon
        }
        if let criteria = criteria {
            collection.smartPredicate = criteria.toJSONString()
        }

        try viewContext.save()
        loadSmartFolders()
    }

    func deleteSmartFolder(_ collection: Collection) throws {
        viewContext.delete(collection)
        try viewContext.save()
        loadSmartFolders()
    }

    // MARK: - Query Methods

    func fetchImages(for smartFolder: Collection) -> [ImageEvaluation] {
        guard smartFolder.isSmartFolder,
              let predicateString = smartFolder.smartPredicate,
              let criteria = SmartFolderCriteria.fromJSONString(predicateString),
              let predicate = criteria.buildPredicate() else {
            return []
        }

        let request: NSFetchRequest<ImageEvaluation> = ImageEvaluation.fetchRequest()
        request.predicate = predicate
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ImageEvaluation.dateAdded, ascending: false)]

        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching images for smart folder: \(error)")
            return []
        }
    }

    func imageCount(for smartFolder: Collection) -> Int {
        guard smartFolder.isSmartFolder,
              let predicateString = smartFolder.smartPredicate,
              let criteria = SmartFolderCriteria.fromJSONString(predicateString),
              let predicate = criteria.buildPredicate() else {
            return 0
        }

        let request: NSFetchRequest<ImageEvaluation> = ImageEvaluation.fetchRequest()
        request.predicate = predicate

        do {
            return try viewContext.count(for: request)
        } catch {
            print("Error counting images for smart folder: \(error)")
            return 0
        }
    }

    // MARK: - Template Creation

    func createDefaultSmartFolders() throws {
        // Check if default folders already exist
        let request: NSFetchRequest<Collection> = Collection.fetchRequest()
        request.predicate = NSPredicate(format: "isSmartFolder == true")
        let existingCount = try viewContext.count(for: request)

        guard existingCount == 0 else { return }

        // Create default smart folders
        let defaults: [(String, String, SmartFolderCriteria)] = [
            ("Portfolio Quality", "star.fill", .portfolioQuality),
            ("Needs Review", "eye.fill", .needsReview),
            ("Recently Added", "clock.fill", .recentlyAdded),
            ("High Commercial Value", "dollarsign.circle.fill", .highCommercialValue),
            ("Needs Improvement", "exclamationmark.triangle.fill", .needsImprovement),
            ("Favorites", "heart.fill", .favorites)
        ]

        for (index, (name, icon, criteria)) in defaults.enumerated() {
            let collection = Collection(context: viewContext)
            collection.id = UUID()
            collection.name = name
            collection.icon = icon
            collection.isSmartFolder = true
            collection.dateCreated = Date()
            collection.smartPredicate = criteria.toJSONString()
            collection.sortOrder = Int32(index)
        }

        try viewContext.save()
        loadSmartFolders()
    }

    // MARK: - Validation

    func validateCriteria(_ criteria: SmartFolderCriteria) -> Bool {
        // Ensure at least one rule exists
        guard !criteria.rules.isEmpty else { return false }

        // Validate each rule has appropriate values
        for rule in criteria.rules {
            switch rule.value {
            case .number(let value):
                if rule.criteriaType.valueType != .number { return false }
                if value < 0 || value > 10 { return false }
            case .placement(let value):
                if rule.criteriaType.valueType != .placement { return false }
                if !["PORTFOLIO", "STORE", "BOTH", "ARCHIVE", "PRACTICE"].contains(value) { return false }
            case .boolean:
                if rule.criteriaType.valueType != .boolean { return false }
            case .date, .dateInterval:
                if rule.criteriaType.valueType != .date { return false }
            default:
                return false
            }
        }

        return true
    }
}

// MARK: - Preview Data

extension SmartFolderManager {
    static var preview: SmartFolderManager {
        let manager = SmartFolderManager()
        // Add sample data if needed
        return manager
    }
}