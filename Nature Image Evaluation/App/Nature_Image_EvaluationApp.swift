//
//  Nature_Image_EvaluationApp.swift
//  Nature Image Evaluation
//
//  Created by Konrad Michels on 10/27/25.
//

import SwiftUI
import CoreData

@main
struct Nature_Image_EvaluationApp: App {
    let persistenceController = PersistenceController.shared

    init() {
        // Migration disabled for fresh programmatic model
        // DataMigrationHelper.shared.runFullMigration(
        //     context: persistenceController.container.viewContext
        // )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
