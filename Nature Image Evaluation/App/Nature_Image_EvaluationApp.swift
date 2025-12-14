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
    @State private var evaluationManager: EvaluationManager

    init() {
        // Initialize evaluation manager
        _evaluationManager = State(initialValue: EvaluationManager(persistenceController: PersistenceController.shared))
    }

    var body: some Scene {
        WindowGroup {
            ContentViewNew()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environment(evaluationManager)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}
