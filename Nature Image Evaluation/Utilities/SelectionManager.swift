//
//  SelectionManager.swift
//  Nature Image Evaluation
//
//  Created by Claude on 11/18/25.
//

import Foundation
import SwiftUI
import CoreData
import Combine

/// Manages standard macOS selection behaviors for collections
@MainActor
class SelectionManager: ObservableObject {
    @Published var selectedIDs: Set<NSManagedObjectID> = []
    private var lastSelectedID: NSManagedObjectID?
    private var lastSelectedIndex: Int?

    /// Handle a click on an item following macOS HID conventions
    /// - Parameters:
    ///   - id: The object ID of the clicked item
    ///   - index: The index of the clicked item in the collection
    ///   - modifiers: The event modifiers (cmd, shift, etc.)
    ///   - allIDs: All object IDs in the current collection (for range selection)
    func handleSelection(
        id: NSManagedObjectID,
        index: Int,
        modifiers: EventModifiers,
        allIDs: [NSManagedObjectID]
    ) {
        if modifiers.contains(.command) {
            // CMD+click: Toggle individual selection
            toggleSingleSelection(id: id, index: index)
        } else if modifiers.contains(.shift), let lastIdx = lastSelectedIndex {
            // SHIFT+click: Range selection from last selected to current
            selectRange(from: lastIdx, to: index, allIDs: allIDs)
        } else {
            // Regular click: Exclusive selection (clear others, select this)
            selectExclusive(id: id, index: index)
        }
    }

    /// Toggle selection of a single item (CMD+click behavior)
    private func toggleSingleSelection(id: NSManagedObjectID, index: Int) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
            // If we deselected the last selected item, clear the anchor
            if lastSelectedID == id {
                lastSelectedID = nil
                lastSelectedIndex = nil
            }
        } else {
            selectedIDs.insert(id)
            lastSelectedID = id
            lastSelectedIndex = index
        }
    }

    /// Select only this item, clearing all others (regular click behavior)
    private func selectExclusive(id: NSManagedObjectID, index: Int) {
        selectedIDs = [id]
        lastSelectedID = id
        lastSelectedIndex = index
    }

    /// Select a range of items (SHIFT+click behavior)
    private func selectRange(from startIndex: Int, to endIndex: Int, allIDs: [NSManagedObjectID]) {
        let minIndex = min(startIndex, endIndex)
        let maxIndex = max(startIndex, endIndex)

        // Add all items in the range to selection
        for index in minIndex...maxIndex {
            if index < allIDs.count {
                selectedIDs.insert(allIDs[index])
            }
        }

        // Update the last selected anchor
        if endIndex < allIDs.count {
            lastSelectedID = allIDs[endIndex]
            lastSelectedIndex = endIndex
        }
    }

    /// Select all items
    func selectAll(ids: [NSManagedObjectID]) {
        selectedIDs = Set(ids)
        if let last = ids.last {
            lastSelectedID = last
            lastSelectedIndex = ids.count - 1
        }
    }

    /// Deselect all items
    func deselectAll() {
        selectedIDs.removeAll()
        lastSelectedID = nil
        lastSelectedIndex = nil
    }

    /// Invert the current selection
    func invertSelection(allIDs: [NSManagedObjectID]) {
        let all = Set(allIDs)
        selectedIDs = all.subtracting(selectedIDs)
        // Clear anchor after inversion as there's no clear "last selected"
        lastSelectedID = nil
        lastSelectedIndex = nil
    }

    /// Check if an item is selected
    func isSelected(_ id: NSManagedObjectID) -> Bool {
        selectedIDs.contains(id)
    }

    /// Get the count of selected items
    var selectionCount: Int {
        selectedIDs.count
    }

    /// Check if any items are selected
    var hasSelection: Bool {
        !selectedIDs.isEmpty
    }
}